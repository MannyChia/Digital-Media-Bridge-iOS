///
///
///
/// *************************************************
/// *** DMB APP TO PUBLISH USER'S SIGNAGE SCREENS
/// *************************************************
///
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import './players_page.dart';
import './screens_page.dart';
import './dmb_functions.dart';

//version 2.0
import 'package:image_picker/image_picker.dart';
import 'dart:io';

//This is the global vars used to know which "page" the user
//selected (i.e., Players or Screens)
dynamic selectedIndex = 0; //PUBLIC variable
dynamic pageTitle = "DMB Media Players"; //PUBLIC variable
dynamic pageSubTitle = "Select Player"; //PUBLIC variable
dynamic storedUsername = "none";
dynamic storedPassword = "none";

//username & password set after successful login (not the same as 'stored')
dynamic loginUsername = "none";
dynamic loginPassword = "none";

///**** STORE THE PROVIDED USERNAME & PASSWORD
const systemStorage = FlutterSecureStorage();

void main() {
  runApp(const DmbApp());

  ///<<-- *** START MAIN APP HERE!!!!
}

/// **********************************************************
/// *********************************************************


class DmbApp extends StatelessWidget {
  const DmbApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Media Bridge',
      initialRoute: '/',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blueGrey,
        inputDecorationTheme: const InputDecorationTheme(
          border:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          focusedBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          enabledBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          errorBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
          focusedErrorBorder:
          OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
        ),
        // This is the theme of the application.
        //
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Digital Media Bridge'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of the DMB application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  //Once the 'Login' page (Scaffold) is loaded, call this function to
  //determine if we've previously stored the users'
  //Username & Password
  Future<bool> _readFromStorage() async {
    try {
      storedUsername = await systemStorage.read(key: "KEY_USERNAME") ?? "none";
      storedPassword = await systemStorage.read(key: "KEY_PASSWORD") ?? "none";

      if (storedUsername != "none" && storedPassword != "none") {
        return true;
      } else {
        return false;
      }
    } catch (exc) {
      return false;
    }
  }

  // *************************************************
  // *** MAIN (DEFAULT) VIEW ***
  // *************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: () {
      //When this class is called and this Scaffold is displayed,
      //we show the login page,
      //but then also check to see if we have a stored
      //username & password
      _readFromStorage().then((bool value) {
        if (value) {
          ///*** TRUE IF WE SUCCESSFUL GOT THE STORED USERNAME & PASSWORD!
          Navigator.push(
            ///GO TO BYPASS LOGIN PAGE
            context,
            MaterialPageRoute(builder: (context) => BypassloginPage()),
          ).then(

            ///*** WHEN THE USER RETURNS TO THE LOGIN PAGE VIA 'BACK' BTN
                  (context) {});
        }
      });
      return LoginPage();

      ///ASSUME THAT WE'RE GOING TO SHOW THE USER THE LOGIN PAGE
    }());
  }
}

/// *************************************************
/// *** BYPASS LOGIN PAGE ***
/// *************************************************
/// NOTE: THIS IS SHOWN (VERY QUICKLY) ONLY AFTER
/// ITS BEEN DETERMINED THAT WE'VE STORED THE
/// DMB USERNAME & PASSWORD AND SO WE DON'T
/// NEED TO ASK THE USER AGAIN
/// *************************************************
class BypassloginPage extends StatefulWidget {
  @override
  _BypassloginPageState createState() => _BypassloginPageState();
}

class _BypassloginPageState extends State<BypassloginPage> {
  var bypassMsg = "Loading...";

  ///This 'override' function is called once when the class is loaded
  ///(is used, in this case, to get the user's DMB info)
  @override
  void initState() {
    super.initState();
    _getBypassLogin();
  }

  Future<void> _getBypassLogin() async {
    final result = await getUserData(storedUsername, storedPassword, "bypass-login");

    if (result == true) {
      loginUsername = storedUsername;
      loginPassword = storedPassword;

      //TODO please remove hard code
      await preloadPlaylistPreviews("mannychia7@gmail.com");

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      ).then((context) {
        _getBypassLogin();
      });
    } else {
      setState(() {
        bypassMsg = "Login Failed.\nPlease logout and then login again with the correct username & password";
      });
    }
  }


  // void _getBypassLogin() {
  //   ///*** GO TO THE DMB SERVER TO GET A LIST OF MEDIA PLAYERS AND SCREENS
  //   /// WITH THE STORED USERNAME & PASSWORD
  //   getUserData(storedUsername, storedPassword, "bypass-login").then((result) {
  //     if (result == true) {
  //       //if good, then load the 'Media Players' view
  //
  //       //set the global logged-in username & password to the ones stored in storage
  //       loginUsername = storedUsername;
  //       loginPassword = storedPassword;
  //
  //       // preloadPlaylistPreviews(loginUsername);
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(builder: (context) => const HomePage()),
  //       ).then((context) {
  //         _getBypassLogin(); //<<-- GET A NEW LIST OF DMB MEDIA PLAYERS (e.g., REFRESH)
  //       });
  //     } else {
  //       //else, error getting the data from the DMB server with the username & password from 'storage'
  //       setState(() {
  //         //tell the user
  //         bypassMsg =
  //         "Login Failed.\nPlease logout and then login again with the correct username & password";
  //       });
  //     }
  //   });
  // }

  //In each view, provide a button to let the user logout
  void _userLogout() {
    confirmLogout(
        context); //*** CONFIRM USER LOGOUT (function is in: dmb_functions.dart)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(bypassMsg,
            style: const TextStyle(
                fontWeight: FontWeight.normal,
                color: Colors.white,
                fontSize: 14)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _userLogout,
        tooltip: 'Logout',
        child: const Icon(Icons.logout),
      ),
    );
  }
}

