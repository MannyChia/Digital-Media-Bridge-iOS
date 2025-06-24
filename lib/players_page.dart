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

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
          .map((f) => 'https://digitalmediabridge.tv/screen-builder/assets/content/'
          '${Uri.encodeComponent(widget.userEmail)}/images/$f')
          .toList();

      // 2) load the .pl file under its screen folder
      final encodedScreen = Uri.encodeComponent(screenName);
      final encodedPl     = Uri.encodeComponent(playlistName);
      final playlistFileUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/content/'
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
                Text(
                  'Edit Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.playlist_add, color: Colors.white, size: 23),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                'No current playlist',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                ),
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
    final entries = groups.entries.toList();

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
          padding: const EdgeInsets.fromLTRB(16,0,16,12),
          child: Row(
            children: const [
              Text(
                'Edit Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.playlist_add, color: Colors.white, size: 23),
            ],
          ),
        ),
        // const Divider(
        //   color: Colors.grey,
        //   thickness: 1,
        //   height: 1,
        // ),
        // const SizedBox(height: 8),

        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                // ... is a spread tool (jsyk)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

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
                  itemCount: entries[i].value.length,
                  itemBuilder: (context, idx) {
                    final preview = entries[i].value[idx];
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
  TextEditingController _textFieldController = TextEditingController();
  String? _generatedImageUrl;
  bool _isGenerating = false; // Track image generation state
  String backgroundURL = "https://lp-cms-production.imgix.net/2023-02/3cb45f6e59190e8213ce0a35394d0e11-nice.jpg"; // URL for background image

  ///This 'override' function is called once when the class is loaded
  ///(is used to update the pageTitle * subTitle)
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

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

  /// returns true if player status at given index is active, false otherwise
  bool _checkPlayerStatus(int index) {
    return dmbMediaPlayers[index].status == "Active";
  }

  /// logs user out of their account
  void _userLogout() {
    confirmLogout(context); //*** CONFIRM USER LOGOUT (function is in: dmb_functions.dart)
  }

  //Call this when the user pulls down the screen
  Future<void> _refreshData() async {
    try {
      //Go to the DMB server to get an updated list of players
      getUserData("$loginUsername", "$loginPassword", "players-refresh").then((result) {
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
      }
      );
    }
    catch (err) {
      print("Error refreshing data");
    }
  }

  // change from pop up dialog to a sheet to make consistent ui throughout
  // remember your future, async
  Future<void> _showUploadSheet(File imageFile) async {
    // save screen width and height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

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

                    final result = await uploadImage(imageFile, loginUsername);

                    final bool success = result['success'] as bool;
                    final String message = result['message'] as String;

                    if (!success) {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            message.contains('20') ? "Upload Limit Reached" : "Upload Failed",
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
                        SnackBar(content: Text(message)),
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
    // 1) Ensure we've preloaded the playlist data
    await preloadPlaylistPreviews(userEmail);

    // 2) Open the bottom sheet (it will render "No current playlist" itself if the list is empty)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PlaylistSheet(userEmail: userEmail),
    );

    // 3) When the sheet closes, refresh the cached previews for next time
    try {
      cachedPlaylistPreviews = await fetchPlaylistPreviews(userEmail);
      hasLoadedPlaylistPreviews = true;
    } catch (e) {
      print("Failed to refresh playlist previews: $e");
    }
  }

  /// generates photo using Leonardo.ai API key
  /// edit this function if we change services (Leonardo, Open AI, etc)
  Future<Map<String, dynamic>?> _getAIPhoto(String prompt, int width, int height, {String? prevImageID}) async {
    // model IDs
    String stable_diffusion = "aa77f04e-3eec-4034-9c07-d0f619684628";

    if (!dotenv.isInitialized) {
      if (mounted) { // checks is a state object is still part of the widget tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Environment variables not loaded')),
        );
      }
      return null;
    }

    final apiKey = dotenv.env['LEONARDO_API_KEY']; // gets the API key, stored in the private .env file

    if (apiKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API key not found in .env file')),
        );
      }
      return null;
    }

    if (prompt.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a prompt')),
        );
      }
      return null;
    }

    final url = Uri.parse('https://cloud.leonardo.ai/api/rest/v1/generations');

    // headers for API call
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    String body = ""; // define based on argument count

    // if prevUrl is not passed in, generate photo just based off prompt
    if (prevImageID == null) {
      print("generating body in _getAIPhoto using just prompt");
      body = jsonEncode({
        'prompt': prompt,
        'modelId': stable_diffusion,
        'num_images': 1,
        'width': width,
        'height': height,
      });
    }

    // else prevImageID was passed in, so generate photo based off prevUrl and prompt
    else {
      print("generating body in _getAIPhoto using prompt and prevImageID");
      body = jsonEncode({
        'prompt': prompt,
        'modelId': stable_diffusion,
        'init_image_id': prevImageID,
        'init_strength': 0.4, // how closely to stick to given image (0-1)
        'num_images': 1,
        'width': width,
        'height': height,
        'guidance_scale': 5,  // how closely to follow prompt (higher -> closer to prompt)
      });
    }

    try {
      final response = await http.post(url, headers: headers, body: body); // call the API

      // response code == 200 means successful response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generationId = data['sdGenerationJob']?['generationId'];

        if (generationId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No generation ID received')),
            );
          }
          return null;
        }

        final pollUrl = Uri.parse('https://cloud.leonardo.ai/api/rest/v1/generations/$generationId');
        bool isCompleted = false;
        String? imageUrl; // URL to the generated Image
        String? imageId; // unique ID of the generated Image

        // make continuous calls to the API until image is received or it times out
        for (int i = 0; i < 30; i++) {
          await Future.delayed(Duration(seconds: 1));
          final pollResponse = await http.get(pollUrl, headers: headers);

          if (pollResponse.statusCode == 200) {
            final pollData = jsonDecode(pollResponse.body);
            final status = pollData['generations_by_pk']?['status'];

            if (status == 'COMPLETE') { // exit the loop - image has been received in full
              isCompleted = true;
              final generatedImage = pollData['generations_by_pk']?['generated_images']?[0]; // first image
              imageUrl = generatedImage['url']?.toString(); // initialize imageUrl
              imageId = generatedImage['id']?.toString(); // initialize imageID
              break;
            }
            else if (status == 'FAILED') {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Image generation failed')),
                );
              }
              return null;
            }
          }
          else {
            print('Poll Error: ${pollResponse.statusCode} - ${pollResponse.body}');
          }
        }

        if (!isCompleted || imageUrl == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image generation timed out or no image received')),
            );
          }
          return null;
        }

        print('Generated Image URL: $imageUrl');
        return {'image_id': imageId, 'image_url': imageUrl}; // return a Map with the imageId and imageUrl
      }
      else {
        print('API Error: ${response.statusCode} - ${response.body}');
        String errorMsg;
        switch (response.statusCode) { // identify the error
          case 401:
            errorMsg = 'Invalid API key. Please check your credentials.';
            break;
          case 429:
            errorMsg = 'Rate limit exceeded. Please try again later.';
            break;
          case 400:
            errorMsg = 'Invalid request: ${response.body}';
            break;
          default:
            errorMsg = 'Error: ${response.statusCode} - ${response.body}';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        return null;
      }
    }
    catch (e) {
      print('Request Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return null;
    }
  }

  /// call this function when the user clicks 'New Photo' after generating one
  void onNewPhoto() {
    Navigator.of(context).pop(); // Close the image dialog
    setState(() {
      _generatedImageUrl = null; // Clear the previous image
      _textFieldController.clear(); // Clear the text field for new input
    });
    _showAIPromptDialog(); // let the user generate a new photo, forgetting the previous one
  }

  /// call this function when the user clicks 'Edit Photo' after generating one
  void onEdit(String prevImageID) {
    Navigator.of(context).pop(); // Close the image dialog
    setState(() {
      _generatedImageUrl = null; // Clear the previous image
      _textFieldController.clear(); // Clear the text field for new input
    });
    _showAIPromptDialog(prevImageID: prevImageID); // let the user generate a new photo based off of a new prompt and the previous photo

  }

  Future<void> onSubmit(String imageUrl, String username) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download image")),
        );
        print("ERROR ON onSubmit FUNCTION!");
        return;
      }

      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final filename = path.basename(imageUrl);
      final tempFile = File("${tempDir.path}/$filename");
      await tempFile.writeAsBytes(bytes);

      // Change upload and get back a Map<String, dynamic>
      final result = await uploadImage(tempFile, username);
      final bool success = result['success'] as bool;
      final String message = result['message'] as String;

      // delete the temp file if upload succeeded
      if (success) {
        await tempFile.delete();
      }

      // grab server’s message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      // Close the image dialog no matter what
      Navigator.of(context).pop();
    }
  }


  /// show the loading circle between when user submits prompt to when photo is displayed
  void showLoadingCircle(BuildContext context) {
    // save screen width and height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents tapping outside to dismiss
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator( // loading button
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  SizedBox(height: screenWidth * 0.1),
                  Text(
                    "Generating Image...",
                    style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.1),
                  ),
                  const SizedBox(height: 10),
                  TextButton( // cancel button
                    onPressed: () {
                      Navigator.of(context).pop(); // Close loading dialog
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// helper function to create and display the image
  Future<void> _generateAndShowImage(String inputPrompt, BuildContext dialogContext, {String? prevImageID}) async {
    // save screen width and height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    print("Starting _generateAndShowImage with prompt: $inputPrompt");

    Map<String?, dynamic>? ai_image; // map that stores the ImageUrl and ImageID

    if (prevImageID == null) { // generate just based off prompt
      print("Calling _getAIPhoto just based on prompt");
      ai_image = await _getAIPhoto(inputPrompt, 1536, 864);
    }
    else { // generate based off prompt and the previous Image
      print("Calling _getAIPhoto based on prompt and prevImageID");
      ai_image = await _getAIPhoto(inputPrompt, 1536, 864, prevImageID: prevImageID);
    }
    String? imageUrl = ai_image?['image_url'];
    String? imageId = ai_image?['image_id'];

    print("Image generation result: URL=$imageUrl, ID=$imageId");
    Navigator.of(dialogContext).pop(); // Dismiss the loading dialog

    if (imageUrl != null && imageId != null) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Image generated successfully')),
      );
      try {
        // show image in slide up box
        await showModalBottomSheet(
            context: dialogContext,
            backgroundColor: Colors.grey[900],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            isScrollControlled: true, // allows user to scroll
            builder: (BuildContext context) {
              return Padding(
                  padding: const EdgeInsets.all(16.0), // padding on all sides
                  child: Column(
                      mainAxisSize: MainAxisSize.min, // take up minimum space
                      children: [
                        const Text("AI Generated Image", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        // first child - the image that was generated
                        GestureDetector(
                          onTap: () {
                            // Show a dialog with the enlarged image
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Dialog(
                                  backgroundColor: Colors.black.withOpacity(0.8), // Semi-transparent background
                                  child: Stack(
                                    children: [
                                      // Display the enlarged image
                                      Center(
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain, // Ensure the image fits within the dialog
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                              ),
                                            );
                                          },

                                          errorBuilder: (context, error, stackTrace) {
                                            print("Error loading image: $error");
                                            return const Text(
                                              "Failed to load image",
                                              style: TextStyle(color: Colors.white),
                                            );
                                          },
                                        ),
                                      ),
                                      // Close button
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () {
                                            Navigator.of(context).pop(); // Close the dialog
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print("Error loading image: $error");
                                return const Text(
                                  "Failed to load image",
                                  style: TextStyle(color: Colors.white),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // second child - a row with buttons 'New Photo' and 'Edit Photo'
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                print("New Photo button pressed");
                                onNewPhoto();
                              },
                              child: const Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text("New Photo"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        // third child - 'Close' and 'Upload' buttons
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton( // close image pop up
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("Close", style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                                onPressed: () async {
                                  onSubmit(imageUrl, loginUsername);
                                },
                                child: const Text("Upload"),
                              )
                            ]
                        )
                      ]
                  )
              );
            }
        );
        print("Image dialog shown successfully");
      }
      catch (e) {
        print("Error showing image dialog: $e");
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Error displaying image: $e')),
          );
        }
      }
    }
    else {
      print("Showing failure snackbar");
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Failed to generate a valid image URL or ID')),
        );
      }
    }
  }

  /// shows the prompt text box and takes in user input
  Future<void> _showAIPromptDialog({String? prevImageID}) async {
    // save screen width and height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    final dialogContext = context; // Store state context
    await showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text("Enter your prompt", style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.05)),
          ),
          backgroundColor: Colors.blueGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(
              hintText: "Example: Show me happy cashier", // goes away when user starts to input data
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
            ),
            onSubmitted: (value) async {
              final prompt = value.trim(); // save given prompt
              if (prompt.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a prompt')),
                );
                return;
              }
              Navigator.of(context).pop(); // Close prompt dialog

              showLoadingCircle(dialogContext);
              await _generateAndShowImage(prompt, dialogContext, prevImageID: prevImageID);
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final prompt = _textFieldController.text.trim();
                if (prompt.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a prompt')),
                  );
                  return;
                }
                Navigator.of(context).pop(); // Close prompt dialog

                showLoadingCircle(dialogContext);
                await _generateAndShowImage(prompt, dialogContext, prevImageID: prevImageID);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: _isGenerating ? 8 : 4),
                  const Text('Create Image', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        );
      },
    );
    _textFieldController.clear(); // clear the text controller
  }


  final List<String> uploadOptions = ['Camera', 'Gallery', 'Create Image'];
  String? selectedOption;

  /// menu on the left of the screen
  @override
  Widget build(BuildContext context) {
    // save screen width and height
    final double vw = MediaQuery.of(context).size.width / 100; // width of screen (by percentage)
    final double vh = MediaQuery.of(context).size.height / 100; // height of screen (by percentage)

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white, // in case the image fails to load
      endDrawer: SizedBox(
        width: vw * 60, // 60% of the screen
        child: Drawer(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(vw * 2),
                          child: Text(
                            "Menu",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: vw * 5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: vw * 2),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(vw * 2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(vw * 2),
                              onTap: () {
                                Navigator.pop(context);
                                _showScreensPage();
                              },
                              splashColor: Colors.white24,
                              highlightColor: Colors.white10,
                              child: ListTile(
                                leading: Icon(
                                  Icons.tv_outlined,
                                  color: Colors.orange,
                                  size: vw * 6,
                                ),
                                title: Text(
                                  "My Screens",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.black),
                        DropdownButton2<String>(
                          isExpanded: true,
                          customButton: Container(
                            padding: EdgeInsets.symmetric(horizontal: vw * 4),
                            height: vh * 10,
                            width: vw * 60,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(vw * 2),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 6),
                                Icon(
                                  Icons.upload,
                                  color: Colors.orange,
                                  size: vw * 6,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Upload Image",
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: vw * 4,
                                ),
                              ],
                            ),
                          ),
                          underline: Container(),
                          items: uploadOptions.map((String value) {
                            IconData iconData;
                            if (value == 'Camera') {
                              iconData = Icons.camera_alt;
                            } else if (value == 'Gallery') {
                              iconData = Icons.photo_library;
                            } else if (value == 'Create Image') {
                              iconData = Icons.auto_awesome;
                            } else {
                              iconData = Icons.help_outline;
                            }
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  SizedBox(width: 5),
                                  Icon(
                                    iconData,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    value,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          value: selectedOption,
                          onChanged: (String? newValue) async {
                            if (newValue == 'Camera') {
                              _takePhoto();
                            } else if (newValue == 'Gallery') {
                              _chooseFromGallery();
                            } else if (newValue == 'Create Image') {
                              _showAIPromptDialog();
                            }
                          },
                          buttonStyleData: ButtonStyleData(
                            padding: EdgeInsets.symmetric(horizontal: vw * 4),
                            height: 8,
                            width: 50,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            maxHeight: vh * 25,
                            decoration: const BoxDecoration(
                              color: Colors.blueGrey,
                            ),
                          ),
                          menuItemStyleData: MenuItemStyleData(
                            height: vh * 5,
                          ),
                        ),
                        const Divider(color: Colors.black),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: vw * 2),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(vw * 2),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(vw * 2),
                              onTap: () async {
                                Navigator.pop(context); // Close the drawer first
                                await _showPlaylistBottomSheet(context, loginUsername);

                                // Then refresh and rebuild
                                await preloadPlaylistPreviews(loginUsername);
                                setState(() {}); // Rebuild UI with updated cachedPlaylistPreviews
                              },
                              splashColor: Colors.white24,
                              highlightColor: Colors.white10,
                              child: ListTile(
                                leading: Icon(
                                  Icons.collections,
                                  color: Colors.orange,
                                  size: vw * 6,
                                ),
                                title: Text(
                                  "Edit Playlists",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Divider(color: Colors.black),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: vh * 1),
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(vw * 1),
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            onTap: () {
                              Navigator.pop(context);
                              _userLogout();
                            },
                            child: ListTile(
                              leading: Icon(
                                Icons.logout,
                                color: Colors.orange,
                                size: vw * 5,
                              ),
                              title: Text(
                                "Logout",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: vw * 5,
                                ),
                              ),
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
      ),
      appBar: _appBarNoBackBtn(context),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              backgroundURL.isNotEmpty
                  ? backgroundURL
                  : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?fit=crop&w=1536&h=864', // Fallback image
            ),
            fit: BoxFit.cover, // Adjusts image to cover the entire background
            onError: (exception, stackTrace) {
              print('Failed to load background image: $exception');
            },
          ),
        ),
        child: RefreshIndicator( // list of players
          onRefresh: _refreshData,
          child: ListView.separated(
            padding: EdgeInsets.only(top: vh * 1, left: vw * 6, right: vw * 6, bottom: vh * 1.5), // 1% of screen padding above first Player
            itemCount: dmbMediaPlayers.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int index) {
              return Align(
                alignment: Alignment.center,
                child: Container(
                  color: Colors.transparent,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(),
                      child: InkWell(
                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Ink(
                          width: vw * 90,
                          height: vh * 10, // 10% of the screen height
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              width: 2,
                              color: const Color.fromRGBO(10, 85, 163, 1.0),
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                            gradient: _checkPlayerStatus(index)
                                ? _gradientActiveMediaPlayer(context)
                                : _gradientInActiveMediaPlayer(context),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dmbMediaPlayers[index].name,
                                      style: TextStyle(
                                        fontSize: (vw * 5),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _checkPlayerStatus(index)
                                        ? _activeScreenText(context, index, vw)
                                        : _inActiveScreenText(context, index, vw),
                                  ],
                                ),
                              ],
                            ),

                          ),

                        ),
                        onTap: () {
                          selectedPlayerName = dmbMediaPlayers[index].name;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${dmbMediaPlayers[index].name} Selected")),
                          );
                          _showScreensPage();
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) => const Divider(color: Colors.black),
          ),
        ),
      ),
    );
  }
}

