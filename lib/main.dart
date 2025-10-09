import 'package:flutter/material.dart';
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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const FocusScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
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
    );
  }
}

// Focus Screen with Timer
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  final int _totalSeconds = 20 * 60; // 20 minutes default
  int _remainingSeconds = 20 * 60;
  bool _isRunning = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
    });
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
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Circular Timer
                      Column(
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
                                    image: AssetImage('assets/images/earth.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Info section below circle
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${(_remainingSeconds ~/ 3600).toString().padLeft(2, '0')}h ${((_remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}m',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'left',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${(((_totalSeconds - _remainingSeconds) / _totalSeconds) * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'completed',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Control buttons
                          Row(
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
                        ],
                      ),
                    ],
                  ),
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