/// *************************************************
/// *** LOGIN PAGE ***
/// *************************************************
class LoginPage extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  //After a successful login, save the info to local storage
  _saveUsername(String login, String password) async {
    await systemStorage.write(key: "KEY_USERNAME", value: login);
    await systemStorage.write(key: "KEY_PASSWORD", value: password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        ///*** Note: we use a special title text that has an color outline
        title: Stack(
          children: <Widget>[
            // border (outline) text
            Text(
              'DIGITAL MEDIA BRIDGE',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 6
                  ..color = Colors.blueGrey,
              ),
            ),
            // main text (fill)
            const Text(
              'DIGITAL MEDIA BRIDGE',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueGrey,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Colors.blueGrey,
                  Color.fromRGBO(10, 85, 163, 0.2)
                ]),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person, color: Colors.white30),
                      border: OutlineInputBorder(),
                      labelText: "Username",
                      labelStyle: TextStyle(color: Colors.white)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.password, color: Colors.white30),
                      border: OutlineInputBorder(),
                      labelText: "Password",
                      labelStyle: TextStyle(color: Colors.white)),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 16.0),
                child: Center(
                  child: ElevatedButton(
                    ///*** LOGIN BUTTON
                    style: ElevatedButton.styleFrom(
                      elevation: 15,
                      shadowColor: Colors.white10,
                      padding: const EdgeInsets.all(20),
                      //content padding inside button
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white30, width: 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      backgroundColor: Color.fromRGBO(10, 85, 163, 0.2),
                      textStyle: const TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final result = await getUserData(
                          emailController.text,
                          passwordController.text,
                          "user-login",
                        );

                        if (result == "invalid_login") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Invalid Login")),
                          );
                        } else if (result == "no_screens") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No Screens To Play")),
                          );
                        } else if (result == "no_players") {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("No Players To Update")),
                          );
                        } else if (result == false) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Cannot Connect To DMB Server")),
                          );
                        } else {
                          loginUsername = emailController.text;
                          loginPassword = passwordController.text;

                          ///TODO please remove hard code
                          await preloadPlaylistPreviews("mannychia7@gmail.com");

                          try {
                            _saveUsername(loginUsername, loginPassword);
                          } catch (exc) {}

                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Username & Password are required')),
                        );
                      }
                    },

                    child: const Text('Log In'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// *************************************************
/// *** AFTER SUCCESSFUL LOGIN ***
/// *************************************************
///
class HomePage extends StatefulWidget {
  //const HomePage({super.key, required this.email});
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  void _updateTitle(title, subTitle, selIndex) {
    setState(() {
      pageTitle = title;
      pageSubTitle = subTitle;
      selectedIndex = selIndex;
    });
  }

  ///*** FUNCTION TO SHOW LIST OF SCREENS AFTER 'SCREENS' SIDE
  ///NAVIGATION IS CLICKED
  void _showScreensPage() {
    ///show the user (in a small pop-up) a message informing
    ///them of the name of the Media Player that they previously selected
    if (selectedPlayerName != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$selectedPlayerName Selected")),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ScreensPage(
                  pageTitle: "Screens (${dmbScreens.length})",
                  pageSubTitle: selectedPlayerName != null
                      ? _PlayerSelectedText()
                      : _PlayerNotSelectedText())),
    ).then((context) {
      _updateTitle(
          "Media Players (${dmbMediaPlayers.length})", "Select Player", 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme
            .of(context)
            .colorScheme
            .primaryContainer,
        child: Builder(
          builder: (_) {
            return PlayersPage(
              pageTitle: "Media Players",
              pageSubTitle: "Select Player",
            );
          },
        ),
      ),
    );
  }
}

//We use one of the following two options when showing the user a
//list of screens.  Depends on if they have previously selected a
//DMB Media Player
String _PlayerSelectedText() {
  return "Select Screen to Publish";
}

String _PlayerNotSelectedText() {
  return "{Read Only}";
}