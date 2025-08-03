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
    setState(() => _errorText = 'Please enter your Email');
    return;
  }

  try {
    final ok = await resetPassword(email);
    if (ok) {
      await showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CupertinoAlertDialog(
          title: Text('Email Sent'),
          content: Text('\nA reset link has been sent to\n$email'),
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
        builder: (_) => CupertinoAlertDialog(
          title: Text('No Account Found'),
          content: Text('\nNo account exists for\n$email'),
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
              Text(
                "What's your Email?",
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 20.h),

              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.darkBackgroundGray,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: CupertinoTextField(
                  controller: _emailController,
                  placeholder: 'Email',
                  placeholderStyle: TextStyle(
                    color: CupertinoColors.white,
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
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),
              SizedBox(height: 8.h),
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
                "We will send you a link to reset your password.",
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
                  borderRadius: BorderRadius.circular(8.r),
                  color: const Color.fromRGBO(10, 85, 163, 1.0),
                  child: Text(
                    'Recover',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  ),
                  onPressed: () {
                    final email = _emailController.text.trim();
                    if (email.isEmpty) {
                      setState(() {
                        _errorText = 'Please enter your Email';
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
