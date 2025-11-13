import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Main authentication screen - unified login/signup with email and social options
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    // Show loading indicator using state
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if email exists in Firestore by querying users collection
      debugPrint('AuthScreen: ========================================');
      debugPrint('AuthScreen: Starting email existence check');
      debugPrint('AuthScreen: Email to check: $email');
      debugPrint('AuthScreen: Firestore settings: ${FirebaseFirestore.instance.settings}');

      final startTime = DateTime.now();
      debugPrint('AuthScreen: Creating Firestore query...');

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              final elapsed = DateTime.now().difference(startTime).inSeconds;
              debugPrint('AuthScreen: ❌ Query TIMED OUT after $elapsed seconds');
              throw Exception('Query timed out - please check your connection');
            },
          );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('AuthScreen: ✅ Query completed in ${elapsed}ms');
      debugPrint('AuthScreen: Found ${querySnapshot.docs.length} documents');

      final emailExists = querySnapshot.docs.isNotEmpty;
      debugPrint('AuthScreen: Email exists: $emailExists');
      debugPrint('AuthScreen: ========================================');

      if (!mounted) return;

      debugPrint('AuthScreen: Stopping loading indicator...');
      setState(() {
        _isLoading = false;
      });
      debugPrint('AuthScreen: Loading stopped');

      if (!mounted) return;

      if (emailExists) {
        debugPrint('AuthScreen: Navigating to LoginScreen');
        // Email is registered - go to login screen
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 150),
            reverseTransitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        debugPrint('AuthScreen: Navigation to LoginScreen initiated');
      } else {
        debugPrint('AuthScreen: Navigating to SignUpScreen with email: $email');
        // Email not registered - start signup flow
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              debugPrint('AuthScreen: SignUpScreen pageBuilder called');
              return SignUpScreen(initialEmail: email);
            },
            transitionDuration: const Duration(milliseconds: 150),
            reverseTransitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        debugPrint('AuthScreen: Navigator.push() completed');
      }
    } catch (e, stackTrace) {
      debugPrint('AuthScreen: ❌ ERROR occurred');
      debugPrint('AuthScreen: Error type: ${e.runtimeType}');
      debugPrint('AuthScreen: Error message: ${e.toString()}');
      debugPrint('AuthScreen: Stack trace: $stackTrace');
      debugPrint('AuthScreen: ========================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      // Show detailed error for debugging
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );

      // For now, default to signup flow if query fails
      // This allows users to continue even if Firestore has issues
      debugPrint('AuthScreen: Falling back to SignUpScreen due to error');
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              SignUpScreen(initialEmail: email),
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  Widget _buildSocialButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: FaIcon(icon, size: 18, color: iconColor),
        label: Text(text, style: const TextStyle(fontSize: 15)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF2F2F2F)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 20),

                    // RAW Logo
                    Image.asset(
                      'assets/images/RAW/ios_dark_icon.png',
                      height: 100,
                      width: 100,
                    ),

                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Log in or sign up',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Email input
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Email',
                        hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                        filled: true,
                        fillColor: const Color(0xFF1C1C1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Or divider
                    const Row(
                      children: [
                        Expanded(child: Divider(color: Color(0xFF2F2F2F))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFF2F2F2F))),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Social login buttons
                    _buildSocialButton(
                      text: 'Continue with Google',
                      icon: FontAwesomeIcons.google,
                      iconColor: const Color(0xFF4285F4), // Google Blue
                      onPressed: () {
                        // TODO: Implement Google Sign-In
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Google Sign-In coming soon'),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    _buildSocialButton(
                      text: 'Continue with Apple',
                      icon: FontAwesomeIcons.apple,
                      onPressed: () {
                        // TODO: Implement Apple Sign-In
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Apple Sign-In coming soon'),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Terms and Privacy Policy
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(
                            text: 'By continuing, you agree to our\n',
                          ),
                          TextSpan(
                            text: 'Terms',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TermsScreen(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PrivacyPolicyScreen(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
          ),
          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
