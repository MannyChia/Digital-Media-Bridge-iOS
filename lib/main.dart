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
import 'package:flutter_dotenv/flutter_dotenv.dart';

import './players_page.dart';
import './screens_page.dart';
import './dmb_functions.dart';
import 'package:flutter/widgets.dart'; // or material.dart depending on your structure

//This is the global vars used to know which "page" the user
//selected (i.e., Players or Screens)
dynamic selectedIndex = 0; //PUBLIC variable
dynamic mainPageTitle = "DMB Media Players"; //PUBLIC variable
dynamic mainPageSubTitle = "Select Player"; //PUBLIC variable
dynamic storedUsername = "none";
dynamic storedPassword = "none";

//username & password set after successful login (not the same as 'stored')
dynamic loginUsername = "none";
dynamic loginPassword = "none";

///**** STORE THE PROVIDED USERNAME & PASSWORD
const systemStorage = FlutterSecureStorage();


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    print("Loaded key: ${dotenv.env['LEONARDO_API_KEY']}");

  }
  catch (e) {
    print("Error loading .env file: $e");
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() {
    //most important stuff
    runApp(const DmbApp());
  }, (error, stackTrace) {
    print("Caught zoned error: $error");
  });
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
        scaffoldBackgroundColor: Color(0xFF0B0B0B),
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

      await preloadPlaylistPreviews(loginUsername);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
            (Route<dynamic> route) => false,
      );
    } else {
      setState(() {
        bypassMsg = "Login Failed.\nPlease logout and then login again with the correct username & password";
      });
    }
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
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digital Media Bridge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Username field
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        prefixIcon: const Icon(Icons.person, color: Colors.white30),
                        hintText: 'Username',
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
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        prefixIcon: const Icon(Icons.lock, color: Colors.white30),
                        hintText: 'Password',
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
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Log In button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 8,
                          shadowColor: Colors.white24,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color.fromRGBO(10, 85, 163, 1.0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                                const SnackBar(
                                    content: Text("Cannot Connect To DMB Server")),
                              );
                            } else {
                              loginUsername = emailController.text;
                              loginPassword = passwordController.text;

                              await preloadPlaylistPreviews(loginUsername);

                              try {
                                _saveUsername(loginUsername, loginPassword);
                              } catch (_) {}

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomePage()),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                  Text('Username & Password are required')),
                            );
                          }
                        },
                        child: const Text('Log In'),
                      ),
                    ),
                  ],
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
      mainPageTitle = title;
      mainPageSubTitle = subTitle;
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
                  screensPageTitle: "Screens (${dmbScreens.length})",
                  screensPageSubTitle: selectedPlayerName != null
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
              mainPageTitle: "Media Players",
              mainPageSubTitle: "Select Player",
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