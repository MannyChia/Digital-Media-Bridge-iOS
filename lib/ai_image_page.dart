import 'package:flutter/material.dart';
import './dmb_functions.dart';

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
            gradient: LinearGradient(
              begin: Alignment.topRight,
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
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                  labelText: 'Enter Prompt',
                  labelStyle: TextStyle(
                    color: Colors.white,
                  )
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveText,
              child: Text('Generate Photo using AI'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ExampleScreen()),
                );
              },
              child: Text('View Examples'),
            )
          ]
        ),
      ),
    );
  }
}

class ExampleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Examples')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding (
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Image.asset('assets/churches_chicken_ai.webp'),
                  SizedBox(height:20),
                  Image.asset('assets/kohls_ai.webp'),
                  SizedBox(height:20),
                  Image.asset('assets/kings_game_ai.webp'),
                  SizedBox(height:20),
                  Image.asset('assets/home_depot_ai.webp')
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}