import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      title: 'FocusFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFFFFFFFF),
        fontFamily: 'Roboto',
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

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
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
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFFFFFFF),
          unselectedItemColor: const Color(0xFF666666),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.adjust), label: 'Focus'),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Community',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
  int _selectedMinutes = 20; // Default 20 minutes
  int _totalSeconds = 20 * 60;
  int _remainingSeconds = 20 * 60;
  bool _isRunning = false;
  bool _isPickerVisible = false;
  late AnimationController _pulseController;
  late AnimationController _timerScaleController;
  late Animation<double> _timerScaleAnimation;

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
    final List<int> minuteOptions = List.generate(24, (index) => (index + 1) * 5);
    int selectedIndex = minuteOptions.indexOf(_selectedMinutes);
    if (selectedIndex == -1) selectedIndex = 3; // Default to 20 minutes (index 3)

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
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
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
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
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

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Icon(Icons.eco, color: const Color(0xFFFFFFFF), size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'FocusFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    color: const Color(0xFFFFFFFF),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Main Timer Area
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isPickerVisible && !_isRunning) {
                    _togglePicker();
                  }
                },
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    // Timer content - takes available space
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // Progress Circle
                                SizedBox(
                                  width: 240,
                                  height: 240,
                                  child: CustomPaint(
                                    painter: CircularProgressPainter(
                                      progress: progress,
                                      isRunning: _isRunning,
                                    ),
                                  ),
                                ),

                                // Center content - Earth image
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: const DecorationImage(
                                      image: AssetImage(
                                        'assets/images/earth.png',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // Timer display or picker - inline toggle with fixed height
                            GestureDetector(
                              onTap: _togglePicker,
                              child: SizedBox(
                                height: 150,
                                child: _isPickerVisible && !_isRunning
                                    ? _buildTimePicker()
                                    : AnimatedBuilder(
                                        animation: _timerScaleAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _timerScaleAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: Center(
                                          child: Text(
                                            '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Control buttons - fixed at bottom with 20px spacing
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pause/Play button (smaller, square with rounded corners)
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isRunning ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                              color: const Color(0xFF000000),
                              onPressed: () {
                                if (_isRunning) {
                                  _pauseTimer();
                                } else {
                                  _startTimer();
                                }
                              },
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Stop button (pill-shaped)
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: TextButton(
                              onPressed: _stopTimer,
                              child: const Text(
                                'Stop focusing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
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
          ],
        ),
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

    // Background circles
    final bgPaint1 = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bgPaint2 = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 10, bgPaint1);
    canvas.drawCircle(center, radius - 25, bgPaint2);

    // Progress arc
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: const Center(
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: const Center(
        child: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
