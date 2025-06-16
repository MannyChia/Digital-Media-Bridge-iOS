///
///
///
/// *************************************************
/// *** LIST OF AVAILABLE DMB PLAYERS
/// *************************************************
///
// for camera and gallery
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import './main.dart';
import './screens_page.dart';
import './dmb_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'Models/playlist_preview.dart';

/*
*/
dynamic activeDMBPlayers = 0;

//Create custom class to hold the media player data
class MediaPlayer {
  //modal class for MediaPlayer object
  String name, status, currentScreen;

  MediaPlayer(
      {required this.name, required this.status, required this.currentScreen});
}

//Add necessary public vars
List<MediaPlayer> dmbMediaPlayers = [];
dynamic selectedPlayerName;

//This var is used to determine whether we should show a 'refresh'
//or a 'back' button when showing the user a list of DMB Media Players
bool playersNoBackButton = true;

class PlaylistSheet extends StatefulWidget {
  final String userEmail;
  const PlaylistSheet({super.key, required this.userEmail});

  @override
  State<PlaylistSheet> createState() => _PlaylistSheetState();
}

class _PlaylistSheetState extends State<PlaylistSheet> {
  String? _currentScreenName;
  int _pageIndex = 0;
  String _currentPlaylist = '';
  List<String> _playlistImages = [];
  Set<String> selectedImages = {};

  Set<String> originalPlaylistImages = {};

  void _openPlaylist(String screenName, String playlistName) async {
    try {
      _currentScreenName = screenName;
      _currentPlaylist   = playlistName;

      // 1) fetch all image URLs (unchanged)
      final apiUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/api/'
          'get_images.php?email=${Uri.encodeComponent(widget.userEmail)}';
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) throw Exception('Failed to fetch image filenames');
      final filenames = json.decode(response.body) as List<dynamic>;
      final allImageUrls = filenames
          .map((f) => 'https://digitalmediabridge.tv/screen-builder-test/assets/content/'
          '${Uri.encodeComponent(widget.userEmail)}/images/$f')
          .toList();

      // 2) load the .pl file under its screen folder
      final encodedScreen = Uri.encodeComponent(screenName);
      final encodedPl     = Uri.encodeComponent(playlistName);
      final playlistFileUrl =
          'https://digitalmediabridge.tv/screen-builder-test/assets/content/'
          '${Uri.encodeComponent(widget.userEmail)}/others/'
          '$encodedScreen/$encodedPl';

      final playlistResponse = await http.get(Uri.parse(playlistFileUrl));
      if (playlistResponse.statusCode != 200) throw Exception('Failed to load playlist');

      final lines = const LineSplitter()
          .convert(playlistResponse.body)
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final selectedFilenames = lines.map((l) => l.split(',').first.trim()).toSet();
      final preSelected = <String>{
        for (final url in allImageUrls)
          if (selectedFilenames.contains(url.split('/').last)) url
      };

      originalPlaylistImages = preSelected.map((url) => url.split('/').last).toSet();
      setState(() {
        _playlistImages = allImageUrls;
        selectedImages  = preSelected;
        _pageIndex      = 1;
      });
    } catch (e) {
      print("ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load playlist images")),
      );
    }
  }

// have to check if playlist is changed, if it didn't change in any circumstance then disable "save playlist" button
  bool _hasPlaylistChanged() {
    final selectedFilenames = selectedImages.map((url) => url.split('/').last).toSet();
    return selectedFilenames.isNotEmpty && !setEquals(selectedFilenames, originalPlaylistImages);
  }


