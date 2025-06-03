import 'package:flutter/material.dart';
import './dmb_functions.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, this.pageTitle, this.pageSubTitle});

  final String? pageTitle;
  final String? pageSubTitle;

  @override
  _WelcomePageState createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  late String pageTitle;
  late String pageSubTitle;
  String _savedText = '';
  String? _generatedImageUrl;
  bool _isLoading = false;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _updateTitle();
  }

  void _updateTitle() {
    pageTitle = widget.pageTitle ?? "Welcome";
    pageSubTitle = widget.pageSubTitle ?? "";
  }

  void _userLogout() {
    confirmLogout(context); // Assumes confirmLogout is defined in dmb_functions.dart
  }

  void _saveText() {
    setState(() {
      _savedText = _controller.text;
    });
  }

  Future<void> _saveText2() async {
    final prompt = _controller.text.trim();

    if (!dotenv.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Environment variables not loaded')),
      );
      return;
    }

    final apiKey = dotenv.env['STABILITY_API_KEY'];

    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a prompt')),
      );
      return;
    }

    if (apiKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API key not found in .env file')),
      );
      return;
    }

    setState(() {
      _savedText = prompt;
      _isLoading = true; // Start loading
    });

    final url = Uri.parse('https://api.stability.ai/v2beta/stable-image/generate/core');

    try {
      var request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..headers['Accept'] = 'application/json'
        ..fields['prompt'] = prompt
        ..fields['output_format'] = 'png';

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final responseBodyString = responseBody.body;
        print('API Response: $responseBodyString');
        final data = jsonDecode(responseBodyString);
        final base64String = data['image']?.toString();
        print('Base64 String Length: ${base64String?.length ?? 0}');
        print('Base64 Sample: ${base64String?.substring(0, base64String != null && base64String.length > 100 ? 100 : base64String?.length ?? 0)}...');

        if (base64String == null || base64String.isEmpty) {
          print('Error: No valid image data found in response');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No valid image data received')),
          );
          return;
        }

        try {
          // Validate base64 string
          base64Decode(base64String.replaceFirst(RegExp(r'^data:image/[^;]+;base64,'), ''));
          setState(() {
            _generatedImageUrl = base64String;
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
                onEdit: () {}, // Implement edit logic if needed
                onAccept: () {}, // Implement accept logic if needed
              ),
            ),
          );
        } catch (e) {
          print('Base64 Decode Error: $e');
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid image data received: $e')),
          );
        }
      } else {
        print('API Error: ${response.statusCode} - ${responseBody.body}');
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
            errorMsg = 'Invalid request: ${responseBody.body}';
            break;
          default:
            errorMsg = 'Error: ${response.statusCode} - ${responseBody.body}';
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 50),
                Image.asset(
                  'assets/cilutions_ai_logo.png',
                  width: 180,
                  height: 180,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Enter Prompt',
                    labelStyle: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                  onSubmitted: (value) {
                    _saveText2();
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveText2,
                  child: const Text('Generate Photo using AI'),
                ),
                const SizedBox(height: 250),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExampleScreen()),
                    );
                  },
                  child: const Text('View Examples'),
                ),
              ],
            ),
          ),

          // LOADING OVERLAY
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
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
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 300,
                      height: 300,
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