import 'package:rideshare/cloud_functions/firebase_function.dart';
import 'package:rideshare/providers/user_state.dart';
import 'package:rideshare/screens/login/custom_route.dart';
import 'package:rideshare/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import '../root.dart';

class LoginScreen extends StatelessWidget {
  static const routeName = '/login';
  final UserState userState;
  static bool isFirstTimeLoad = false;

  const LoginScreen({super.key, required this.userState});
  Duration get loginTime => const Duration(milliseconds: 1000);

  Future<String?> _handleLogin(BuildContext context, String email) async {
    try {
      await FirebaseFunctions.fetchUserByEmail(email).then((user) async {
        await userState.setCurrentUser(user!);
        await userState.loadData();
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Close keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Add a Scaffold with safe area handling
        body: SafeArea(
          // Use SafeArea to handle notches and system UI
          minimum: const EdgeInsets.all(0),
          child: FlutterLogin(
            title: "RideShare",
            titleTag: "RideShare",
            theme: LoginTheme(
              titleStyle: const TextStyle(
                fontFamily: 'Garamond',
                fontWeight: FontWeight.bold,
                fontSize: 24.0,
              ),
              primaryColor: const Color(0xFF6A4C93),
              accentColor: const Color(0xFF8A70B8),
              // Key fix for half screen issue - use proper page colors
              pageColorLight: const Color(0xFF6A4C93),
              pageColorDark: const Color(0xFF4A2C73),
              buttonTheme: LoginButtonTheme(
                backgroundColor: const Color(0xFF6A4C93),
                elevation: 4,
              ),
              cardTheme: CardTheme(
                color: Colors.white,
                elevation: 5,
                margin: const EdgeInsets.only(top: 15, bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
              ),
              inputTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.all(16.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            userType: LoginUserType.email,
            onLogin: (data) async {
              final err = await FirebaseFunctions.authUser(data);
              if (err == null) {
                return await _handleLogin(context, data.name);
              } else {
                return err;
              }
            },
            onSignup: (data) async {
              final err = await FirebaseFunctions.signupUser(data);
              if (err == null) {
                return await _handleLogin(context, data.name!);
              } else {
                return err;
              }
            },
            onSubmitAnimationCompleted: () {
              // Fix for black screen - add a small delay before navigation
              Future.delayed(const Duration(milliseconds: 300), () {
                if (isFirstTimeLoad) {
                  isFirstTimeLoad = false;
                  Navigator.of(context).pushReplacement(
                    FadePageRoute(
                      builder: (context) => OnboardingScreen(
                        userState: userState,
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).pushReplacement(
                    FadePageRoute(
                      builder: (context) => RootNavigationView(
                        userState: userState,
                      ),
                    ),
                  );
                }
              });
            },
            userValidator: (value) =>
                value == null || value.isEmpty ? 'Email is required' : null,
            passwordValidator: (value) =>
                value == null || value.isEmpty ? 'Password is required' : null,
            onRecoverPassword: FirebaseFunctions.recoverPassword,
            messages: LoginMessages(
              userHint: 'Email',
              passwordHint: 'Password',
              confirmPasswordHint: 'Confirm Password',
              loginButton: 'LOG IN',
              signupButton: 'SIGN UP',
              forgotPasswordButton: 'Forgot Password?',
              recoverPasswordButton: 'RESET',
              goBackButton: 'BACK',
            ),
            loginAfterSignUp: true,
            additionalSignupFields: [
              UserFormField(
                  keyName: "firstName",
                  displayName: "First Name",
                  icon: const Icon(Icons.person),
                  fieldValidator: (value) =>
                      value!.isEmpty ? 'First Name is required' : null),
              UserFormField(
                  keyName: "lastName",
                  displayName: "Last Name",
                  icon: const Icon(Icons.person_outline),
                  fieldValidator: (value) =>
                      value!.isEmpty ? 'Last Name is required' : null),
            ],
          ),
        ),
      ),
    );
  }
}
