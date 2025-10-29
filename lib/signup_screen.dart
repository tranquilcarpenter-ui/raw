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
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  int get _currentPage => _currentPageNotifier.value;

  // Form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  DateTime? _selectedBirthday;
  String? _selectedGender;
  final Map<String, String> _questionAnswers = {};
  final List<Offset> _signaturePoints = [];

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isEmailValid = false;

  // Total pages: 0=Email/Password, 1=Name/Username, 2=Birthday/Gender, 3-9=Questions (7 total), 10=Signature
  final int _totalPages =
      11; // 3 info pages + 7 question pages + 1 signature page

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    // Check if email is complete: has @ and ., and has at least 2 chars after the last dot
    final isValid =
        email.isNotEmpty &&
        email.contains('@') &&
        email.contains('.') &&
        email.indexOf('@') < email.lastIndexOf('.') &&
        email.lastIndexOf('.') < email.length - 1 &&
        email.substring(email.lastIndexOf('.') + 1).length >= 2;
    if (isValid != _isEmailValid) {
      setState(() {
        _isEmailValid = isValid;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getPageTitle() {
    switch (_currentPage) {
      case 0:
        return 'General informations';
      case 1:
        return 'Tell us about yourself';
      case 2:
        return 'A few more details';
      default:
        return '';
    }
  }

  void _validateSignatureAndCreateAccount() {
    if (_signaturePoints.isEmpty) {
      setState(() => _errorMessage = 'Please sign to confirm your commitment');
      return;
    }
    _createAccount();
  }

  Future<void> _createAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Create Firebase auth account
      final credential = await FirebaseService.instance.auth
          .createUserWithEmailAndPassword(
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
        fullName: _displayNameController.text.trim().isEmpty
            ? 'User'
            : _displayNameController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        birthday: _selectedBirthday,
        gender: _selectedGender,
        questionAnswers: _questionAnswers.isNotEmpty ? _questionAnswers : null,
      );

      await UserDataService.instance.saveUserData(user.uid, userData);

      // Success - auth state listener will handle navigation
      if (mounted) {
        Navigator.of(
          context,
        ).pop(); // Go back to auth screen, which will redirect to main
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
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title/progress
            ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, child) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Back button on the left
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (currentPage == 0) {
                                    Navigator.of(context).pop();
                                  } else {
                                    _previousPage();
                                  }
                                },
                        ),
                      ),
                      // Centered title or progress indicator
                      if (currentPage >= 3)
                        // Progress indicator for question pages
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_totalPages - 3, (index) {
                            final questionPage = index + 3;
                            final isActive = questionPage == currentPage;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index < (_totalPages - 4) ? 4 : 0,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: isActive ? 32 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A3A3C),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        )
                      else
                        // Page title for info pages
                        Text(
                          _getPageTitle(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (page) {
                  _currentPageNotifier.value = page;
                  if (_errorMessage.isNotEmpty) {
                    setState(() {
                      _errorMessage = '';
                    });
                  }
                },
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  Widget page;
                  switch (index) {
                    case 0:
                      page = _buildEmailPasswordPage();
                      break;
                    case 1:
                      page = _buildNameUsernamePage();
                      break;
                    case 2:
                      page = _buildBirthdayGenderPage();
                      break;
                    case 3:
                    case 4:
                    case 5:
                    case 6:
                    case 7:
                    case 8:
                    case 9:
                      page = _buildQuestionPage(index - 2);
                      break;
                    case 10:
                      page = _buildSignaturePage();
                      break;
                    default:
                      page = Container();
                  }
                  return RepaintBoundary(
                    key: ValueKey(index),
                    child: page,
                  );
                },
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
                  border: Border.all(color: const Color(0xFFFF3B30), width: 1),
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

            // Navigation buttons - hide on question pages (3-9)
            ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, child) {
                // Show Continue button on info pages and signature page
                if (currentPage < 3 || currentPage == _totalPages - 1) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                if (currentPage == 0) {
                                  _validateEmailPassword();
                                } else if (currentPage == 1) {
                                  _validateNameUsername();
                                } else if (currentPage == 2) {
                                  _validateBirthdayGender();
                                } else {
                                  // Signature page (page 10), create account
                                  _validateSignatureAndCreateAccount();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                                currentPage == _totalPages - 1
                                    ? 'Accept & Continue'
                                    : 'Continue',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  );
                }
                // Show "Skip for now" on question pages (3-9)
                else if (currentPage >= 3 && currentPage < _totalPages - 1) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          // Skip all questions and go directly to signature page
                          _pageController.jumpToPage(_totalPages - 1);
                        },
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
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

    if (!_isEmailValid) {
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

    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please confirm your password');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    _nextPage();
  }

  void _validateNameUsername() {
    setState(() => _errorMessage = '');

    if (_displayNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your display name');
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a username');
      return;
    }

    _nextPage();
  }

  void _validateBirthdayGender() {
    setState(() => _errorMessage = '');

    if (_selectedBirthday == null) {
      setState(() => _errorMessage = 'Please select your birthday');
      return;
    }

    if (_selectedGender == null || _selectedGender!.isEmpty) {
      setState(() => _errorMessage = 'Please select your gender');
      return;
    }

    _nextPage();
  }

  Widget _buildEmailPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email label
          const Text(
            'Email',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Email field with validation checkmark
          TextField(
            controller: _emailController,
            autofocus: false,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'john@example.com',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: _isEmailValid
                  ? const Icon(Icons.check, color: Color(0xFF34C759), size: 24)
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // Password label
          const Text(
            'Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Password field with visibility toggle
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            obscuringCharacter: '*',
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: '******',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF8E8E93),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Confirm Password label
          const Text(
            'Confirm Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Confirm Password field with visibility toggle
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            obscuringCharacter: '*',
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: '******',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF8E8E93),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameUsernamePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display Name',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _displayNameController,
            autofocus: false,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'John Doe',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Username',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'johndoe',
              hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayGenderPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Birthday',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          GestureDetector(
            onTap: () => _showBirthdayPicker(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
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
                      fontSize: 16,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Gender',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              dropdownColor: const Color(0xFF2C2C2E),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              hint: const Text(
                'Select your gender',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(
                  value: 'Prefer not to say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(int questionNumber) {
    // Define question text based on question number
    final questionTexts = {
      1: 'What are your main goals for using RAW?',
      2: 'How do you prefer to work?',
      3: 'What time of day are you most productive?',
      4: 'What motivates you the most?',
      5: 'How do you handle distractions?',
      6: 'What is your biggest productivity challenge?',
      7: 'What would success look like for you?',
    };

    final questionKey = 'question_$questionNumber';
    final currentAnswer = _questionAnswers[questionKey] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Question $questionNumber of 7',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            questionTexts[questionNumber] ?? 'Question $questionNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          // Answer option buttons
          _buildAnswerButton('Option A', 'option_a', questionKey, currentAnswer),
          const SizedBox(height: 12),
          _buildAnswerButton('Option B', 'option_b', questionKey, currentAnswer),
          const SizedBox(height: 12),
          _buildAnswerButton('Option C', 'option_c', questionKey, currentAnswer),
          const SizedBox(height: 12),
          _buildAnswerButton('Option D', 'option_d', questionKey, currentAnswer),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(
    String text,
    String value,
    String questionKey,
    String currentAnswer,
  ) {
    final isSelected = currentAnswer == value;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _questionAnswers[questionKey] = value;
          });
          // Automatically go to next page after selecting an answer
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_currentPage < _totalPages - 1) {
              _nextPage();
            }
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFF3A3A3C)
              : const Color(0xFF2C2C2E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected
                ? const BorderSide(color: Colors.white, width: 1)
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSignaturePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "Let's use your phone as a tool, not as a distraction",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'Signature',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFC4C4C4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _signaturePoints.add(details.localPosition);
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _signaturePoints.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _signaturePoints.add(Offset.infinite);
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _SignaturePainter(_signaturePoints),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_signaturePoints.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _signaturePoints.clear();
                });
              },
              child: const Text(
                'Clear signature',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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

class _SignaturePainter extends CustomPainter {
  final List<Offset> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
