import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import './main.dart';
import 'package:fluttertoast/fluttertoast.dart';

import './screens_page.dart';
import './dmb_functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons; // Still needed for icon constants
import 'package:flutter/services.dart';
import 'Models/playlist_preview.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

dynamic activeDMBPlayers = 0;

class MediaPlayer {
  String name, status, currentScreen;

  MediaPlayer(
      {required this.name, required this.status, required this.currentScreen});
}

List<MediaPlayer> dmbMediaPlayers = [];
dynamic selectedPlayerName;

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
  bool _isLoading = true; // display loading circle when playlists are loading
  Color darkGreen = Color(0xFF006400); 

  @override 
  void initState() {
    super.initState();
    _refreshPlaylistPreviews(); // fetch playlists on init
  }

  void _openPlaylist(String screenName, String playlistName) async {
    try {
      _currentScreenName = screenName;
      _currentPlaylist = playlistName;
      final apiUrl = 'https://digitalmediabridge.tv/screen-builder/assets/api/'
          'get_images.php?email=${Uri.encodeComponent(widget.userEmail)}';
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch image filenames');
      }
      final filenames = json.decode(response.body) as List<dynamic>;
      final allImageUrls = filenames
          .map((f) =>
              'https://digitalmediabridge.tv/screen-builder/assets/content/'
              '${Uri.encodeComponent(widget.userEmail)}/images/$f')
          .toList();
      final encodedScreen = Uri.encodeComponent(screenName);
      final encodedPl = Uri.encodeComponent(playlistName);
      final playlistFileUrl =
          'https://digitalmediabridge.tv/screen-builder/assets/content/'
          '${Uri.encodeComponent(widget.userEmail)}/others/'
          '$encodedScreen/$encodedPl';
      final playlistResponse = await http.get(Uri.parse(playlistFileUrl));
      if (playlistResponse.statusCode != 200) {
        throw Exception('Failed to load playlist');
      }
      final lines = const LineSplitter()
          .convert(playlistResponse.body)
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final selectedFilenames =
          lines.map((l) => l.split(',').first.trim()).toSet();
      final preSelected = <String>{
        for (final url in allImageUrls)
          if (selectedFilenames.contains(url.split('/').last)) url
      };
      originalPlaylistImages =
          preSelected.map((url) => url.split('/').last).toSet();
      setState(() {
        _playlistImages = allImageUrls;
        selectedImages = preSelected;
        _pageIndex = 1;
      });
    } catch (e) {
      if (kDebugMode) {
        print("ERROR: $e");
      }
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to load playlist images'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  }

  bool _hasPlaylistChanged() {
    final selectedFilenames =
        selectedImages.map((url) => url.split('/').last).toSet();
    return selectedFilenames.isNotEmpty &&
        !setEquals(selectedFilenames, originalPlaylistImages);
  }

  Future<void> _refreshPlaylistPreviews() async {
    try {
      final updated = await fetchPlaylistPreviews(widget.userEmail);
      setState(() {
        cachedPlaylistPreviews = updated;
        hasLoadedPlaylistPreviews = true;
        _isLoading = false; // hide loading circle when playlists load
      });
    }
    catch (e) {
      if (kDebugMode) {
        print("Failed to refresh playlist previews: $e");
      }
      setState(() {
        _isLoading = false; // even if playlists don't load, hide loading circle
      });
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to load playlists'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)), 
            ),
            child: _isLoading
              ? Center(
                  child: CupertinoActivityIndicator(),
              )
              : AnimatedSwitcher(
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
    final double vw = MediaQuery.of(context).size.width / 100;
    if (cachedPlaylistPreviews.isEmpty) {
      return Column(
        key: const ValueKey(0),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
              color: CupertinoColors.systemGrey,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Edit Image Playlists',
                  style: TextStyle(
                    color: CupertinoColors.systemGrey2,
                    fontSize: vw * 7,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.add, color: CupertinoColors.systemGrey2, size: vw * 7),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: Text(
                'No current playlist',
                style: TextStyle(
                  color: CupertinoColors.systemGrey2,
                  fontSize: 24,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      );
    }

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
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Edit Image Playlists',
                style: TextStyle(
                  color: CupertinoColors.systemGrey2,
                  fontSize: vw * 7,
                ),
              ),
              SizedBox(width: 6),
              Icon(CupertinoIcons.add, color: CupertinoColors.systemGrey2, size: vw * 7),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          "Screen: ",
                          style: TextStyle(
                              color: CupertinoColors.systemGrey2, fontSize: vw * 5.5),
                        ),
                        Text(
                          entries[i].key,
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontSize: vw * 5.5,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      ]),
                ),
                const SizedBox(height: 8),
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
                    final displayName = preview.name.endsWith('.pl')
                        ? preview.name.substring(0, preview.name.length - 3)
                        : preview.name;
                    return GestureDetector(
                      onTap: () =>
                          _openPlaylist(preview.screenName, preview.name),
//                       borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                color: CupertinoColors.systemGrey2,
                                child: preview.previewImageUrl != null
                                    ? Image.network(
                                        preview.previewImageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Center(
                                            child: Icon(CupertinoIcons.exclamationmark_triangle,
                                              color: CupertinoColors.systemGrey2),
                                            ),
                                      )
                                    : Container(
                                        color: CupertinoColors.systemGrey3,
                                        child: const Center(
                                          child: Icon(CupertinoIcons.photo_fill,
                                              color: CupertinoColors.systemGrey2, size: 40),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  '$displayName (${preview.itemCount})',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: vw * 4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ])
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
                  color: CupertinoColors.systemGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque, // larger tap area
                  onTap: () async {
                    await _refreshPlaylistPreviews();
                    setState(() {
                      _pageIndex = 0;
                    });
                  },
                  child: const Icon(
                    CupertinoIcons.back,
                    color: CupertinoColors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  "${selectedImages.length} selected",
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey2,
                    fontSize: 13,
                  ),
                ),
              ],
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
                    behavior: HitTestBehavior.opaque, // larger tap area
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
                              color: CupertinoColors.systemGrey4,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                  child: Icon(CupertinoIcons.exclamationmark_triangle,
                                  color: CupertinoColors.systemGrey2,
                                ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                // Billy fill free to mess with the opacity
                                color: CupertinoColors.black.withOpacity(0.3),
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
                              color: isSelected ? CupertinoColors.activeGreen : CupertinoColors.black.withOpacity(0.4),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isSelected ? CupertinoIcons.check_mark : CupertinoIcons.circle,
                              size: 16,
                              color: isSelected ? CupertinoColors.black : CupertinoColors.white,
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
        bottom: 60,
        left: 16,
        right: 16,
        child: CupertinoButton.filled(
          color: darkGreen,
          onPressed: _hasPlaylistChanged() ? _onSavePressed : null,
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: BorderRadius.circular(10),
          child: const Text(
            'Save Playlist',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(height: 40),
    ],
  );
}
//         Positioned(
//           bottom: 60,
//           left: 16,
//           right: 16,
//           child: CupertinoButton.filled(
//             onPressed: _hasPlaylistChanged() ? _onSavePressed : null,
//             style: ElevatedButton.styleFrom(
//               backgroundColor:
//                   _hasPlaylistChanged() ? Colors.green : Colors.grey[700],
//               foregroundColor:
//                   _hasPlaylistChanged() ? Colors.black : Colors.white54,
//               padding: const EdgeInsets.symmetric(vertical: 16),
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child: const Text(
//               'Save Playlist',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),
//         ),
//         SizedBox(height: 40),
//       ],
//     );
//   }

  void _onSavePressed() async {
    final selectedFilenames =
        selectedImages.map((url) => url.split('/').last).toList();
    final fullFileName = '$_currentScreenName/$_currentPlaylist';
    final success = await updatePlaylist(
      userEmail: widget.userEmail,
      playlistFileName: fullFileName,
      selectedFilenames: selectedFilenames,
    );
    if (success) {
      originalPlaylistImages = selectedFilenames.toSet();
      cachedPlaylistPreviews = await fetchPlaylistPreviews(widget.userEmail);
      setState(() {});
   await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Playlist updated successfully.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () {
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  } else {
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: const Text('Failed to update playlist.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
}
class PlayersPage extends StatefulWidget {
  final String userEmail;

  const PlayersPage(
      {super.key,
      this.mainPageTitle,
      this.mainPageSubTitle,
      required this.userEmail});

  final String? mainPageTitle;
  final String? mainPageSubTitle;

  @override
  _PlayersPageState createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  late String mainPageTitle;
  late String mainPageSubTitle;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textFieldController = TextEditingController();
  final bool _isGenerating = false;
  String backgroundURL = dotenv.env['BACKGROUND_IMAGE_URL']!;
  Color darkGreen = Color(0xFF006400); 
  // final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
  //     GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _updateTitle();
    _refreshData();
  }

  void _updateTitle() {
    mainPageTitle = "${widget.mainPageTitle} (${dmbMediaPlayers.length})";
    mainPageSubTitle = widget.mainPageSubTitle ?? "";
  }

  // final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;

void _showScreensPage(bool onPlayer) {
  final String title = onPlayer
      ? "Player: $selectedPlayerName"
      : "Available Screens";
  final String subtitle = onPlayer
      ? "Select Screen to Publish"
      : "Return to Menu to Select Player";

  Navigator.push(
    context,
    CupertinoPageRoute(
      builder: (context) => ScreensPage(
        screensPageTitle: title,
        screensPageSubTitle: subtitle,
      ),
    ),
  );
}


  bool _checkPlayerStatus(int index) {
    return dmbMediaPlayers[index].status == "Active";
  }

  void _userLogout() {
    cachedPlaylistPreviews.clear();
    confirmLogout(context);
  }

  Future<void> _refreshData() async {
    try {
      getUserData("$loginUsername", "$loginPassword", "players-refresh")
          .then((result) {
        if (result.runtimeType != String) {
          setState(() {
            dmbMediaPlayers = result;
            mainPageTitle = "DMB Media Players (${dmbMediaPlayers.length})";
            mainPageSubTitle = "Select Player";
          });
        }
      });
    } catch (err) {
      if (kDebugMode) {
        print("Error refreshing data");
      }
    }
  }

  Future<void> _showUploadSheet(File imageFile) async {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => SafeArea(
        child: Container(
          // Let height be flexible
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.9,
          ),
          decoration: const BoxDecoration(
            color: CupertinoColors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
            child: SingleChildScrollView( // ✅ Add scroll behavior
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Text(
                    "Upload Image to Account",
                    style: TextStyle(
                      fontSize: screenWidth * 0.07,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemGrey6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: CupertinoColors.black,
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
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text("Close", style: TextStyle(color: CupertinoColors.systemGrey6)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      CupertinoButton.filled(
                        color: darkGreen,
                        child: const Text("Upload"),
                        onPressed: () async {
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                          final result = await uploadImage(imageFile, loginUsername);
                          final bool success = result['success'] as bool;
                          final String message = result['message'] as String;
                          if (!success) {
                            await showCupertinoDialog(
                              context: context,
                              builder: (_) => CupertinoAlertDialog(
                                title: Text(
                                  message.contains('20')
                                      ? "Upload Limit Reached"
                                      : "Upload Failed",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                content: Text(
                                  message.contains('20')
                                      ? "You cannot upload more than 20 images. Please delete one first."
                                      : message,
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    isDefaultAction: true,
                                    child: const Text("OK"),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ),
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

  Future<void> _showPlaylistBottomSheet(
      BuildContext context, String userEmail) async {
    await showCupertinoModalPopup(
      context: context,
    builder: (_) {
      final height = MediaQuery.of(context).size.height * 0.75;
      return SafeArea(
        child: SizedBox(
          height: height,
          child: PlaylistSheet(userEmail: userEmail),
        ),
      );
    },
  );
    try {
      cachedPlaylistPreviews = await fetchPlaylistPreviews(userEmail);
      hasLoadedPlaylistPreviews = true;
    } catch (e) {
      if (kDebugMode) {
        print("Failed to refresh playlist previews: $e");
      }
    }
  }

  Future<Map<String, dynamic>?> _getAIPhoto( String prompt, int width, int height, {String? prevImageID}) async {
    final stableDiffusion = dotenv.env['STABLE_DIFFUSION_KEY']!;
    final lucidRealism = dotenv.env['LUCID_REALISM_KEY']!;
    if (!dotenv.isInitialized) {
      if (kDebugMode) {
        print("ENVIRONMENTAL VARIABLES NOT LOADED");
      }
    }
    final apiKey = dotenv.env['LEONARDO_API_KEY_2'];
    if (apiKey == null) {
      if (kDebugMode) {
        print("API KEY NOT FOUND IN .env FILE");
      }
    }
    final url = Uri.parse('https://cloud.leonardo.ai/api/rest/v1/generations');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    String body = "";
    if (prevImageID == null) {
      if (kDebugMode) {
        print("generating body in _getAIPhoto using just prompt");
      }
      body = jsonEncode({
        'prompt': prompt,
        'modelId': lucidRealism,
        'num_images': 1,
        'width': width,
        'height': height,
      });
    } else {
      if (kDebugMode) {
        print("generating body in _getAIPhoto using prompt and prevImageID");
      }
      body = jsonEncode({
        'prompt': prompt,
        'modelId': stableDiffusion,
        'init_image_id': prevImageID,
        'init_strength': 0.4,
        'num_images': 1,
        'width': width,
        'height': height,
        'guidance_scale': 5,
      });
    }

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generationId = data['sdGenerationJob']?['generationId'];
        if (generationId == null) {
          if (kDebugMode) {
            print("No generation ID received");
          }
        }
        final pollUrl = Uri.parse(
            'https://cloud.leonardo.ai/api/rest/v1/generations/$generationId');
        bool isCompleted = false;
        String? imageUrl;
        String? imageId;
        for (int i = 0; i < 30; i++) {
          await Future.delayed(Duration(seconds: 1));
          final pollResponse = await http.get(pollUrl, headers: headers);
          if (pollResponse.statusCode == 200) {
            final pollData = jsonDecode(pollResponse.body);
            final status = pollData['generations_by_pk']?['status'];
            if (status == 'COMPLETE') {
              isCompleted = true;
              final generatedImage =
                  pollData['generations_by_pk']?['generated_images']?[0];
              imageUrl = generatedImage['url']?.toString();
              imageId = generatedImage['id']?.toString();
              break;
            } else if (status == 'FAILED') {
              if (mounted) {
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(
                //     content: Text("Image generation failed",
                //         style: TextStyle(fontSize: 20)),
                //     backgroundColor: Colors.redAccent,
                //     behavior: SnackBarBehavior.floating,
                //     shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(10)),
                //   ),
                // );
              }
              return null;
            }
          } else {
            if (kDebugMode) {
              print(
                  'Poll Error: ${pollResponse.statusCode} - ${pollResponse.body}');
            }
          }
        }
        if (!isCompleted || imageUrl == null) {
          if (mounted) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text("Image generation timed out or no image received",
            //         style: TextStyle(fontSize: 20)),
            //     backgroundColor: Colors.redAccent,
            //     behavior: SnackBarBehavior.floating,
            //     shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(10)),
            //   ),
            // );
          }
          return null;
        }
        if (kDebugMode) {
          print('Generated Image URL: $imageUrl');
        }
        return {'image_id': imageId, 'image_url': imageUrl};
      } else {
        if (kDebugMode) {
          print('API Error: ${response.statusCode} - ${response.body}');
        }
        String errorMsg;
        switch (response.statusCode) {
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
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(errorMsg, style: TextStyle(fontSize: 20)),
          //     backgroundColor: Colors.redAccent,
          //     behavior: SnackBarBehavior.floating,
          //     shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(10)),
          //   ),
          // );
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Request Error: $e');
      }
    }
    return null;
  }

  void onNewPhoto() {
    Navigator.of(context).pop();
    setState(() {
      _textFieldController.clear();
    });
    _showAIPromptDialog();
  }

  // void onEdit(String prevImageID) {
  //   Navigator.of(context).pop();
  //   setState(() {
  //     _textFieldController.clear();
  //   });
  //   _showAIPromptDialog(prevImageID: prevImageID);
  // }

  // Future<String> onSubmit(
  //     String imageUrl,
  //     String username,
  //     BuildContext dialogContext,
  //     GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) async {
  //   try {
  //     final response = await http
  //         .get(Uri.parse(imageUrl))
  //         .timeout(Duration(seconds: 30), onTimeout: () {
  //       throw TimeoutException("Image download timed out");
  //     });

  //     if (response.statusCode != 200) {
  //       // scaffoldMessengerKey.currentState?.showSnackBar(
  //       //   SnackBar(
  //       //     content: Text(
  //       //         "Failed to download image: HTTP ${response.statusCode}",
  //       //         style: TextStyle(fontSize: 20)),
  //       //     backgroundColor: Colors.redAccent,
  //       //     behavior: SnackBarBehavior.floating,
  //       //     shape:
  //       //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //       //   ),
  //       // );
  //       if (kDebugMode) {
  //         print("ERROR ON onSubmit FUNCTION: HTTP ${response.statusCode}");
  //       }
  //       return "error";
  //     }
  //     final bytes = response.bodyBytes;
  //     final tempDir = await getTemporaryDirectory();
  //     final filename = path.basename(imageUrl);
  //     final tempFile = File("${tempDir.path}/$filename");
  //     await tempFile.writeAsBytes(bytes);
  //     final result = await uploadImage(tempFile, username);
  //     if (result is! Map<String, dynamic> ||
  //         !result.containsKey('success') ||
  //         !result.containsKey('message')) {
  //       throw Exception("Invalid response from uploadImage");
  //     }
  //     final bool success = result['success'] as bool;
  //     final String message = result['message'] as String;
  //     await tempFile.delete();

  //     if (success) {
  //       // scaffoldMessengerKey.currentState?.showSnackBar(
  //       //   SnackBar(
  //       //     content: Row(
  //       //       mainAxisSize: MainAxisSize.min,
  //       //       children: [
  //       //         Text("Image Saved to your Account",
  //       //             style: TextStyle(fontSize: 20)),
  //       //         SizedBox(width: 8),
  //       //         Icon(Icons.check_circle_outline, color: Colors.green),
  //       //       ],
  //       //     ),
  //       //     behavior: SnackBarBehavior.floating,
  //       //     shape: RoundedRectangleBorder(
  //       //       borderRadius: BorderRadius.circular(10),
  //       //       side: BorderSide(color: Colors.green, width: 2),
  //       //     ),
  //       //   ),
  //       // );
  //       return "success";
  //     } else {
  //       await showDialog(
  //         context: dialogContext,
  //         barrierColor: const Color.fromARGB(128, 0, 0, 0),
  //         builder: (_) => AlertDialog(
  //           backgroundColor: const Color(0xFF1E1E1E),
  //           shape:
  //               RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //           title: Text(
  //             message.contains('20') ? "Upload Limit Reached" : "Upload Failed",
  //             style: const TextStyle(
  //                 color: Colors.white, fontWeight: FontWeight.bold),
  //           ),
  //           content: Text(
  //             message.contains('20')
  //                 ? "You cannot upload more than 20 images. Please delete one first."
  //                 : message,
  //             style: const TextStyle(color: Colors.white70),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.of(dialogContext).pop(),
  //               child: const Text("OK", style: TextStyle(color: Colors.green)),
  //             ),
  //           ],
  //         ),
  //       );
  //       return "too many images";
  //     }
  //   } catch (e) {
  //     // scaffoldMessengerKey.currentState?.showSnackBar(
  //     //   SnackBar(
  //     //     content: Text("Error: $e", style: TextStyle(fontSize: 20)),
  //     //     backgroundColor: Colors.redAccent,
  //     //     behavior: SnackBarBehavior.floating,
  //     //     shape:
  //     //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     //   ),
  //     // );
  //     return "error";
  //   } finally {
  //     Navigator.of(dialogContext).pop();
  //   }
  // }

  void showLoadingCircle(BuildContext context, {bool isGenerating = false}) {
    double screenWidth = MediaQuery.of(context).size.width;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoPopupSurface(
          isSurfacePainted: true,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(
                    radius: 15,
                    animating: true,
                  ),
                  if (isGenerating) ...[
                    SizedBox(height: screenWidth * 0.1),
                    Text(
                      "Generating Image...",
                      style: TextStyle(
                        color: CupertinoColors.systemGrey6,
                        fontSize: screenWidth * 0.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoButton.filled(
                      color: CupertinoColors.systemGrey,
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      onPressed: () {
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _generateAndShowImage(
    String inputPrompt,
    int numLeft,
    int width,
    int height, {
    String? prevImageID,
  }) async {
    if (!mounted) return; // widget already disposed

    final navigator = Navigator.of(context); // stable context
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (kDebugMode) {
      print("Starting _generateAndShowImage with prompt: $inputPrompt");
    }

    Map<String, dynamic>? aiImage;

    if (prevImageID == null) {
      if (kDebugMode) {
        print("Calling _getAIPhoto just based on prompt");
      }
      aiImage = await _getAIPhoto(inputPrompt, width, height);
    } else {
      if (kDebugMode) {
        print("Calling _getAIPhoto based on prompt and prevImageID");
      }
      aiImage = await _getAIPhoto(inputPrompt, width, height, prevImageID: prevImageID);
    }

    if (!mounted) return;

    String? imageUrl = aiImage?['image_url'];
    String? imageId = aiImage?['image_id'];

    if (kDebugMode) {
      print("Image generation result: URL=$imageUrl, ID=$imageId");
    }

    if (navigator.canPop()) {
      navigator.pop(); // close loading dialog
    }

    if (imageUrl != null && imageId != null) {
      int newNumLeft = numLeft - 1;

      final setNumLeft = Uri.parse(
        'https://www.digitalmediabridge.tv/screen-builder/assets/api/ai_images_track.php?type=set&email=${Uri.encodeComponent(widget.userEmail)}&count=$newNumLeft',
      );
      final response = await http.get(setNumLeft);
      final data = jsonDecode(response.body);

      if (kDebugMode) {
        print('Set Images Left Response: ${data.runtimeType}, Content: $data');
      }

      if (!mounted) return;

      try { // show the image dialog
        await showCupertinoModalPopup(
          context: context,
          builder: (BuildContext popupContext) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * 0.9,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.black,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView( 
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Text(
                        "AI Generated Image",
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.systemGrey6,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: screenHeight * 0.4, // Limit image height
                          maxWidth: screenWidth * 0.9,
                        ),
                        color: CupertinoColors.black,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CupertinoActivityIndicator(radius: 15));
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                "Failed to load image",
                                style: TextStyle(color: CupertinoColors.destructiveRed),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () {
                              onNewPhoto();
                            },
                            child: Row(
                              children: const [
                                Icon(CupertinoIcons.pencil, color: CupertinoColors.systemOrange),
                                SizedBox(width: 8),
                                Text("Try Again", style: TextStyle(color: CupertinoColors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CupertinoButton(
                            onPressed: () {
                              if (Navigator.canPop(popupContext)) {
                                Navigator.of(popupContext).pop();
                              }
                            },
                            child: const Text("Close", style: TextStyle(color: CupertinoColors.systemGrey6)),
                          ),
                          const SizedBox(width: 10),
                          CupertinoButton.filled(
                            borderRadius: BorderRadius.circular(8),
                            color: darkGreen,
                            onPressed: () async {
                              if (Navigator.canPop(popupContext)) {
                                Navigator.of(popupContext).pop();
                              }
                              showLoadingCircle(context, isGenerating: true);
                              // await onSubmit(...)
                            },
                            child: const Text("Save & Upload", style: TextStyle(color: CupertinoColors.systemGrey6)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 35),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print("Error showing image dialog: $e");
        }
      }
    } else {
      if (kDebugMode) {
        print("Failed to generate a valid image");
      }
    }
  }



Future<void> _showAIPromptDialog({String? prevImageID}) async {
  double screenHeight = MediaQuery.of(context).size.height;
  double screenWidth = MediaQuery.of(context).size.width;
  final int colorNum = int.parse(dotenv.env['LIGHT_GREY_THEME']!, radix: 16);
  final Uri numLeftURL = Uri.parse(
    'https://www.digitalmediabridge.tv/screen-builder/assets/api/ai_images_track.php?type=get&email=${Uri.encodeComponent(widget.userEmail)}',
  );

  final response = await http.get(numLeftURL);
  int numLeft;
  try {
    final list = jsonDecode(response.body);
    numLeft = int.tryParse(list.first.toString()) ?? 0;
  } catch (_) {
    numLeft = 0;
  }

  int desiredImageWidth = 1536;
  int desiredImageHeight = 864;
  List<bool> isSelected = [true, false, false];

  await showCupertinoDialog(
    context: context,
    builder: (BuildContext context) {
      return CupertinoAlertDialog(
        title: Text(
          "Describe Your Image",
          style: TextStyle(fontSize: screenWidth * 0.05),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Column(
                children: [
                  Text(
                    "$numLeft Image Generations Remaining",
                    style: TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015),
                  CupertinoTextField(
                    controller: _textFieldController,
                    placeholder: 'Enter prompt...',
                    style: const TextStyle(color: CupertinoColors.white),
                    placeholderStyle: const TextStyle(color: CupertinoColors.inactiveGray),
                    cursorColor: CupertinoColors.white,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(colorNum),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    "Image Dimensions",
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final labels = ['16 x 9', '10 x 10', '9 x 16'];
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque, // larger tap area
                        onTap: () {
                          setState(() {
                            for (int i = 0; i < 3; i++) {
                              isSelected[i] = i == index;
                            }
                            if (index == 0) {
                              desiredImageWidth = 1536;
                              desiredImageHeight = 864;
                            } else if (index == 1) {
                              desiredImageWidth = 1024;
                              desiredImageHeight = 1024;
                            } else {
                              desiredImageWidth = 864;
                              desiredImageHeight = 1536;
                            }
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isSelected[index]
                                ? CupertinoColors.systemGrey
                                : CupertinoColors.darkBackgroundGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CupertinoColors.white),
                          ),
                          child: Text(
                            labels[index],
                            style: const TextStyle(color: CupertinoColors.white),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () async {
              final prompt = _textFieldController.text.trim();
              if (prompt.isEmpty || prompt.length > 1500) {
                Fluttertoast.showToast(
                  msg: "Please enter a prompt",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  backgroundColor: CupertinoColors.systemRed,
                  textColor: CupertinoColors.white,
                );
                return;
              }
              else if (numLeft <= 0) {
                Fluttertoast.showToast(
                  msg: "No AI Image Generations Remaining",
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  backgroundColor: CupertinoColors.systemRed,
                  textColor: CupertinoColors.white,
                );
                return;
              }
              // else, generate and show the image
              if (mounted) {
                Navigator.of(context).pop();
              }
              showLoadingCircle(context, isGenerating: true);
              await _generateAndShowImage(
                prompt,
                numLeft,
                desiredImageWidth,
                desiredImageHeight,
                prevImageID: prevImageID,
              );
            },
            child: Text(
              'Generate AI Image',
              style: TextStyle(color: CupertinoColors.systemGreen, fontSize: screenWidth * 0.045),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      );
    },
  );

  _textFieldController.clear();
}


  final List<String> uploadOptions = ['Camera', 'Gallery', 'AI Image'];
  String? selectedOption;
  bool _drawerOpen = false;

  void _toggleDrawer() => setState(() => _drawerOpen = !_drawerOpen);

  @override
  Widget build(BuildContext context) {
    final double vw = MediaQuery.of(context).size.width / 100;
    final double vh = MediaQuery.of(context).size.height / 100;
    final int colorNum = int.parse(dotenv.env['LIGHT_GREY_THEME']!, radix: 16);
    final Color backgroundColor = Color(colorNum);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.network(
              backgroundURL.isNotEmpty
                  ? backgroundURL
                  : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?fit=crop&w=1536&h=864',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: CupertinoColors.systemGrey),
            ),
          ),

          CupertinoPageScaffold(
            backgroundColor: CupertinoColors.transparent,
            navigationBar: _appBarNoBackBtn(context, mainPageTitle, mainPageSubTitle, _toggleDrawer),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                CupertinoSliverRefreshControl(onRefresh: _refreshData),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: vh * 12,
                    left: vw * 6,
                    right: vw * 6,
                    bottom: vh * 10,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final player = dmbMediaPlayers[index];
                        final active = _checkPlayerStatus(index);
                        return Padding(
                          padding: EdgeInsets.only(bottom: vh * 1),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque, // larger tap area
                            onTap: () {
                              selectedPlayerName = player.name;
                              _showScreensPage(true);
                            },
                            child: Container(
                              height: vh * 10,
                              decoration: BoxDecoration(
                                gradient: active
                                    ? _gradientActiveMediaPlayer(context)
                                    : _gradientInActiveMediaPlayer(context),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.systemGrey.withAlpha(80),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    player.name,
                                    style: TextStyle(
                                      fontSize: vw * 5,
                                      fontWeight: FontWeight.bold,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                  active
                                      ? _activeScreenText(context, index, vw)
                                      : _inActiveScreenText(context, index, vw),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: dmbMediaPlayers.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // allow user to tap away
          if (_drawerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleDrawer,
                child: Container(),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            right: _drawerOpen ? 0 : -vw * 60, 
            top: 0,
            bottom: 0,
            width: vw * 60,
            child: Container(
              color: backgroundColor,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(vw * 4, vh * 4, 0, vh * 2),
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.7),
                          fontSize: vw * 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(vertical: vw * 2),
                        children: [
                          _drawerItem(
                            icon: CupertinoIcons.tv,
                            label: 'Screens',
                            vw: vw,
                            onTap: () {
                              _toggleDrawer();
                              _showScreensPage(false);
                            },
                          ),
                          SizedBox(height: vw * 3),
                          _drawerItem(
                            icon: CupertinoIcons.collections,
                            label: 'Image Playlists',
                            vw: vw,
                            onTap: () {
                              _toggleDrawer();
                              _showPlaylistBottomSheet(context, loginUsername);
                              preloadPlaylistPreviews(loginUsername);
                              setState(() {});
                            },
                          ),
                          SizedBox(height: vw * 3),
                          _uploadExpansion(vw),
                        ],
                      ),
                    ),
                    _drawerItem(
                      icon: CupertinoIcons.escape,
                      label: 'Logout',
                      vw: vw,
                      onTap: () {
                       _userLogout();
                      },
                    ),
                    SizedBox(height: vh * 2),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required double vw,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // larger tap area
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: vw * 4, vertical: vw * 1.5),
        child: Row(
          children: [
            Icon(icon, color: CupertinoColors.systemOrange, size: vw * 7),
            SizedBox(width: vw * 4),
            Text(label, style: TextStyle(color: CupertinoColors.white, fontSize: vw * 4.5)),
          ],
        ),
      ),
    );
  }

  bool _uploadExpanded = false; // Place this as a state variable in your class

Widget _uploadExpansion(double vw) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // "Upload Image" button styled like other menu buttons
      GestureDetector(
        behavior: HitTestBehavior.opaque, // larger tap area
        onTap: () {
          setState(() {
            _uploadExpanded = !_uploadExpanded;
          });
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: vw * 4, vertical: vw * 1.5),
          child: Row(
            children: [
              Icon(CupertinoIcons.upload_circle, color: CupertinoColors.systemOrange, size: vw * 7),
              SizedBox(width: vw * 4),
              Text(
                'Upload Image',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: vw * 4.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Spacer(),
              Icon(
                _uploadExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                color: CupertinoColors.white,
                size: vw * 4,
              ),
            ],
          ),
        ),
      ),

      // Dropdown options with your distinct style
      if (_uploadExpanded)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: vw * 2), // Add some space between options
            _uploadOption(vw, CupertinoIcons.camera, 'Camera', _takePhoto),
            SizedBox(height: vw * 2), // Add some space between options
            _uploadOption(vw, CupertinoIcons.photo_on_rectangle, 'Gallery', _chooseFromGallery),
            SizedBox(height: vw * 2), // Add some space between options
            _uploadOption(vw, CupertinoIcons.sparkles, 'AI Image', _showAIPromptDialog),
          ],
        ),
    ],
  );
}


  Widget _uploadOption(double vw, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // larger tap area
      onTap: () {
        _toggleDrawer();
        onTap();
        setState(() {
          _uploadExpanded = false;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: vw * 7, vertical: vw * 1.5),
        child: Row(
          children: [
            Icon(icon, color: CupertinoColors.systemOrange, size: vw * 4),
            SizedBox(width: vw * 3),
            Text(label, style: TextStyle(color: CupertinoColors.systemGrey2, fontSize: vw * 5)),
          ],
        ),
      ),
    );
  }
}

  // @override
  // Widget build(BuildContext context) {
  //   final double vw = MediaQuery.of(context).size.width / 100;
  //   final double vh = MediaQuery.of(context).size.height / 100;
  //   final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
  //   final int colorNum = int.parse(lightGreyTheme!, radix: 16);
  //   final Color backgroundColor = Color(colorNum);

  //   return PopScope(
  //     canPop: false,
  //     onPopInvokedWithResult: (didPop, result) {
  //       if (!didPop) {
  //         SystemNavigator.pop();
  //       }
  //     },
  //     child: Stack( // outer Stack for the background image
  //       children: [
  //         Positioned.fill(
  //           child: Image.network(
  //             backgroundURL.isNotEmpty
  //                 ? backgroundURL
  //                 : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?fit=crop&w=1536&h=864',
  //             fit: BoxFit.cover,
  //             errorBuilder: (context, error, stackTrace) {
  //               if (kDebugMode) {
  //                 print('Failed to load background image: $error');
  //               }
  //               return Container(color: CupertinoColors.systemGrey);
  //             },
  //           ),
  //         ),
  //         CupertinoPageScaffold(
  //           backgroundColor: CupertinoColors.transparent, 
  //           navigationBar: _appBarNoBackBtn(context, mainPageTitle, mainPageSubTitle), 
  //           child: CustomScrollView( 
  //             physics: const AlwaysScrollableScrollPhysics(),
  //             slivers: <Widget>[
  //               CupertinoSliverRefreshControl(
  //                 onRefresh: _refreshData,
  //               ),
  //               SliverPadding(
  //                 padding: EdgeInsets.only(
  //                     top: vh * 12, // padding between top of screen and first item 
  //                     left: vw * 6,
  //                     right: vw * 6,
  //                     bottom: vh * 10),
  //                 sliver: SliverList(
  //                   delegate: SliverChildBuilderDelegate(
  //                     (BuildContext context, int index) {
  //                       return Padding(
  //                         padding: const EdgeInsets.only(bottom: 10),
  //                         child: GestureDetector(
  //                           onTap: () {
  //                             // add logic here
  //                           },
  //                           child: Container(
  //                             margin: EdgeInsets.symmetric(vertical: vh * 1),
  //                             decoration: BoxDecoration(
  //                               gradient: _checkPlayerStatus(index)
  //                                   ? _gradientActiveMediaPlayer(context)
  //                                   : _gradientInActiveMediaPlayer(context),
  //                               borderRadius: BorderRadius.circular(10),
  //                               boxShadow: [
  //                                 BoxShadow(
  //                                   color: CupertinoColors.systemGrey.withAlpha(80),
  //                                   blurRadius: 8,
  //                                   offset: const Offset(0, 4),
  //                                 ),
  //                               ],
  //                             ),
  //                             height: vh * 10,
  //                             width: vw * 90,
  //                             child: Center(
  //                               child: Column(
  //                                 mainAxisAlignment: MainAxisAlignment.center,
  //                                 children: [
  //                                   Text(
  //                                     dmbMediaPlayers[index].name,
  //                                     style: TextStyle(
  //                                       fontSize: (vw * 5),
  //                                       fontWeight: FontWeight.bold,
  //                                       color: CupertinoColors.white,
  //                                     ),
  //                                   ),
  //                                   _checkPlayerStatus(index)
  //                                       ? _activeScreenText(context, index, vw)
  //                                       : _inActiveScreenText(context, index, vw),
  //                                 ],
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                       );
  //                     },
  //                     childCount: dmbMediaPlayers.length,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  // }

ObstructingPreferredSizeWidget _appBarNoBackBtn(BuildContext context, String title, String subTitle, VoidCallback onMenuPressed) {
  final double vw = MediaQuery.of(context).size.width / 100;

  return CupertinoNavigationBar(
    backgroundColor: CupertinoColors.black.withAlpha(200),
    leading: null,

    // left aligned title
    middle: Align(
      alignment: Alignment.centerLeft,
      child: Padding( 
        padding: EdgeInsets.only(
          left: vw * 4, // space between left edge and title
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
                fontSize: vw * 6, 
              ),
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ), 
      ),
    ),

    // hamburger menu
    trailing: CupertinoButton( 
      padding: EdgeInsets.zero,
      child: Icon(
        CupertinoIcons.line_horizontal_3, 
        color: CupertinoColors.white,
        size: vw * 8,
      ),
      onPressed: onMenuPressed, // show drawer
    ),
    padding: null, 
  );
}


LinearGradient _gradientActiveMediaPlayer(BuildContext context) {
  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      CupertinoColors.black,
      CupertinoColors.systemGreen,
    ],
  );
}

LinearGradient _gradientInActiveMediaPlayer(BuildContext context) {
  return const LinearGradient(
    begin: AlignmentDirectional.topCenter,
    end: AlignmentDirectional.bottomCenter,
    colors: [
      CupertinoColors.black,
      CupertinoColors.systemRed,
    ],
  );
}

Text _activeScreenText(BuildContext context, pIndex, vw) {
  return Text(
      "${dmbMediaPlayers[pIndex].status} - Screen: ${dmbMediaPlayers[pIndex].currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: CupertinoColors.white));
}

Text _inActiveScreenText(BuildContext context, pIndex, vw) {
  return Text(
      "${dmbMediaPlayers[pIndex].status} - Screen: ${dmbMediaPlayers[pIndex].currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: CupertinoColors.white));
}