// this updates the preview image and playlist number using cache data
  Future<void> _refreshPlaylistPreviews() async {
    try {
      final updated = await fetchPlaylistPreviews(widget.userEmail);
      setState(() {
        // remember data stored in cache UPDATES the current playlist previes when reloaded
        cachedPlaylistPreviews = updated;
      });
    } catch (e) {
      print("Failed to refresh playlist previews: $e");
    }
  }



  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            // animation navigation between playlist and image view, it could change later
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pageIndex == 0
                  ? _buildPlaylistView(scrollController)
                  : _buildImageView(scrollController),
            ),
          );

        }

    );
  }

  Widget _buildPlaylistView(ScrollController scrollController) {
    // error check when there is no playlists
    if (cachedPlaylistPreviews.isEmpty) {
      return Column(
        key: const ValueKey(0),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Text('Edit Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(width: 6),
                Icon(Icons.playlist_add, color: Colors.white, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                'No current playlist',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ],
      );
    }

    // Nested group by screenName
    final Map<String, List<PlaylistPreview>> groups = {};
    for (final p in cachedPlaylistPreviews) {
      groups.putIfAbsent(p.screenName, () => []).add(p);
    }

    return Column(
      key: const ValueKey(0),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 40, height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),

        //
        //got to make header not scrollable later!!*
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Text('Edit Playlist',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 6),
              Icon(Icons.playlist_add, color: Colors.white, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in groups.entries) ...[
                // ... is a spread tool (jsyk)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),

                // Grid layout
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (context, idx) {
                    final preview = entry.value[idx];
                    // If playlist ends with ".pl" then drop those 3 chars
                    final displayName = preview.name.endsWith('.pl')
                        ? preview.name.substring(0, preview.name.length - 3)
                        : preview.name;

                    return InkWell(
                      onTap: () => _openPlaylist(preview.screenName, preview.name),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                color: Colors.grey[700],
                                child: preview.previewImageUrl != null
                                    ? Image.network(
                                  preview.previewImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image, color: Colors.white70)),
                                )
                                    : Container(
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(Icons.image_not_supported, color: Colors.white70, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$displayName (${preview.itemCount})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              ],
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildImageView(ScrollController scrollController) {
    // Got to remove the “.pl” from the header title if present
    final displayTitle = _currentPlaylist.endsWith('.pl')
        ? _currentPlaylist.substring(0, _currentPlaylist.length - 3)
        : _currentPlaylist;

    return Stack(
      children: [
        Column(
          key: const ValueKey(1),
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            ListTile(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  await _refreshPlaylistPreviews();
                  setState(() {
                    _pageIndex = 0;
                  });
                },
              ),
              title: Text(
                displayTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Text(
                "${selectedImages.length} selected",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(
                    left: 12, right: 12, bottom: 70, top: 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _playlistImages.length,
                itemBuilder: (context, index) {
                  final imageUrl = _playlistImages[index];
                  final isSelected = selectedImages.contains(imageUrl);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (isSelected) {
                          selectedImages.remove(imageUrl);
                        } else {
                          selectedImages.add(imageUrl);
                        }
                      });
                    },
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              color: Colors.grey[800],
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white70),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.greenAccent
                                  : Colors.black45,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isSelected ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: isSelected ? Colors.black : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: _hasPlaylistChanged() ? _onSavePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              _hasPlaylistChanged() ? Colors.greenAccent : Colors.grey[700],
              foregroundColor:
              _hasPlaylistChanged() ? Colors.black : Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Save Playlist',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )
      ],
    );
  }


  // remember to save it in cache later.
  // for future got to update locally first and let backend update gradually
  void _onSavePressed() async {
    // Build bare filenames from selected URLs
    final selectedFilenames = selectedImages
        .map((url) => url.split('/').last)
        .toList();

    // Include screen folder in the playlistFileName
    final fullFileName = '$_currentScreenName/$_currentPlaylist';

    final success = await updatePlaylist(
      userEmail: widget.userEmail,
      playlistFileName: fullFileName,
      selectedFilenames: selectedFilenames,
    );

    if (success) {
      originalPlaylistImages = selectedFilenames.toSet();
      // Refresh previews so the counts & images update
      cachedPlaylistPreviews = await fetchPlaylistPreviews(widget.userEmail);
      setState(() {}); // rebuild UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Playlist updated")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update playlist")),
      );
    }
  }




}
///
class PlayersPage extends StatefulWidget {
  //const PlayersPage({super.key, required this.pageTitle, required this.pageSubTitle});
  const PlayersPage({super.key, this.pageTitle, this.pageSubTitle});

  final String? pageTitle;
  final String? pageSubTitle;

  @override
  _PlayersPageState createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late String pageTitle;
  late String pageSubTitle;

  File? _image;
  final ImagePicker _picker = ImagePicker();

  ///This 'override' function is called once when the class is loaded
  ///(is used to update the pageTitle * subTitle)
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  // void _updateTitle() {
  //
  //   setState(() {
  //     pageTitle = "${widget.pageTitle} (${dmbMediaPlayers.length})";
  //     pageSubTitle = widget.pageSubTitle;
  //   });
  // }

  void _updateTitle() {
    pageTitle = "${widget.pageTitle} (${dmbMediaPlayers.length})";
    pageSubTitle = widget.pageSubTitle ?? "";
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int selectedIndex = 0;

  void _showScreensPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ScreensPage(
              pageTitle: "Player: $selectedPlayerName",
              pageSubTitle: "Select Screen to Publish",
            ),
      ),
    );
  }


  //As the list of players is being build, this function will determine
  //whether we show a 'regular' color button or a 'red' one because
  //the status of the player is inactive
  // _checkPlayerStatus(index){
  //
  //   var pStatus = dmbMediaPlayers[index].status;
  //   return pStatus == "Active" ? true : false;
  // }

  bool _checkPlayerStatus(int index) {
    return dmbMediaPlayers[index].status == "Active";
  }

  //In each view, provide a button to let the user logout
  void _userLogout() {
    confirmLogout(
        context); //*** CONFIRM USER LOGOUT (function is in: dmb_functions.dart)
  }

  //Called this when the user pulls down the screen
  Future<void> _refreshData() async {
    try {
      //Go to the DMB server to get an updated list of players
      getUserData("$loginUsername", "$loginPassword", "players-refresh").then((
          result) {
        //*** If the return value is a string, then there was an error
        // getting the data, so don't do anything.
        // Otherwise, should be Ok to set the
        // dmbMediaPlayers var with the new data
        if (result.runtimeType != String) {
          setState(() {
            dmbMediaPlayers = result;
            pageTitle = "Media Players (${dmbMediaPlayers.length})";
            pageSubTitle = "Select Player";
          });
        }
      });
    } catch (err) {}
  }

  // change from pop up dialog to a sheet to make consistent ui throughout
  // remember your future, async
  Future<void> _showUploadSheet(File imageFile) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              "Upload Image",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey[800],
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    // Call uploadImage and handle result.
                    // got to update user if there's any errors
                    // got to keep testing to prompt user ALL errors
                    final result = await uploadImage(imageFile, "mannychia7@gmail.com");

                    if (!result['success']) {
                      final String message = result['message'];

                      showDialog(
                        context: context,
                        barrierColor: Colors.black,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            message.contains('20')
                                ? "Upload Limit Reached"
                                : "Upload Failed",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          content: Text(
                            message.contains('20')
                                ? "You cannot upload more than 20 images. Please delete one first."
                                : message,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text("OK", style: TextStyle(color: Colors.greenAccent)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Image uploaded successfully")),
                      );
                    }
                  },
                  child: const Text("Upload"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _takePhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _showUploadSheet(_image!);
    }
  }

  Future<void> _chooseFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _showUploadSheet(_image!);
    }
  }

  Future<void> _showPlaylistBottomSheet(BuildContext context, String userEmail) async {
    // 1) preload playlists
    await preloadPlaylistPreviews(userEmail);

    // 2) if still empty, show a SnackBar and bail
    if (cachedPlaylistPreviews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No playlists available")),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PlaylistSheet(userEmail: userEmail),
    );

    //Refresh preview after sheet is closed
    // slight delay though, got to fix this in the future
    // for local load and then backend functions
    try {
      cachedPlaylistPreviews = await fetchPlaylistPreviews(userEmail);
      hasLoadedPlaylistPreviews = true;
    } catch (e) {
      print("Failed to refresh playlist previews: $e");
    }
  }














  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Colors.blueGrey,
                Color.fromRGBO(10, 85, 163, 1.0),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "Menu",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // ListTile(
                      //   leading: const Icon(Icons.tv_outlined, color: Colors.white),
                      //   title: const Text("Screens", style: TextStyle(color: Colors.white)),
                      //   onTap: () {
                      //     Navigator.pop(context);
                      //     _showScreensPage();
                      //   },
                      // ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context);
                              _showScreensPage();
                            },
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            child: ListTile(
                              leading: const Icon(Icons.tv_outlined, color: Colors.white),
                              title: const Text("Screens", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ),
                      ),



                      const Divider(),

                      MenuAnchor(
                        alignmentOffset: const Offset(190, 0),
                        style: MenuStyle(
                          backgroundColor: WidgetStateProperty.all(Color.fromRGBO(242, 242, 247, 0.85)), // iOS-like w/ transparency need to change this like drawer ui
                          elevation: WidgetStateProperty.all(0),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                          visualDensity: VisualDensity.compact,
                        ),
                        builder: (BuildContext context, MenuController controller, Widget? child) {
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    controller.isOpen ? controller.close() : controller.open();
                                    setState(() {}); // rebuild to rotate the arrow
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  splashColor: Colors.white24,
                                  highlightColor: Colors.white10,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.upload, color: Colors.white),
                                        const SizedBox(width: 12),
                                        const Text("Upload Image", style: TextStyle(color: Colors.white, fontSize: 16)),
                                        const Spacer(),
                                        AnimatedRotation(
                                          duration: const Duration(milliseconds: 200),
                                          turns: controller.isOpen ? 0.25 : 0.0, // 90° when open
                                          child: const Icon(Icons.arrow_right, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _takePhoto();
                            },

                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 7, horizontal: 12)),
                              overlayColor: WidgetStateProperty.all(Colors.grey[300]),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.camera_alt, size: 18, color: Colors.black87),
                                SizedBox(width: 8),
                                Text("Camera", style: TextStyle(fontSize: 14, color: Colors.black87)),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.grey),
                          MenuItemButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _chooseFromGallery();
                            },
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 7, horizontal: 12)),
                              overlayColor: WidgetStateProperty.all(Colors.grey[300]),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.photo_library, size: 18, color: Colors.black87),
                                SizedBox(width: 8),
                                Text("Gallery", style: TextStyle(fontSize: 14, color: Colors.black87)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListTile(
                        leading: const Icon(Icons.collections, color: Colors.white), // or Icons.collections
                        title: const Text("Edit Playlists", style: TextStyle(color: Colors.white)),
                        // onTap: () async {
                        //   Navigator.pop(context); // close drawer
                        //   try {
                        //     // final playlists = await getUserPlaylists("billstanton@gmail.com");
                        //     // _showPlaylistBottomSheet(context, playlists);
                        //     _showPlaylistBottomSheet(context, "billstanton@gmail.com");
                        //   } catch (e) {
                        //     ScaffoldMessenger.of(context).showSnackBar(
                        //       SnackBar(content: Text('Error loading playlists')),
                        //     );
                        //   }
                        // },
                        onTap: () async {
                          Navigator.pop(context); // Close the drawer first
                          await _showPlaylistBottomSheet(context, "mannychia7@gmail.com");

                          // Then refresh and rebuild
                          await preloadPlaylistPreviews("mannychia7@gmail.com");
                          setState(() {}); // Rebuild UI with updated cachedPlaylistPreviews
                        },




                      ),

                    ],
                  ),
                ),

                // Bottom Section (Logout)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Column(
                    children: [
                      const Divider(color: Colors.white54),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(4),
                          splashColor: Colors.white24,
                          highlightColor: Colors.white10,
                          onTap: () {
                            Navigator.pop(context);
                            _userLogout();
                          },
                          child: const ListTile(
                            leading: Icon(Icons.logout, color: Colors.white),
                            title: Text("Logout", style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        ),
      ),
      // **********
      /* THE HEADER OF THE 'PLAYERS' PAGE */
      // **********
      appBar: _appBarNoBackBtn(context),
      body:
      RefreshIndicator(
        onRefresh: _refreshData,

        ///*** // trigger the _refreshData function when the user pulls down
        child:
        ListView.separated(
          itemCount: dmbMediaPlayers.length,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            return Align(
              alignment: Alignment.center,
              child: Container(
                //width: 100,
                color: Colors.blueGrey,
                child: Card(

                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                    ),
                    child: InkWell(

                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Ink(
                          width: 500,
                          //The width & height of the 'players' button
                          height: 50,
                          decoration: BoxDecoration( //*** the selectable 'button' of each media player
                            shape: BoxShape.rectangle,
                            border: Border.all(
                                width: 0, //
                                color: const Color.fromRGBO(10, 85, 163, 1.0)
                            ),
                            borderRadius: const BorderRadius.all(
                                Radius.circular(8.0)),
                            gradient: _checkPlayerStatus(index)
                                ? _gradientActiveMediaPlayer(context)
                                : _gradientInActiveMediaPlayer(context),
                          ),

                          ///The two line text on each button
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(dmbMediaPlayers[index].name,
                                        style: const TextStyle(fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _checkPlayerStatus(index)
                                        ? _activeScreenText(context, index)
                                        : _inActiveScreenText(context, index),
                                  ],
                                ),
                              ],
                            ),

                          ),

                        ),
                        onTap: () { //*** When one of the 'Media Players' button is selected .....

                          ///set the global variable of the selected player
                          selectedPlayerName = dmbMediaPlayers[index].name;

                          ///show the user (in a small pop-up) the player name
                          ///that they just selected
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(
                                "${dmbMediaPlayers[index].name} Selected")),
                          );

                          _showScreensPage();

                          /// SHOW LIST OF SCREENS
                        }
                    ),
                  ),
                ),
              ),
            );
          },
          separatorBuilder: (context, index) =>
          const Divider(

            ///the divider between the items
            color: Colors.blueGrey,
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _userLogout,
      //   tooltip: 'Logout',
      //   child: const Icon(Icons.logout),
      // ),
    );
  }

}

