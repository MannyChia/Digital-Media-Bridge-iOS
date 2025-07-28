import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import './dmb_functions.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
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
      print('Please enter your email');
      return;
    }
    try {
      //TODO: need to make snack bars in the future
      final ok = await resetPassword(email);
      if (ok) {
        print('Reset link (success): $email');
        Navigator.of(context).pop();
      } else {
        print('No account: $email');
      }
    } catch (e) {
      print('Exception forgot pwd: $e');
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
              Text(
                "What's your email or username?",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                "We'll help you find your account.",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email or username',
                  placeholderStyle: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16.sp,
                  ),
                  style:
                      TextStyle(color: CupertinoColors.white, fontSize: 16.sp),
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                  cursorColor: CupertinoColors.white,
                  clearButtonMode: OverlayVisibilityMode.editing,
                  decoration: BoxDecoration(),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),
              if (_errorText != null) ...[
                SizedBox(height: 8.h),
                Text(
                  _errorText!,
                  style: TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 12.sp,
                  ),
                ),
              ] else
                SizedBox(height: 8.h),
              Text(
                "You may receive email notifications from us for security and login purposes.",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  borderRadius: BorderRadius.circular(30.r),
                  child: Text(
                    'Recover',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() {
                        _errorText = 'Please enter your email or username';
                      });
                      return;
                    }
                    _submit();
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
