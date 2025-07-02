import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './players_page.dart';
import './dmb_functions.dart';

dynamic selectedIndex = 0;
dynamic mainPageTitle = "DMB Media Players";
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Digital Media Bridge',
            initialRoute: '/',
            theme: ThemeData(
              scaffoldBackgroundColor: const Color(0xFF000000),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
                focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30)),
              ),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: Colors.black,
                contentTextStyle:
                    TextStyle(color: Colors.white, fontSize: 16.sp),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.white70, width: 2),
                ),
              ),
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
              useMaterial3: true,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
          const AssetImage('assets/cilutions_background.jpg'), context);
    });
  }

  Future<bool> _readFromStorage() async {
    try {
      storedUsername = await systemStorage.read(key: "KEY_USERNAME") ?? "none";
      storedPassword = await systemStorage.read(key: "KEY_PASSWORD") ?? "none";
      return storedUsername != "none" && storedPassword != "none";
    } catch (exc) {
      return false;
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: FutureBuilder<bool>(
        future: _readFromStorage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          }
          if (snapshot.hasData && snapshot.data == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const BypassloginPage()),
              ).then((_) {});
            });
          }
          return LoginPage();
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
        MaterialPageRoute(builder: (context) => const HomePage()),
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Text(
          bypassMsg,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Digital Media Bridge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 48.h),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        prefixIcon:
                            const Icon(Icons.person, color: Colors.white30),
                        hintText: 'Username',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 16.sp),
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
                          borderSide: BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !_passwordPeak,
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[800],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordPeak
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white30,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordPeak = !_passwordPeak;
                            });
                          },
                        ),
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.white30),
                        hintText: 'Password',
                        hintStyle:
                            TextStyle(color: Colors.white54, fontSize: 16.sp),
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
                          borderSide: BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 32.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          elevation: 8,
                          shadowColor: Colors.white24,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          backgroundColor:
                              const Color.fromRGBO(10, 85, 163, 1.0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: TextStyle(
                            fontSize: 16.sp,
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
                                SnackBar(
                                    content: Text("Invalid Login",
                                        style: TextStyle(fontSize: 16.sp))),
                              );
                            } else if (result == "no_screens") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("No Screens To Play",
                                        style: TextStyle(fontSize: 16.sp))),
                              );
                            } else if (result == "no_players") {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("No Players To Update",
                                        style: TextStyle(fontSize: 16.sp))),
                              );
                            } else if (result == false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Cannot Connect To DMB Server",
                                        style: TextStyle(fontSize: 16.sp))),
                              );
                            } else {
                              loginUsername = emailController.text;
                              loginPassword = passwordController.text;
                              await _saveUsername(loginUsername, loginPassword);
                              await preloadPlaylistPreviews(loginUsername);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomePage()),
                              );
                            }
                          }
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                              fontSize: 16.sp),
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: PlayersPage(
        mainPageTitle: "Media Players",
        mainPageSubTitle: "Select Player",
        userEmail: loginUsername,
      ),
    );
  }
}