///**** This is the 'App bar' to the players tab when you don't want
/// to show a 'back' btn
PreferredSizeWidget _appBarNoBackBtn(BuildContext context) {
  return AppBar(
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Colors.blueGrey, Color.fromRGBO(10, 85, 163, 1.0)],
        ),
      ),
    ),
    automaticallyImplyLeading: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pageTitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        Text(
          pageSubTitle,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    ),
    actions: [
      Builder(
        builder: (context) =>
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
      ),
    ],
  );
}


///**** As the list is being displayed use this object to show a
/// player whose status is 'active'
LinearGradient _gradientActiveMediaPlayer(BuildContext context) {
  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      Colors.blueGrey,
      Color.fromRGBO(10, 85, 163, 1.0),
    ],
  );
}

///**** As the list is being displayed use this object to show a
/// player whose status is 'inactive'
LinearGradient _gradientInActiveMediaPlayer(BuildContext context) {
  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      Colors.blueGrey,
      Colors.red,
    ],
  );
}

///*** As the list is being displayed, show a (slightly) different
/// text (label) to the user for players that are active vs. inactive
Text _activeScreenText(BuildContext context, pIndex) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Current Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: const TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}

Text _inActiveScreenText(BuildContext context, pIndex) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Last Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: const TextStyle(
          fontSize: 10,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}