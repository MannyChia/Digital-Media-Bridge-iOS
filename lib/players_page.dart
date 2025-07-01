import 'dart:async';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load playlist images",
              style: TextStyle(fontSize: 20)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
      });
    } catch (e) {
      if (kDebugMode) {
        print("Failed to refresh playlist previews: $e");
      }
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _pageIndex == 0
                  ? _buildPlaylistView(scrollController)
                  : _buildImageView(scrollController),
            ),
          );
        });
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
          Divider(color: Colors.white70, thickness: 1, height: 1),
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
              color: Colors.grey[600],
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
                  color: Colors.white70,
                  fontSize: vw * 7,
                ),
              ),
              SizedBox(width: 6),
              Icon(Icons.playlist_add, color: Colors.white70, size: vw * 7),
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
                              color: Colors.white70, fontSize: vw * 5.5),
                        ),
                        Text(
                          entries[i].key,
                          style: TextStyle(
                            color: Colors.white,
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
                    return InkWell(
                      onTap: () =>
                          _openPlaylist(preview.screenName, preview.name),
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
                                            const Center(
                                                child: Icon(Icons.broken_image,
                                                    color: Colors.white70)),
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: Icon(Icons.image_not_supported,
                                              color: Colors.white70, size: 40),
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
                                    color: Colors.white,
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
                              color: isSelected ? Colors.green : Colors.black45,
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
          bottom: 60,
          left: 16,
          right: 16,
          child: ElevatedButton(
            onPressed: _hasPlaylistChanged() ? _onSavePressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _hasPlaylistChanged() ? Colors.green : Colors.grey[700],
              foregroundColor:
                  _hasPlaylistChanged() ? Colors.black : Colors.white54,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Save Playlist',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(height: 40),
      ],
    );
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            Text("Playlist Updated", style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Icon(Icons.check_circle_outline, color: Colors.green),
          ]),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Colors.green,
              width: 2,
            ),
          ),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Failed to update playlist", style: TextStyle(fontSize: 20)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class PlayersPage extends StatefulWidget {
  final String userEmail;
  const PlayersPage({super.key, this.mainPageTitle, this.mainPageSubTitle, required this.userEmail});

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
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();



  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle() {
    mainPageTitle = "${widget.mainPageTitle} (${dmbMediaPlayers.length})";
    mainPageSubTitle = widget.mainPageSubTitle ?? "";
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int selectedIndex = 0;

  void _showScreensPage(bool onPlayer) {
    if (onPlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScreensPage(
            screensPageTitle: "Player: $selectedPlayerName",
            screensPageSubTitle: "Select Screen to Publish",
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScreensPage(
            screensPageTitle: "Available Screens",
            screensPageSubTitle: "Return to Menu to Select Player",
          ),
        ),
      );
    }
  }

  bool _checkPlayerStatus(int index) {
    return dmbMediaPlayers[index].status == "Active";
  }

  void _userLogout() {
    confirmLogout(context);
  }

  Future<void> _refreshData() async {
    try {
      getUserData("$loginUsername", "$loginPassword", "players-refresh")
          .then((result) {
        if (result.runtimeType != String) {
          setState(() {
            dmbMediaPlayers = result;
            mainPageTitle = "Media Players (${dmbMediaPlayers.length})";
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
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
              "Upload Image to Account",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
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
                  child: const Text("Close",
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final result = await uploadImage(imageFile, loginUsername);
                    final bool success = result['success'] as bool;
                    final String message = result['message'] as String;
                    if (!success) {
                      showDialog(
                        context: context,
                        barrierColor: const Color.fromARGB(128, 0, 0, 0),
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            message.contains('20')
                                ? "Upload Limit Reached"
                                : "Upload Failed",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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
                              child: const Text("OK",
                                  style: TextStyle(color: Colors.green)),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(message, style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Icon(Icons.check_circle_outline, color: Colors.green),
                        ]),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  child: const Text("Upload",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.03)
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

  Future<void> _showPlaylistBottomSheet(
      BuildContext context, String userEmail) async {
    await preloadPlaylistPreviews(userEmail);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => PlaylistSheet(userEmail: userEmail),
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

  Future<Map<String, dynamic>?> _getAIPhoto(
      String prompt, int width, int height,
      {String? prevImageID}) async {
    final stableDiffusion = dotenv.env['STABLE_DIFFUSION_KEY']!;
    final lucidRealism   = dotenv.env['LUCID_REALISM_KEY']!;
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Image generation failed",
                        style: TextStyle(fontSize: 20)),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Image generation timed out or no image received",
                    style: TextStyle(fontSize: 20)),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg, style: TextStyle(fontSize: 20)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
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

  void onEdit(String prevImageID) {
    Navigator.of(context).pop();
    setState(() {
      _textFieldController.clear();
    });
    _showAIPromptDialog(prevImageID: prevImageID);
  }

  Future<String> onSubmit(String imageUrl, String username, BuildContext dialogContext, GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey) async {
    try {
      // Add timeout to HTTP request
      final response = await http.get(Uri.parse(imageUrl)).timeout(Duration(seconds: 30), onTimeout: () {
        throw TimeoutException("Image download timed out");
      });

      if (response.statusCode != 200) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("Failed to download image: HTTP ${response.statusCode}", style: TextStyle(fontSize: 20)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        if (kDebugMode) {
        print("ERROR ON onSubmit FUNCTION: HTTP ${response.statusCode}");
        }
        return "error";
      }
      final bytes = response.bodyBytes;
      final tempDir = await getTemporaryDirectory();
      final filename = path.basename(imageUrl);
      final tempFile = File("${tempDir.path}/$filename");
      await tempFile.writeAsBytes(bytes);
      final result = await uploadImage(tempFile, username);
      if (result is! Map<String, dynamic> || !result.containsKey('success') || !result.containsKey('message')) {
        throw Exception("Invalid response from uploadImage");
      }
      final bool success = result['success'] as bool;
      final String message = result['message'] as String;

      // Always delete the temp file
      await tempFile.delete();

      if (success) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Image Saved to your Account", style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Icon(Icons.check_circle_outline, color: Colors.green),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.green, width: 2),
            ),
          ),
        );
        return "success";
      } else {
        // Show error dialog directly
        await showDialog(
          context: dialogContext,
          barrierColor: const Color.fromARGB(128, 0, 0, 0),
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("OK", style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        );
        return "too many images";
      }
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: TextStyle(fontSize: 20)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return "error";
    } finally {
      Navigator.of(dialogContext).pop();
    }
  }

  void showLoadingCircle(BuildContext context, {bool isGenerating = false}) {
    double screenWidth = MediaQuery.of(context).size.width;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                  if (isGenerating) ...[
                    SizedBox(height: screenWidth * 0.1),
                    Text(
                      "Generating Image...",
                      style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.05),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Color(colorNum),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: Colors.white, fontSize: screenWidth * 0.04),
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

  Future<void> _generateAndShowImage(String inputPrompt, BuildContext dialogContext, int numLeft, int width, int height, {String? prevImageID}) async {
    double screenWidth = MediaQuery.of(dialogContext).size.width;
    double screenHeight = MediaQuery.of(dialogContext).size.height;

    if (kDebugMode) {
      print("Starting _generateAndShowImage with prompt: $inputPrompt");
    }

    Map<String, dynamic>? aiImage; // Map to store the imageUrl and imageId

    if (prevImageID == null) {
      print("Calling _getAIPhoto just based on prompt");
      aiImage = await _getAIPhoto(inputPrompt, width, height);
    } else {
      print("Calling _getAIPhoto based on prompt and prevImageID");
      aiImage = await _getAIPhoto(inputPrompt, width, height, prevImageID: prevImageID);
    }

    String? imageUrl = aiImage?['image_url'];
    String? imageId = aiImage?['image_id'];

    print("Image generation result: URL=$imageUrl, ID=$imageId");
    Navigator.of(dialogContext).pop(); // Dismiss the loading dialog

    if (imageUrl != null && imageId != null) {
      // decrement the number of images the user can generate
      int newNumLeft = numLeft -1;

      final setNumLeft = Uri.parse('https://www.digitalmediabridge.tv/screen-builder/assets/api/ai_images_track.php?type=set&email=${Uri.encodeComponent(widget.userEmail)}&count=$newNumLeft');
      final response = await http.get(setNumLeft);
      final data = jsonDecode(response.body);
      print('Set Images Left Response: ${data.runtimeType}, Content: $data');

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Image generated successfully", style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Icon(Icons.check_circle_outline, color: Colors.green),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.green, width: 2),
          ),
        ),
      );

      try {
        // Show image in slide-up bottom sheet
        await showModalBottomSheet(
          context: dialogContext,
          backgroundColor: Colors.grey[900],
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          isScrollControlled: true,
          builder: (BuildContext context) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handlebar for the bottom sheet
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Text(
                      "AI Generated Image",
                      style: TextStyle(
                        fontSize: screenWidth * 0.07,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: screenWidth * 0.9,
                        height: screenHeight * 0.6,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
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
                    SizedBox(height: screenHeight * 0.02),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            onNewPhoto();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withOpacity(0.7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.edit, color: Colors.orange),
                              SizedBox(width: 8),
                              Text("Try Again", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop(); // Close the image preview dialog
                            showLoadingCircle(dialogContext); // Show loading dialog
                            await onSubmit(imageUrl, loginUsername, dialogContext, _scaffoldMessengerKey); // Call updated onSubmit
                          },
                          child: const Text("Save & Upload", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 35),
                  ],
                ),
              ),
            );
          },
        );
        print("Image dialog shown successfully");
      }
      catch (e) {
        print("Error showing image dialog: $e");
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("Error displaying image: $e", style: TextStyle(fontSize: 20)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
    else {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Failed to generate a valid image", style: TextStyle(fontSize: 20)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showAIPromptDialog({String? prevImageID}) async {
    double screenHeight = MediaQuery.of(context).size.height;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16); // parse the number in base 16

    // get the number of AI Images this user has left
    // Construct the URL
    final numLeftURL = Uri.parse(
      'https://www.digitalmediabridge.tv/screen-builder/assets/api/ai_images_track.php?type=get&email=${Uri.encodeComponent(widget.userEmail)}',
    );

    final response = await http.get(numLeftURL);
    int numLeft;
    try {
      final List<dynamic> list = jsonDecode(response.body);

      if (list.isEmpty || list.first == null || list.first.toString().isEmpty) {
        numLeft = 20;
      } else {
        numLeft = int.tryParse(list.first.toString()) ?? 20;
      }
    } catch (e) {
      debugPrint( '$e');
      numLeft = 20;
    }
    if (kDebugMode) {
      print("Num Left: $numLeft");
    }

    // Set default dimensions (16x9)
    int desiredImageWidth = 1536;
    int desiredImageHeight = 864;
    List<bool> isSelected = [true, false, false];
    final dialogContext = context;
    await showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Center(
                child: Text(
                  "Describe Your Image",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.06,
                  ),
                ),
              ),
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: EdgeInsets.all(16),
              content: FractionallySizedBox(
                widthFactor: 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$numLeft Image Generations Remaining", style: TextStyle(color: Colors.white70, fontSize: screenWidth * 0.04)),
                    SizedBox(height: screenHeight * 0.02),
                    TextFormField(
                      controller: _textFieldController,
                      style: TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(colorNum),
                        hintText: 'Enter text ... ',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      onFieldSubmitted: (value) async {
                        final prompt = value.trim();
                        if (prompt.isEmpty) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Please enter a prompt",
                                  style: TextStyle(fontSize: 20)),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }
                        if (prompt.length > 1500) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Prompt can be no more than 1500 characters", style: TextStyle(fontSize: 20)),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(); // Close prompt dialog
                        showLoadingCircle(dialogContext, isGenerating: true);
                        await _generateAndShowImage(
                          prompt,
                          dialogContext,
                          numLeft,
                          desiredImageWidth,
                          desiredImageHeight,
                          prevImageID: prevImageID,
                        );
                      },
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    Text(
                      "Image Dimensions",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(1.0),
                      ),
                      child: Wrap(
                        spacing: screenWidth * 0.01,
                        runSpacing: 8.0,
                        children: [
                          ToggleButtons(
                            isSelected: isSelected,
                            onPressed: (index) {
                              setState(() {
                                for (int i = 0; i < isSelected.length; i++) {
                                  isSelected[i] = i == index;
                                }
                                if (index == 0) {
                                  desiredImageWidth = 1536;
                                  desiredImageHeight = 864;
                                } else if (index == 1) {
                                  desiredImageWidth = 1024;
                                  desiredImageHeight = 1024;
                                } else if (index == 2) {
                                  desiredImageWidth = 864;
                                  desiredImageHeight = 1536;
                                }
                              });
                            },
                            selectedColor: Colors.white,
                            fillColor: Color(colorNum),
                            color: Colors.white,
                            borderColor: Colors.grey,
                            selectedBorderColor: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            constraints: const BoxConstraints(
                              minWidth: 60,
                              minHeight: 36,
                              maxWidth: 60,
                              maxHeight: 36,
                            ),
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Text("16 x 9"),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Text("10 x 10"),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 0),
                                child: Text("9 x 16"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final prompt = _textFieldController.text.trim();
                    if (prompt.isEmpty) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Please enter a prompt",
                              style: TextStyle(fontSize: 20)),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }
                    if (prompt.length > 1500) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Prompt can be no longer than 1500 characters", style: TextStyle(fontSize: 20)),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }
                    if (numLeft <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("AI Image Generation Limit Reached", style: TextStyle(fontSize: 20)),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(); // Close prompt dialog
                    showLoadingCircle(dialogContext, isGenerating: true);
                    await _generateAndShowImage(
                      prompt,
                      dialogContext,
                      numLeft,
                      desiredImageWidth,
                      desiredImageHeight,
                      prevImageID: prevImageID,
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenHeight * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: _isGenerating ? 8 : 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Generate AI Image ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth * 0.05,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    _textFieldController.clear();
  }

  final List<String> uploadOptions = ['Camera', 'Gallery', 'AI Image'];
  String? selectedOption;

  @override
  Widget build(BuildContext context) {
    final double vw = MediaQuery.of(context).size.width / 100;
    final double vh = MediaQuery.of(context).size.height / 100;
    final lightGreyTheme = dotenv.env['LIGHT_GREY_THEME'];
    final int colorNum = int.parse(lightGreyTheme!, radix: 16);
    Color backgroundColor = Color(colorNum);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(backgroundURL),
              fit: BoxFit.cover,
            ),
          ),
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            endDrawer: SizedBox(
              width: vw * 60,
              child: Drawer(
                child: Container(
                  decoration: BoxDecoration(color: backgroundColor),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding:
                              EdgeInsets.fromLTRB(vw * 4, vh * 4, 0, vh * 2),
                          child: Text(
                            "Menu",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: vw * 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.symmetric(vertical: vw * 2),
                            children: [
                              ListTile(
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: vw * 4),
                                leading: Icon(Icons.tv_outlined,
                                    color: Colors.orange, size: vw * 7),
                                title: Text("Screens",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: vw * 4.5)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showScreensPage(false);
                                },
                                dense: true,
                                shape: const ContinuousRectangleBorder(),
                              ),
                              SizedBox(height: vw * 3),
                              ListTile(
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: vw * 4),
                                leading: Icon(Icons.collections,
                                    color: Colors.orange, size: vw * 7),
                                title: Text("Image Playlists",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: vw * 4.5)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showPlaylistBottomSheet(
                                      context, loginUsername);
                                  preloadPlaylistPreviews(loginUsername);
                                  setState(() {});
                                },
                                dense: true,
                                shape: const ContinuousRectangleBorder(),
                              ),
                              SizedBox(height: vw * 3),
                              Theme(
                                data: Theme.of(context)
                                    .copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  leading: Icon(Icons.upload,
                                      color: Colors.orange, size: vw * 7),
                                  title: Text("Upload Image",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: vw * 4.5)),
                                  iconColor: Colors.white,
                                  textColor: Colors.white,
                                  tilePadding:
                                      EdgeInsets.symmetric(horizontal: vw * 4),
                                  childrenPadding: EdgeInsets.zero,
                                  children: uploadOptions.map((opt) {
                                    IconData icon;
                                    void Function() action;
                                    if (opt == 'Camera') {
                                      icon = Icons.camera_alt;
                                      action = _takePhoto;
                                    } else if (opt == 'Gallery') {
                                      icon = Icons.photo_library;
                                      action = _chooseFromGallery;
                                    } else {
                                      icon = Icons.auto_awesome;
                                      action = () => _showAIPromptDialog();
                                    }
                                    return ListTile(
                                      leading: Icon(icon, color: Colors.orange, size: vw * 4),
                                      title: Text(opt, style: TextStyle(color: Colors.white70, fontSize: vw * 5)),
                                      contentPadding: EdgeInsets.symmetric(horizontal: vw * 7),
                                      onTap: () {
                                        Navigator.pop(context);
                                        action();
                                      },
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide.none,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.orange, size: vw * 5),
                          title: Text("Logout", style: TextStyle(color: Colors.white, fontSize: vw * 5)),
                          onTap: () {
                            Navigator.pop(context);
                            _userLogout();
                          },
                          dense: true,
                          shape: const ContinuousRectangleBorder(),
                        ),
                        SizedBox(height: vh * 2), // paddding between 'logout' and bottom of screen
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
                    if (kDebugMode) {
                      print('Failed to load background image: $exception');
                    }
                  },
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView.separated(
                  padding: EdgeInsets.only(top: vh * 2, left: vw * 6, right: vw * 6, bottom: vh * 1.5),
                  itemCount: dmbMediaPlayers.length,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    return Align(
                      alignment: Alignment.center,
                      child: Container(
                        color: Colors.transparent,
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3), // White shadow with opacity
                                  spreadRadius: 6, // How far the shadow spreads
                                  blurRadius: 6, // How blurry the shadow is
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                selectedPlayerName = dmbMediaPlayers[index].name;
                                _showScreensPage(true);
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _checkPlayerStatus(index)
                                      ? _gradientActiveMediaPlayer(context)
                                      : _gradientInActiveMediaPlayer(context),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                width: vw * 90,
                                height: vh * 10,
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
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(color: Colors.transparent), // dividers between players
                ),
              ),
            ),
          )
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
      backgroundColor: Colors.black.withOpacity(0.8), // app bar background
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            mainPageTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: vw * 6, // Increase font size to 6% of smaller dimension
            ),
          ),
          Text(
            mainPageSubTitle,
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
      Colors.black,
      Colors.green,
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
      Colors.black,
      Colors.red,
    ],
  );
}

///*** As the list is being displayed, show a (slightly) different
/// text (label) to the user for players that are active vs. inactive
Text _activeScreenText(BuildContext context, pIndex, vw) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: Colors.white70));
}

Text _inActiveScreenText(BuildContext context, pIndex, vw) {
  return Text("${dmbMediaPlayers[pIndex]
      .status} - Screen: ${dmbMediaPlayers[pIndex]
      .currentScreen}",
      style: TextStyle(
          fontSize: vw * 4,
          fontStyle: FontStyle.italic,
          color: Colors.white70)
  );
}