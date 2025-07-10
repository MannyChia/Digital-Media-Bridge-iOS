import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart'; // Using Cupertino
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './players_page.dart'; // Uncommented
import './dmb_functions.dart'; // Uncommented - assuming it's Cupertino-compatible or pure logic
import './screens_page.dart'; // Assuming this is needed and also converted

// Global variables - remain as is
dynamic selectedIndex = 0;
dynamic mainPageTitle = "Select Media Player";
dynamic mainPageSubTitle = "Select Player";
dynamic storedUsername = "none";
dynamic storedPassword = "none";
dynamic loginUsername = "none";
dynamic loginPassword = "none";

const systemStorage = FlutterSecureStorage();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  try {
    await dotenv.load(fileName: ".env");
    if (kDebugMode) {
      print("Loaded key: ${dotenv.env['LEONARDO_API_KEY']}");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error loading .env file: $e");
    }
  }
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  runZonedGuarded(() {
    runApp(const DmbApp());
  }, (error, stackTrace) {
    if (kDebugMode) {
      print("Caught zoned error: $error");
    }
  });
}

class DmbApp extends StatelessWidget {
  const DmbApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: false,
      splitScreenMode: true,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: CupertinoApp( // CupertinoApp as the root
            debugShowCheckedModeBanner: false,
            title: 'Digital Media Bridge',
            initialRoute: '/',
            theme: const CupertinoThemeData(
              primaryColor: CupertinoColors.activeBlue,
              // Use CupertinoColors for scaffold background
              scaffoldBackgroundColor: CupertinoColors.black,
              barBackgroundColor: CupertinoColors.black, // For navigation bars
              // Add other Cupertino theme properties as needed
            ),
            home: const MyHomePage(title: 'Digital Media Bridge'),
            // Define routes if you use named routes
            // routes: {
            //   '/home': (context) => const HomePage(),
            //   '/login': (context) => const LoginPage(),
            //   '/bypassLogin': (context) => const BypassloginPage(),
            // },
          ),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // precacheImage( // Uncommented if you have a Cupertino-style background, otherwise not needed
      //     const AssetImage('assets/cilutions_background.jpg'), context);
    });
  }

  Future<bool> _readFromStorage() async { // Uncommented
    try {
      storedUsername = await systemStorage.read(key: "KEY_USERNAME") ?? "none";
      storedPassword = await systemStorage.read(key: "KEY_PASSWORD") ?? "none";
      return storedUsername != "none" && storedPassword != "none";
    } catch (exc) {
      if (kDebugMode) {
        print("Error reading from storage: $exc");
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold( // CupertinoPageScaffold
      backgroundColor: CupertinoColors.black, // Explicitly black background
      child: FutureBuilder<bool>(
        future: _readFromStorage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator( // Cupertino loading indicator
                radius: 15.0, // Adjust size as needed
              ),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Using CupertinoPageRoute for navigation
              Navigator.push(
                context,
                CupertinoPageRoute(
                    builder: (context) => const BypassloginPage()),
              ).then((_) {});
            });
          }
          return const LoginPage(); // Assuming LoginPage is also Cupertino
        },
      ),
    );
  }
}

class BypassloginPage extends StatefulWidget {
  const BypassloginPage({super.key});
  @override
  _BypassloginPageState createState() => _BypassloginPageState();
}

class _BypassloginPageState extends State<BypassloginPage> {
  var bypassMsg = "Loading...";
  @override
  void initState() {
    super.initState();
    _getBypassLogin();
  }

