import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './dmb_functions.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

Future<void> _submit() async {
  final email = _emailController.text.trim();
  if (email.isEmpty) {
    setState(() => _errorText = 'Please enter your Email');
    return;
  }

  try {
    final ok = await createNewUser(email);
    if (ok) {
      await showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CupertinoAlertDialog(
          title: Text('Email Sent'),
          content: Text('\nPlease check your email to complete account creation.\n$email'),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      await showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CupertinoAlertDialog(
          title: Text('Already Registered'),
          content: Text('\nAn account with that email already exists.\n$email'),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    await showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text('\nSomething went wrong.\nPlease try again later.'),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        border: null,
        leading: CupertinoNavigationBarBackButton(color: CupertinoColors.white),
        automaticallyImplyMiddle: false,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                "What's your Email?",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 20.h),

              // Email input container
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  placeholderStyle: TextStyle(
                    color: CupertinoColors.white.withOpacity(0.7),
                    fontSize: 16.sp,
                  ),
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16.sp,
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                  cursorColor: CupertinoColors.white,
                  clearButtonMode: OverlayVisibilityMode.editing,
                  decoration: BoxDecoration(),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                ),
              ),
              SizedBox(height: 8.h),

              // Error message or space
              if (_errorText != null)
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 12.sp,
                  ),
                ),
              if (_errorText == null) SizedBox(height: 8.h),

              Text(
                "We will send you a link with your new account information.",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 24.h),
              // Sign Up button full width
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color.fromRGBO(10, 85, 163, 1.0),
                  child: Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                  onPressed: () {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() => _errorText = 'Please enter your email');
                      return;
                    }
                    _submit();
                  },
                ),
              ),

              Spacer(),

              // Bottom link button
              Center(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "I already have an account",
                    style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontSize: 14.sp,
                    ),
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
