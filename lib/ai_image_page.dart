import 'package:flutter/material.dart';
import './dmb_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart';


/// landing page of the Flutter App
/// contains the logic for the ai image generation page
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, this.pageTitle, this.pageSubTitle});
  final String? pageTitle;
  final String? pageSubTitle;

  @override
  _WelcomePageState createState() => _WelcomePageState();
}
/// implementation of WelcomePage
class _WelcomePageState extends State<WelcomePage> {
  late String pageTitle;
  late String pageSubTitle;
  String? _savedText; // if this breaks set it to the empty string
  String? _generatedImageUrl; // URL to the remote server where the AI image is kept
  bool _isLoading = false; // true between the time that we submitted our query for the image and when we receive feedback
  final TextEditingController _controller = TextEditingController(); // needed for accepting text input

  ///  needed to perform set up tasks
  ///  called when the State object is created
  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  /// updates the Title of the page
  void _updateTitle() {
    pageTitle = widget.pageTitle ?? "Welcome";
    pageSubTitle = widget.pageSubTitle ?? "";
  }

  /// logs out the user
  /// assumes confirmLogout is defined in dmb_functions.dart
  void _userLogout() {
    confirmLogout(context);
  }

  /// generates photo using Stability.ai API key
  /// edit this function if we change services (Leonardo, Open AI, etc)
  Future<void> _getAIPhoto() async {
    final prompt = _controller.text.trim();

    // Check if dotenv is initialized
    if (!dotenv.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Environment variables not loaded')),
      );
      return;
    }

    final apiKey = dotenv.env['LEONARDO_API_KEY'];

    // Validate prompt
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a prompt')),
      );
      return;
    }

    // Validate API key
    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API key not found in .env file')),
      );
      return;
    }

    setState(() {
      _savedText = prompt;
      _isLoading = true;
    });

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
        'width': 1536,
        'height': 864,
      });

      // Initiate image generation
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generationId = data['sdGenerationJob']?['generationId'];

        if (generationId == null) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No generation ID received')),
          );
          return;
        }

        // Poll for generation result
        final pollUrl = Uri.parse('https://cloud.leonardo.ai/api/rest/v1/generations/$generationId');
        bool isCompleted = false;
        String imageUrl = "";

        // Poll until the generation is complete (max 30 seconds)
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
            } else if (status == 'FAILED') {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Image generation failed')),
              );
              return;
            }
          } else {
            print('Poll Error: ${pollResponse.statusCode} - ${pollResponse.body}');
          }
        }

        if (!isCompleted || imageUrl == null) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image generation timed out or no image received')),
          );
          return;
        }

        // Update state with the image URL
        setState(() {
          _generatedImageUrl = imageUrl;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image generated successfully')),
        );

        // Navigate to ImageResultScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageResultScreen(
              imageUrl: _generatedImageUrl!,
              onEdit: () {
                // Implement edit logic if needed
              },
              onAccept: () async {
                // Optionally download and save the image
                try {
                  final imageResponse = await http.get(Uri.parse(imageUrl));
                  if (imageResponse.statusCode == 200) {
                    // Save to gallery (uncomment and implement if needed)
                    /*
                  final imageBytes = imageResponse.bodyBytes;
                  final fileName = "ai_generated_image_${DateTime.now().millisecondsSinceEpoch}.png";
                  final result = await ImageGallerySaver.saveImage(
                    Uint8List.fromList(imageBytes),
                    quality: 100,
                    name: fileName,
                  );
                  if (result['isSuccess'] != true) {
                    throw Exception("Failed to save image");
                  }
                  */
                  } else {
                    throw Exception('Failed to download image');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving image: $e')),
                  );
                }
              },
            ),
          ),
        );
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        setState(() {
          _isLoading = false;
        });
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      print('Request Error: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

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
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // get dimensions of the screen
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white, //change your color here
        ),
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[Colors.black87, Color.fromRGBO(10, 85, 163, 1.0)]),  //DMB BLUE
          ),
        ),
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(pageTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        color:Colors.white,
                        fontSize: 16)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(pageSubTitle,
                    style: const TextStyle(fontStyle: FontStyle.italic,
                        color:Colors.white70,
                        fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
      endDrawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black87,
          ),
          child: SafeArea(
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
                const Divider(color: Colors.black),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Material(
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: (screenHeight * 0.03)),
              Image.asset(
                'assets/cilutions_ai_logo.png',
                width: screenWidth * 0.2,
                height: screenWidth * 0.2,
                // width: 180,
                // height: 180,
              ),
              SizedBox(height: (screenHeight * 0.03)),
              Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Enter Prompt',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _getAIPhoto(),
                  ),
                ),
              ),
              SizedBox(height: (screenHeight * 0.03)),
              ElevatedButton(
                onPressed: _getAIPhoto,
                child: const Text('Generate Photo using AI'),
              ),
              SizedBox(height: (screenHeight * 0.2)),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ExampleScreen()),
                  );
                },
                child: const Text('View Examples'),
              ),
            ]
          )
        )
      )
    );
  }
}

class ExampleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Examples', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Colors.black87,
                Color.fromRGBO(10, 85, 163, 1.0),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center( // This ensures the column is centered within the scroll view
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/churches_chicken_ai.webp', width: 280, height: 280),
                SizedBox(height: 20),
                Image.asset('assets/kohls_ai.webp', width: 280, height: 280),
                SizedBox(height: 20),
                Image.asset('assets/kings_game_ai.webp', width: 280, height: 280),
                SizedBox(height: 20),
                Image.asset('assets/home_depot_ai.webp', width: 280, height: 280),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImageResultScreen extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onAccept;

  const ImageResultScreen({
    Key? key,
    required this.imageUrl,
    required this.onEdit,
    required this.onAccept,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Image Result"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children : [
            Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                     blurRadius: 8.0,
                    offset: Offset(0,2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            // buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                  ),
                  child: const Text(
                    'Edit Photo',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 12.0,
                    ),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Accept Photo',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}