///**** This is the 'App bar' to the players tab when you don't want
/// to show a 'back' btn
PreferredSizeWidget _appBarNoBackBtn(BuildContext context) {
  // Calculate viewport units
  final double vw = MediaQuery.of(context).size.width / 100;
  final double vh = MediaQuery.of(context).size.height / 100;

  return PreferredSize(
    preferredSize: Size.fromHeight(vh * 11), // 11% of screen height
    child: AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF424242),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)],
          ),
        ),
      ),
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pageTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: vw * 6, // Increase font size to 6% of smaller dimension
            ),
          ),
          Text(
            pageSubTitle,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white,
              fontSize: vw * 5.5, // Increase font size to 5% of smaller dimension
            ),
          ),
        ],
      ),
      titleSpacing: vw * 4, // Add padding to the left of the title (4% of screen width)
      toolbarHeight: vh * 12, // Match toolbarHeight to preferredSize height
      actions: [
        Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: Colors.white,
              size: vw * 8, // Increase icon size to 8% of smaller dimension
            ),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            padding: EdgeInsets.all(vw * 2), // Add padding around icon
          ),
        ),
      ],
    ),
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
Text _activeScreenText(BuildContext context, pIndex, vw) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Current Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}

Text _inActiveScreenText(BuildContext context, pIndex, vw) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Last Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: Colors.white70)
  );
}