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
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import './main.dart';
import './screens_page.dart';
import './dmb_functions.dart';
import './ai_image_page.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

///
class PlayersPage extends StatefulWidget {
  //const PlayersPage({super.key, required this.pageTitle, required this.pageSubTitle});
  const PlayersPage({super.key, this.pageTitle, this.pageSubTitle});

  final String? pageTitle;
  final String? pageSubTitle;

  @override
  _PlayersPageState createState() => _PlayersPageState();
}

// main class that holds everything until line 611
class _PlayersPageState extends State<PlayersPage> {
  late String pageTitle;
  late String pageSubTitle;
  File? _image;
  final ImagePicker _picker = ImagePicker();
  TextEditingController _textFieldController = TextEditingController();
  String? _generatedImageUrl;
  bool _isGenerating = false; // Track image generation state
  List<String> prompts = []; // stores all the prompts given by the user
  String backgroundURL = "https://lp-cms-production.imgix.net/2023-02/3cb45f6e59190e8213ce0a35394d0e11-nice.jpg";

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

  Future<void> _showUploadSheet(File imageFile) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Upload Image",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(imageFile),
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
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    bool success = await uploadImage(imageFile, "billstantonthefourth@gmail.com");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? "Image uploaded successfully" : "Image upload failed",
                        ),
                      ),
                    );
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


  /// generates photo using Stability.ai API key
  /// edit this function if we change services (Leonardo, Open AI, etc)
  Future<String?> _getAIPhoto(String prompt, int width, int height) async {
    if (!dotenv.isInitialized) {
      if (mounted) { // checks is a state object is still part of the widget tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Environment variables not loaded')),
        );
      }
      return null;
    }

    final apiKey = dotenv.env['LEONARDO_API_KEY'];

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

    try {
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode({
        'prompt': prompt,
        'modelId': 'de7d3faf-762f-48e0-b3b7-9d0ac3a3fcf3', // Phoenix 1.0 model
        'num_images': 1,
        'width': width,
        'height': height,
      });

      final response = await http.post(url, headers: headers, body: body);

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
        String? imageUrl;

        for (int i = 0; i < 30; i++) {
          await Future.delayed(Duration(seconds: 1));
          final pollResponse = await http.get(pollUrl, headers: headers);

          if (pollResponse.statusCode == 200) {
            final pollData = jsonDecode(pollResponse.body);
            final status = pollData['generations_by_pk']?['status'];

            if (status == 'COMPLETE') {
              isCompleted = true;
              imageUrl = pollData['generations_by_pk']?['generated_images']?[0]?['url'];
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

        print('Generated Image URL: $imageUrl'); // Debug URL
        return imageUrl;
      }
      else {
        print('API Error: ${response.statusCode} - ${response.body}');
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

  void onEdit() {
    Navigator.of(context).pop(); // Close the image dialog
    setState(() {
      _generatedImageUrl = null; // Clear the previous image
      _textFieldController.clear(); // Clear the text field for new input
    });
    _showAIPromptDialog();
  }

  Future<void> onSubmit(String imageUrl, String username) async {
    // convert imageUrl into File, upload to DMB server
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download image")),
        );
        print("ERROR ON ONSUBMIT FUNCTION!");
        return;
      }

      // extract the bytes from the url's image
      final bytes = response.bodyBytes;
      // dir to store the tempfile -> should be located in cache
      final tempDir = await getTemporaryDirectory();
      // extract the names of the file
      final filename = path.basename(imageUrl);
      final tempFile = File("${tempDir.path}/$filename");

      // use writeAsBytes
      // this takes the bytes from the url and copies it directly into the tempfile
      await tempFile.writeAsBytes(bytes);

      // call uploadImage with tempFile and userName
      bool success = await uploadImage(tempFile, "billstantonthefourth@gmail.com");

      // Only delete temp file if upload succeeded AND deleteAfter is true
      // remember to delete from cache
      if (success) {
        try {
          await tempFile.delete();
        }
        catch (_) {
          // ignore deletion errors first
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Image uploaded successfully"
                : "Image upload failed",
          ),
        ),
      );
    }
    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
    Navigator.of(context).pop(); // Close the image dialog
  }

  // Helper function to handle image generation and display
  Future<void> _generateAndShowImage(String inputPrompt, BuildContext dialogContext) async {
    final imageUrl = await _getAIPhoto(inputPrompt, 1536, 864);
    if (!dialogContext.mounted) return; // Prevent UI updates if unmounted
    setState(() {
      _generatedImageUrl = imageUrl;
    });
    if (imageUrl != null) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Image generated successfully')),
        );
        showDialog(
          context: dialogContext,
          builder: (BuildContext context) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent, // Set dialog background to transparent
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                  SizedBox(height:20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          onEdit();
                        },
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Edit Photo'),
                          ]
                        )
                      ),
                      ElevatedButton(
                          onPressed: () {
                            onSubmit(imageUrl, "billstantonthefourth@gmail.com");
                          },
                          child: Row(
                              children: [
                                Icon(Icons.check, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Submit Photo'),
                              ]
                          )
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }
    } else {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(content: Text('Failed to generate a valid image URL')),
        );
      }
    }
  }

  Future<void> _showAIPromptDialog() async {
    final dialogContext = context; // Store state context
    await showDialog(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text("Enter your prompt", style: TextStyle(color: Colors.white))
          ),
          backgroundColor: Colors.blueGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: TextField(
            controller: _textFieldController,
            decoration: InputDecoration(
              hintText: "Example: Show me happy cashier",
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black))
            ),
            onSubmitted: (value) async {
              // Handle Enter key press
              final prompt = value.trim();
              if (prompt.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a prompt')),
                );
                return;
              }
              Navigator.of(context).pop(); // Close prompt dialog
              if (mounted) {
                setState(() {
                  _isGenerating = true; // Show loading circle
                });
              }
              // add prompt to prompts list
              prompts.add(prompt);
              // concatenate all strings in prompts into one
              String totalPrompt = "";
              for (String my_prompt in prompts) {
                totalPrompt = "$totalPrompt, $my_prompt";
              }
              await _generateAndShowImage(totalPrompt, dialogContext);
              if (mounted) {
                setState(() {
                  _isGenerating = false; // Hide loading circle
                });
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Handle button click
                final prompt = _textFieldController.text.trim();
                if (prompt.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a prompt')),
                  );
                  return;
                }
                Navigator.of(context).pop(); // Close prompt dialog
                if (mounted) {
                  setState(() {
                    _isGenerating = true; // Show loading circle
                  });
                }
                // add prompt to prompts list
                prompts.add(prompt);
                // concatenate all strings in prompts into one
                String totalPrompt = "";
                for (String my_prompt in prompts) {
                  totalPrompt = "$totalPrompt, $my_prompt";
                }

                await _generateAndShowImage(totalPrompt, dialogContext);
                if (mounted) {
                  setState(() {
                    _isGenerating = false; // Hide loading circle
                  });
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Create Image', style: TextStyle(color: Colors.white))
                ]
              )
            ),
          ],
        );
      },
    );
    // when user taps away from dialog, clear input string
    prompts.clear();
    _textFieldController.clear(); // Clear the text field for new input

  }


  final List<String> uploadOptions = ['Camera', 'Gallery', 'Create Image'];
  String? selectedOption;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white, // Fallback color if image fails to load
      endDrawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black87,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
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
                              leading: const Icon(Icons.tv_outlined, color: Colors.orange),
                              title: const Text("My Screens", style: TextStyle(color: Colors.white, fontSize: 20)),
                            ),
                          ),
                        ),
                      ),
                      // UPLOAD IMAGE DROP DOWN BUTTON
                      const Divider(color: Colors.black),
                      DropdownButton2<String>(
                        isExpanded: true,
                        customButton: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 60,
                          width: 350,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              const Icon(Icons.upload, color: Colors.orange),
                              const SizedBox(width: 15),
                              const Text(
                                "Upload Image",
                                style: TextStyle(fontSize: 20, color: Colors.white),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_drop_down, color: Colors.white),
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
                                Icon(iconData, color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  value,
                                  style: const TextStyle(color: Colors.white),
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
                        buttonStyleData: const ButtonStyleData(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          height: 60,
                          width: 200,
                        ),
                        dropdownStyleData: const DropdownStyleData(
                          maxHeight: 200,
                          decoration: BoxDecoration(
                            color: Color(0xFF424242),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 40,
                        ),
                      ),
                      const Divider(color: Colors.black),
                    ],
                  ),
                ),
                // Bottom Section (Logout)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Column(
                    children: [
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
                            leading: Icon(Icons.logout, color: Colors.orange),
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
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: ListView.separated(
            itemCount: dmbMediaPlayers.length,
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int index) {
              return Align(
                alignment: Alignment.center,
                child: Container(
                  color: Colors.transparent,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(),
                      child: InkWell(
                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Ink(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.height * 0.1,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              width: 0,
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
                                      style: const TextStyle(
                                        fontSize: 12,
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
                                        ? _activeScreenText(context, index)
                                        : _inActiveScreenText(context, index),
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
  return AppBar(
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
            color: Colors.white,
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