  Future<void> _getBypassLogin() async {
    final result =
        await getUserData(storedUsername, storedPassword, "bypass-login");
    if (result == true) {
      loginUsername = storedUsername;
      loginPassword = storedPassword;
      await preloadPlaylistPreviews(loginUsername);
      // Using CupertinoPageRoute for navigation
      Navigator.pushAndRemoveUntil(
        context,
        CupertinoPageRoute(builder: (context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
    } else {
      setState(() {
        bypassMsg =
            "Login Failed.\nPlease logout and then login again with the correct username & password";
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black, // Cupertino black
      child: Center(
        child: Text(
          bypassMsg,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: CupertinoColors.white, // Cupertino white
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // GlobalKey for Form is typically used with Material's Form/TextFormField.
  // For Cupertino, you'd usually validate manually or use a different validation approach.
  // Keeping it for potential future integration with a Cupertino-compatible validation package.
  final _formKey = GlobalKey<FormState>(); // Still FormState
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _passwordPeak = false;

  Future<void> _saveUsername(String login, String password) async { // Uncommented
    await systemStorage.write(key: "KEY_USERNAME", value: login);
    await systemStorage.write(key: "KEY_PASSWORD", value: password);
  }

  // Helper function for Cupertino-style alerts
  void _showCupertinoAlert(BuildContext context, String title, String message, {Color? titleColor}) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(
          title,
          style: TextStyle(color: titleColor ?? CupertinoColors.label),
        ),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text("OK"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black, // Cupertino black
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digital Media Bridge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CupertinoColors.white, // Cupertino white
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 48.h),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray, // Cupertino dark grey
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.person, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField( // Cupertino TextField
                        controller: emailController,
                        placeholder: 'Username',
                        maxLength: 40,
                        style: const TextStyle(color: CupertinoColors.white),
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        cursorColor: CupertinoColors.white,
                        decoration: const BoxDecoration(), // No border by default
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray, // Cupertino dark grey
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lock, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField( // Cupertino TextField
                        controller: passwordController,
                        placeholder: 'Password',
                        obscureText: !_passwordPeak,
                        maxLength: 40,
                        style: const TextStyle(color: CupertinoColors.white),
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        cursorColor: CupertinoColors.white,
                        decoration: const BoxDecoration(), // No border by default
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _passwordPeak = !_passwordPeak;
                        });
                      },
                      child: Icon(
                        _passwordPeak ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled( // Cupertino filled button
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  borderRadius: BorderRadius.circular(8),
                  // Use a Cupertino-compatible color or a custom one
                  color: const Color.fromRGBO(10, 85, 163, 1.0), // Your custom blue
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                  onPressed: () async {
                    // For CupertinoTextField, validation is usually done by checking controller.text
                    // directly, as there's no built-in validator like TextFormField.
                    // The _formKey.currentState!.validate() will always be true unless you wrap
                    // your CupertinoTextFields in a custom FormField-like widget or manually add validation logic.
                    // For demonstration, I'll proceed as if validation passes or handle errors immediately.

                    // Basic validation check
                    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                      _showCupertinoAlert(
                        context,
                        "Input Error",
                        "Please enter both username and password.",
                        titleColor: CupertinoColors.systemRed,
                      );
                      return;
                    }

                    final result = await getUserData(
                      emailController.text,
                      passwordController.text,
                      "user-login",
                    );
                    if (result == "invalid_login") {
                      _showCupertinoAlert(
                        context,
                        "Login Failed",
                        "Invalid Username or Password.",
                        titleColor: CupertinoColors.systemRed,
                      );
                    } else if (result == "no_screens") {
                      _showCupertinoAlert(
                        context,
                        "Login Failed",
                        "No Screens To Play.",
                        titleColor: CupertinoColors.systemRed,
                      );
                    } else if (result == "no_players") {
                      _showCupertinoAlert(
                        context,
                        "Login Failed",
                        "No Players To Update.",
                        titleColor: CupertinoColors.systemRed,
                      );
                    } else if (result == false) {
                      _showCupertinoAlert(
                        context,
                        "Connection Error",
                        "Cannot Connect To DMB Server.",
                        titleColor: CupertinoColors.systemRed,
                      );
                    }
                    else {
                      loginUsername = emailController.text;
                      loginPassword = passwordController.text;
                      await _saveUsername(loginUsername, loginPassword);
                      await preloadPlaylistPreviews(loginUsername);
                      // Using CupertinoPageRoute for navigation
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                            builder: (context) => const HomePage()),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// HomePage class from your previous request, already converted.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: PlayersPage( 
        mainPageTitle: "Select Media Player",
        mainPageSubTitle: "Select Player",
        userEmail: loginUsername,
      ),
    );
  }
}