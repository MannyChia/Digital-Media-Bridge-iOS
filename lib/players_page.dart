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
import 'package:animations/animations.dart';
import 'package:flutter/services.dart';

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
  int _pageIndex = 0;
  String _currentPlaylist = '';
  List<String> _playlistImages = [];
  Set<String> selectedImages = {};

  Set<String> originalPlaylistImages = {};

  void _openPlaylist(String playlistName) async {
    try {
      // Step 1: Fetch all image filenames from API
      final apiUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/api/get_images.php?email=${Uri.encodeComponent(widget.userEmail)}';
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch image filenames');
      }

      final List<dynamic> filenames = json.decode(response.body);
      final List<String> allImageUrls = filenames
          .map((f) =>
      'https://digitalmediabridge.tv/screen-builder-test/assets/content/${Uri.encodeComponent(widget.userEmail)}/images/$f')
          .toList();

      // Step 2: Load playlist file to get selected filenames
      final playlistFileUrl =
          'https://digitalmediabridge.tv/screen-builder-test/assets/content/${Uri.encodeComponent(widget.userEmail)}/others/$playlistName';

      final playlistResponse = await http.get(Uri.parse(playlistFileUrl));
      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to load playlist');
      }

      final lines = LineSplitter()
          .convert(playlistResponse.body)
          .where((line) => line.trim().isNotEmpty)
          .toList();

      final selectedFilenames =
      lines.map((line) => line.split(',').first.trim()).toSet();

      final preSelected = <String>{
        for (final url in allImageUrls)
          if (selectedFilenames.contains(url.split('/').last)) url
      };

      // 🟩 Save the original set for change comparison
      originalPlaylistImages =
          preSelected.map((url) => url.split('/').last).toSet();

      setState(() {
        _playlistImages = allImageUrls;
        selectedImages = preSelected;
        _currentPlaylist = playlistName;
        _pageIndex = 1;
      });
    } catch (e) {
      print("ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load playlist images")),
      );
    }
  }


  bool _hasPlaylistChanged() {
    final selectedFilenames = selectedImages.map((url) => url.split('/').last).toSet();
    return selectedFilenames.isNotEmpty && !setEquals(selectedFilenames, originalPlaylistImages);
  }



  Future<void> _refreshPlaylistPreviews() async {
    try {
      final updated = await fetchPlaylistPreviews(widget.userEmail);
      setState(() {
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
    return Column(
      key: const ValueKey(0),
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: const [
              Text(
                'Edit Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.playlist_add, color: Colors.white, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: cachedPlaylistPreviews.length,
            itemBuilder: (context, index) {
              final preview = cachedPlaylistPreviews[index];
              return InkWell(
                onTap: () => _openPlaylist(preview.name),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child:
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          color: Colors.grey[700],
                          child: Image.network(
                            preview.previewImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${preview.name} (${preview.itemCount})',
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
        ),
      ],
    );
  }


  Widget _buildImageView(ScrollController scrollController) {
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
                  await _refreshPlaylistPreviews(); //This re-fetches the updated data
                  setState(() {
                    _pageIndex = 0;
                  });
                },

              ),
              title: Text(
                _currentPlaylist,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                "${selectedImages.length} selected",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 70, top: 12), // leave space for the Save button
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
                        isSelected
                            ? selectedImages.remove(imageUrl)
                            : selectedImages.add(imageUrl);
                      });
                    },

                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                              ),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white70),
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
                                  ? Colors.greenAccent.withOpacity(0.9)
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
            onPressed: _hasPlaylistChanged() ? () => _onSavePressed() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasPlaylistChanged() ? Colors.greenAccent : Colors.grey[700],
              foregroundColor: _hasPlaylistChanged() ? Colors.black : Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  void _onSavePressed() async {
    final selectedFilenames = selectedImages.map((url) => url.split('/').last).toList();

    final success = await updatePlaylist(
      userEmail: widget.userEmail,
      playlistFileName: _currentPlaylist,
      selectedFilenames: selectedFilenames,
    );

    if (success) {
      originalPlaylistImages = selectedFilenames.toSet();
      setState(() {}); // Refresh UI to disable Save button
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Playlist updated")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to update playlist")),
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

  //photo taken from camera
  Future<void> _takePhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Show image in a popup dialog with "Post" and "Close"
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              backgroundColor: Colors.black,
              content: Image.file(_image!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                      "Close", style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close dialog before posting
                    // TODO: Replace with actual username/email
                    bool success = await uploadImage(
                        _image!, "mannychia7@gmail.com");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? "Image uploaded successfully"
                              : "Image upload failed",
                        ),
                      ),
                    );
                  },
                  child: const Text(
                      "Post", style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _chooseFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });

      // Show image in a popup dialog with "Post" and "Close"
      showDialog(
        context: context,
        builder: (_) =>
            AlertDialog(
              backgroundColor: Colors.black,
              content: Image.file(_image!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                      "Close", style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close dialog before posting
                    //TODO: make sure to change account name
                    bool success = await uploadImage(
                        _image!, "mannychia7@gmail.com");
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Image uploaded successfully")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Image upload failed")),
                      );
                    }
                  },
                  child: const Text(
                      "Post", style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            ),
      );
    }
  }

  void _showPlaylistBottomSheet(BuildContext context, String userEmail) {
    if (!hasLoadedPlaylistPreviews || cachedPlaylistPreviews.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Playlists are still loading...")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PlaylistSheet(userEmail: userEmail),
    );

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
                      ListTile(
                        leading: const Icon(Icons.tv_outlined, color: Colors.white),
                        title: const Text("Screens", style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          _showScreensPage();
                        },
                      ),
                      MenuAnchor(
                        alignmentOffset: const Offset(190, 0),
                        builder: (BuildContext context, MenuController controller, Widget? child) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            onTap: () {
                              controller.isOpen ? controller.close() : controller.open();
                            },
                            title: Row(
                              children: const [
                                Icon(Icons.upload, color: Colors.white),
                                SizedBox(width: 16),
                                Text("Upload Image", style: TextStyle(color: Colors.white)),
                                Spacer(),
                                Icon(Icons.arrow_drop_down, color: Colors.white),
                              ],
                            ),
                          );
                        },
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _takePhoto();
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.camera_alt, size: 20),
                                SizedBox(width: 8),
                                Text("Camera"),
                              ],
                            ),
                          ),
                          const Divider(),
                          MenuItemButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _chooseFromGallery();
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.photo_library, size: 20),
                                SizedBox(width: 8),
                                Text("Gallery"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListTile(
                        leading: const Icon(Icons.collections, color: Colors.white), // or Icons.collections
                        title: const Text("Playlists", style: TextStyle(color: Colors.white)),
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
                        onTap: () {
                          Navigator.pop(context);
                          _showPlaylistBottomSheet(context, "mannychia7@gmail.com");
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
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.white),
                        title: const Text("Logout", style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          _userLogout();
                        },
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