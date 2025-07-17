import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart'; 
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './players_page.dart';
import './dmb_functions.dart'; 
import './screens_page.dart'; 

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
          child: CupertinoApp( 
            debugShowCheckedModeBanner: false,
            title: 'Digital Media Bridge',
            initialRoute: '/',
            theme: const CupertinoThemeData(
              primaryColor: CupertinoColors.activeBlue,
              scaffoldBackgroundColor: CupertinoColors.black,
              barBackgroundColor: CupertinoColors.black, 
            ),
            home: const MyHomePage(title: 'Digital Media Bridge'),

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
    return CupertinoPageScaffold( 
      backgroundColor: CupertinoColors.black, 
      child: FutureBuilder<bool>(
        future: _readFromStorage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator( 
                radius: 15.0, 
              ),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.push(
                context,
                CupertinoPageRoute(
                    builder: (context) => const BypassloginPage()),
              ).then((_) {});
            });
          }
          return const LoginPage(); 
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
      backgroundColor: CupertinoColors.black, 
      child: Center(
        child: Text(
          bypassMsg,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: CupertinoColors.white,
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
  final _formKey = GlobalKey<FormState>(); 
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _passwordPeak = false;

  Future<void> _saveUsername(String login, String password) async { 
    await systemStorage.write(key: "KEY_USERNAME", value: login);
    await systemStorage.write(key: "KEY_PASSWORD", value: password);
  }

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
      backgroundColor: CupertinoColors.black, 
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
                  color: CupertinoColors.white, 
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 48.h),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray, 
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.person, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField( 
                        controller: emailController,
                        placeholder: 'Username',
                        maxLength: 40,
                        style: const TextStyle(color: CupertinoColors.white),
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.white.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        cursorColor: CupertinoColors.white,
                        decoration: const BoxDecoration(), 
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray, 
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lock, color: CupertinoColors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CupertinoTextField( 
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
                        decoration: const BoxDecoration(), 
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
                child: CupertinoButton.filled( 
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color.fromRGBO(10, 85, 163, 1.0), 
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                  onPressed: () async {
                    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
                      _showCupertinoAlert(
                        context,
                        "Input Error",
                        "Please enter both username and password.",
                        titleColor: CupertinoColors.white,
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
                        titleColor: CupertinoColors.white,
                      );
                    } else if (result == "no_screens") {
                      _showCupertinoAlert(
                        context,
                        "Login Failed",
                        "No Screens To Play.",
                        titleColor: CupertinoColors.white,
                      );
                    } else if (result == "no_players") {
                      _showCupertinoAlert(
                        context,
                        "Login Failed",
                        "No Players To Update.",
                        titleColor: CupertinoColors.white,
                      );
                    } else if (result == false) {
                      _showCupertinoAlert(
                        context,
                        "Connection Error",
                        "Cannot Connect To DMB Server.",
                        titleColor: CupertinoColors.white,
                      );
                    }
                    else {
                      loginUsername = emailController.text;
                      loginPassword = passwordController.text;
                      await _saveUsername(loginUsername, loginPassword);
                      await preloadPlaylistPreviews(loginUsername);
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