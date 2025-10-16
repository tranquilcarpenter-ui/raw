import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RAW',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFFFFFFFF),
        fontFamily: 'Inter',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  AnimationController? _navBarController;
  Animation<double>? _navBarAnimation;

  @override
  void initState() {
    super.initState();
    _navBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _navBarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _navBarController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _navBarController?.dispose();
    super.dispose();
  }

  void _onFocusStateChanged(bool isRunning) {
    if (isRunning) {
      _navBarController?.forward();
    } else {
      _navBarController?.reverse();
    }
  }

  Widget _buildNavItem(
    String iconPath,
    int index,
    String label, {
    bool useMaterialIcon = false,
    IconData? materialIcon,
    bool isProfilePicture = false,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: isProfilePicture
              ? Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF6C6C70),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      iconPath,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6C6C70),
                          size: 22,
                        );
                      },
                    ),
                  ),
                )
              : useMaterialIcon && materialIcon != null
              ? Icon(
                  materialIcon,
                  color: isSelected ? Colors.white : const Color(0xFF6C6C70),
                  size: 28,
                )
              : SvgPicture.asset(
                  iconPath,
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(
                    isSelected ? Colors.white : const Color(0xFF6C6C70),
                    BlendMode.srcIn,
                  ),
                ),
        ),
      ),
    );
  }

  Widget get _currentScreen {
    switch (_currentIndex) {
      case 0:
        return FocusScreen(onFocusStateChanged: _onFocusStateChanged);
      case 1:
        return const CommunityScreen();
      case 2:
        return const ProfileScreen();
      default:
        return FocusScreen(onFocusStateChanged: _onFocusStateChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentScreen,
      bottomNavigationBar: _navBarAnimation == null
          ? null
          : AnimatedBuilder(
              animation: _navBarAnimation!,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 80 * _navBarAnimation!.value),
                  child: Opacity(
                    opacity: 1 - _navBarAnimation!.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(30, 0, 30, 50),
                width: 358,
                height: 53,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1D),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      'assets/images/Icons/timericon.svg',
                      0,
                      'Focus',
                    ),
                    _buildNavItem(
                      'assets/images/Icons/groupiconlight.svg',
                      1,
                      'Community',
                    ),
                    _buildNavItem(
                      'assets/images/pfpplaceholder.JPG',
                      2,
                      'Profile',
                      isProfilePicture: true,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Focus Screen with Timer
class FocusScreen extends StatefulWidget {
  final Function(bool)? onFocusStateChanged;

  const FocusScreen({super.key, this.onFocusStateChanged});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  int _selectedMinutes = 60; // Default 60 minutes to match Figma
  int _totalSeconds = 60 * 60;
  int _remainingSeconds = 60 * 60;
  bool _isRunning = false;
  bool _isPickerVisible = false;
  late AnimationController _pulseController;
  late AnimationController _timerScaleController;
  late Animation<double> _timerScaleAnimation;

  // Color extraction
  List<Color> _paletteColors = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _timerScaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _timerScaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _timerScaleController, curve: Curves.easeInOut),
    );
    _extractImageColors();
  }

  Future<void> _extractImageColors() async {
    final PaletteGenerator paletteGenerator =
        await PaletteGenerator.fromImageProvider(
          const AssetImage('assets/images/lava.png'),
          maximumColorCount: 20,
        );

    setState(() {
      // Collect multiple colors for gradient
      _paletteColors = [
        paletteGenerator.vibrantColor?.color,
        paletteGenerator.lightVibrantColor?.color,
        paletteGenerator.darkVibrantColor?.color,
        paletteGenerator.mutedColor?.color,
        paletteGenerator.lightMutedColor?.color,
      ].whereType<Color>().toList();

      // Fallback colors if extraction fails
      if (_paletteColors.isEmpty) {
        _paletteColors = [const Color(0xFF4A90E2), const Color(0xFF50C878)];
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _timerScaleController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
    _timerScaleController.forward();
    widget.onFocusStateChanged?.call(true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopTimer();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    _timerScaleController.reverse();
    widget.onFocusStateChanged?.call(false);
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
    _timerScaleController.reverse();
    widget.onFocusStateChanged?.call(false);
  }

  void _togglePicker() {
    if (!_isRunning) {
      setState(() {
        _isPickerVisible = !_isPickerVisible;
      });
    }
  }

  void _onPickerChanged(int minutes) {
    setState(() {
      _selectedMinutes = minutes;
      _totalSeconds = _selectedMinutes * 60;
      _remainingSeconds = _totalSeconds;
    });
  }

  Widget _buildTimePicker() {
    // Generate list of minutes in 5-minute increments (5, 10, 15, ..., 120)
    final List<int> minuteOptions = List.generate(
      24,
      (index) => (index + 1) * 5,
    );
    int selectedIndex = minuteOptions.indexOf(_selectedMinutes);
    if (selectedIndex == -1) {
      selectedIndex = 11; // Default to 60 minutes (index 11)
    }

    return GestureDetector(
      onTap: _togglePicker,
      child: SizedBox(
        height: 150, // 3 items with proper spacing
        child: CupertinoPicker(
          itemExtent: 50, // Height of each item
          scrollController: FixedExtentScrollController(
            initialItem: selectedIndex,
          ),
          selectionOverlay: GestureDetector(
            onTap: _togglePicker,
            child: Container(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 0,
                  ),
                ),
              ),
            ),
          ),
          onSelectedItemChanged: (int index) {
            _onPickerChanged(minuteOptions[index]);
          },
          children: minuteOptions.map((minutes) {
            return GestureDetector(
              onTap: _togglePicker,
              child: Center(
                child: Text(
                  '${minutes.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _totalSeconds > 0
        ? 1 - (_remainingSeconds / _totalSeconds)
        : 0;

    // Using responsive layout
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          return Container(
            width: double.infinity,
            height: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: Colors.black),
            child: Stack(
              children: [
                // Timer text and picker - Centered
                if (!_isRunning && _isPickerVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        screenHeight *
                        0.522, // Adjusted to center the 150px picker
                    child: GestureDetector(
                      onTap: _togglePicker,
                      child: Center(child: _buildTimePicker()),
                    ),
                  ),

                // Timer text - Centered
                if (!_isPickerVisible || _isRunning)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenHeight * 0.570, // 504/844 ≈ 0.597
                    child: GestureDetector(
                      onTap: _togglePicker,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _timerScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _timerScaleAnimation.value,
                              child: child,
                            );
                          },
                          child: Text(
                            '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 45,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Pause and Stop buttons container - when running
                if (_isRunning)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenHeight * 0.723, // 610/844 ≈ 0.723
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause button
                          GestureDetector(
                            onTap: _pauseTimer,
                            child: Container(
                              width: 60,
                              height: 55,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D1D1D),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.pause,
                                  size: 32,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stop button
                          GestureDetector(
                            onTap: _stopTimer,
                            child: Container(
                              width: 185,
                              height: 55,
                              decoration: ShapeDecoration(
                                color: const Color(0xFF1D1D1D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'Stop focusing',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Start focusing button - Centered
                if (!_isRunning)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenHeight * 0.723, // 610/844 ≈ 0.723
                    child: Center(
                      child: GestureDetector(
                        onTap: _startTimer,
                        child: Container(
                          width: 185,
                          height: 55,
                          decoration: ShapeDecoration(
                            color: const Color(0xFF1D1D1D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Start focusing',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Progress circle - Centered
                Positioned(
                  left: 0,
                  right: 0,
                  top: screenHeight * 0.135, // 114/844 ≈ 0.135
                  child: Center(
                    child: SizedBox(
                      width: 227,
                      height: 227,
                      child: CustomPaint(
                        painter: CircularProgressPainter(
                          progress: progress,
                          isRunning: _isRunning,
                        ),
                      ),
                    ),
                  ),
                ),

                // RAW logo - 16px from left, 50px from top
                Positioned(
                  left: 16,
                  top: 50,
                  child: Image.asset(
                    'assets/images/rawlogo.png',
                    width: 70,
                    height: 31,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading rawlogo.png: $error');
                      return const Text(
                        'RAW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),

                // Streak counter - 16px from right, 50px from top
                Positioned(
                  right: 16,
                  top: 50,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '1',
                        style: TextStyle(
                          color: Color(0xFFE68510),
                          fontSize: 16,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFFFA500),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Custom Painter for Circular Progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isRunning;

  CircularProgressPainter({required this.progress, required this.isRunning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Progress arc only - no background strokes
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC), Color(0xFFFFFFFF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 17.5),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isRunning != isRunning;
  }
}

// Community Screen (Placeholder)
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: Text(
          'Community',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

// Profile Screen (Placeholder)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF000000),
      body: Center(
        child: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
