import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'user_data.dart';
import 'user_data_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedBirthday;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Create Firebase auth account
      final credential =
          await FirebaseService.instance.auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create user');
      }

      // Create complete user data in Firestore (profile + default statistics)
      final userData = UserData.newUser(
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim().isEmpty
            ? 'User'
            : _nameController.text.trim(),
        birthday: _selectedBirthday,
      );

      await UserDataService.instance.saveUserData(user.uid, userData);

      // Success - auth state listener will handle navigation
      if (mounted) {
        Navigator.of(context).pop(); // Go back to auth screen, which will redirect to main
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'weak-password') {
          _errorMessage = 'Password is too weak (min 6 characters)';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists with this email';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'Email address is badly formatted';
        } else {
          _errorMessage = e.message ?? 'An error occurred';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and progress
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_currentPage == 0) {
                              Navigator.of(context).pop();
                            } else {
                              _previousPage();
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: List.generate(4, (index) {
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(
                              right: index < 3 ? 8 : 0,
                            ),
                            decoration: BoxDecoration(
                              color: index <= _currentPage
                                  ? const Color(0xFF06B6D4)
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                    _errorMessage = '';
                  });
                },
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcomePage(),
                  _buildEmailPasswordPage(),
                  _buildNamePage(),
                  _buildBirthdayPage(),
                ],
              ),
            ),

            // Error message
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFF3B30),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Color(0xFFFF3B30),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (_currentPage == 0) {
                      _nextPage();
                    } else if (_currentPage == 1) {
                      _validateEmailPassword();
                    } else if (_currentPage == 2) {
                      _validateName();
                    } else {
                      _createAccount();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _currentPage == 3 ? 'Create Account' : 'Continue',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),

            // Skip button on birthday page
            if (_currentPage == 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _selectedBirthday = null);
                          _createAccount();
                        },
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _validateEmailPassword() {
    setState(() => _errorMessage = '');

    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter an email address');
      return;
    }

    if (!_emailController.text.trim().contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a password');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    _nextPage();
  }

  void _validateName() {
    setState(() => _errorMessage = '');

    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your name');
      return;
    }

    _nextPage();
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 60,
              color: Color(0xFF06B6D4),
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            'Welcome to RAW',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Track your focus, build better habits, and achieve your goals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailPasswordPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Create your account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Enter your email and create a password',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 40),

          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFF8E8E93),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Password must be at least 6 characters',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'What\'s your name?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'We\'ll use this to personalize your experience',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 40),

          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: const TextStyle(
                color: Color(0xFF8E8E93),
              ),
              filled: true,
              fillColor: const Color(0xFF1C1C1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'When\'s your birthday?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Optional - helps us provide age-appropriate insights',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 40),

          GestureDetector(
            onTap: () => _showBirthdayPicker(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedBirthday == null
                        ? 'Select your birthday'
                        : '${_selectedBirthday!.day}/${_selectedBirthday!.month}/${_selectedBirthday!.year}',
                    style: TextStyle(
                      color: _selectedBirthday == null
                          ? const Color(0xFF8E8E93)
                          : Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF06B6D4),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBirthdayPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        DateTime tempDate = _selectedBirthday ?? DateTime(2000, 1, 1);

        return Container(
          height: 300,
          color: const Color(0xFF1C1C1E),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF8E8E93)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Color(0xFF06B6D4)),
                      ),
                      onPressed: () {
                        setState(() => _selectedBirthday = tempDate);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: tempDate,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
