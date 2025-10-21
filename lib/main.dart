import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

// User Statistics Data Model
class UserStatistics {
  int dayStreak;
  int focusHours;
  String rankPercentage;
  String currentBadge;
  String currentBadgeProgress;
  String nextBadge;
  String nextBadgeProgress;
  Map<DateTime, double> dailyActivityData; // Date -> hours focused
  bool isGeneratedData; // Flag to indicate if data is test data
  DateTime? generatedAt; // Timestamp when data was generated

  UserStatistics({
    required this.dayStreak,
    required this.focusHours,
    required this.rankPercentage,
    required this.currentBadge,
    required this.currentBadgeProgress,
    required this.nextBadge,
    required this.nextBadgeProgress,
    required this.dailyActivityData,
    this.isGeneratedData = false,
    this.generatedAt,
  });

  // Factory constructor for default values (real user data)
  factory UserStatistics.initial() {
    // Generate initial activity data for the past 365 days
    final now = DateTime.now();
    final Map<DateTime, double> activityData = {};

    for (int i = 0; i < 365; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      // Sample data: varying activity levels
      activityData[date] = (i % 7 == 0 || i % 7 == 6)
          ? 1.0 + (i % 3)
          : 2.0 + (i % 5);
    }

    return UserStatistics(
      dayStreak: 23,
      focusHours: 278,
      rankPercentage: 'Top 35%',
      currentBadge: 'Radiant',
      currentBadgeProgress: '23/30 days',
      nextBadge: 'Dutiful',
      nextBadgeProgress: '278/500 days',
      dailyActivityData: activityData,
      isGeneratedData: false,
      generatedAt: null,
    );
  }

  // Factory constructor to generate random test data
  factory UserStatistics.random() {
    final random = math.Random();

    // Generate random day streak (1-365)
    final dayStreak = random.nextInt(365) + 1;

    // Generate random focus hours (50-2000)
    final focusHours = random.nextInt(1950) + 50;

    // Generate random rank percentage (Top 1% to Top 99%)
    final rankPercent = random.nextInt(99) + 1;
    final rankPercentage = 'Top $rankPercent%';

    // Generate random activity data for the past 365 days
    final now = DateTime.now();
    final Map<DateTime, double> activityData = {};

    for (int i = 0; i < 365; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      // Random hours between 0 and 8
      activityData[date] = random.nextDouble() * 8;
    }

    // Generate badge progress
    final currentBadgeDays = dayStreak % 30;
    final currentBadgeProgress = '$currentBadgeDays/30 days';
    final nextBadgeProgress = '$focusHours/500 days';

    return UserStatistics(
      dayStreak: dayStreak,
      focusHours: focusHours,
      rankPercentage: rankPercentage,
      currentBadge: 'Radiant',
      currentBadgeProgress: currentBadgeProgress,
      nextBadge: 'Dutiful',
      nextBadgeProgress: nextBadgeProgress,
      dailyActivityData: activityData,
      isGeneratedData: true,
      generatedAt: DateTime.now(),
    );
  }
}

// Global state management for user statistics
class UserStatisticsProvider extends InheritedWidget {
  final UserStatistics statistics;
  final Function(UserStatistics) updateStatistics;

  const UserStatisticsProvider({
    super.key,
    required this.statistics,
    required this.updateStatistics,
    required super.child,
  });

  static UserStatisticsProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserStatisticsProvider>();
  }

  @override
  bool updateShouldNotify(UserStatisticsProvider oldWidget) {
    return statistics != oldWidget.statistics;
  }
}

void main() {
  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  late UserStatistics _statistics;

  @override
  void initState() {
    super.initState();
    _statistics = UserStatistics.initial();
  }

  void _updateStatistics(UserStatistics newStatistics) {
    setState(() {
      _statistics = newStatistics;
    });
  }

  @override
  Widget build(BuildContext context) {
    return UserStatisticsProvider(
      statistics: _statistics,
      updateStatistics: _updateStatistics,
      child: MaterialApp(
        title: 'RAW',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF000000),
          primaryColor: const Color(0xFFFFFFFF),
          fontFamily: 'Inter',
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// Reusable SafeArea Template Widget
class AppSafeArea extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const AppSafeArea({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 50, 16, 0),
      child: child,
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
      extendBody: true,
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
                color: Colors.transparent,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Gradient background
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF000000).withValues(alpha: 0.02),
                              const Color(0xFF000000).withValues(alpha: 0.05),
                              const Color(0xFF000000).withValues(alpha: 0.1),
                              const Color(0xFF000000).withValues(alpha: 0.2),
                              const Color(0xFF000000).withValues(alpha: 0.35),
                              const Color(0xFF000000).withValues(alpha: 0.5),
                              const Color(0xFF000000).withValues(alpha: 0.7),
                              const Color(0xFF000000).withValues(alpha: 0.88),
                              const Color(0xFF000000),
                            ],
                            stops: const [
                              0.0,
                              0.1,
                              0.2,
                              0.3,
                              0.4,
                              0.5,
                              0.6,
                              0.75,
                              0.9,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Navigation bar
                    Container(
                      margin: const EdgeInsets.fromLTRB(30, 0, 30, 50),
                      width: 358,
                      height: 53,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1D1D),
                        borderRadius: BorderRadius.circular(20),
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
                // Top radiant gradient (Dynamic Island area)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        height: 250,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -1.2),
                            radius: 2.0,
                            colors: [
                              const Color.fromARGB(
                                255,
                                255,
                                255,
                                255,
                              ).withValues(alpha: 0.10),
                              const Color.fromARGB(
                                255,
                                4,
                                87,
                                240,
                              ).withValues(alpha: 0.08),
                              const Color.fromARGB(
                                255,
                                88,
                                121,
                                180,
                              ).withValues(alpha: 0.06),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.045),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.03),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.02),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.012),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.006),
                              const Color.fromARGB(
                                255,
                                0,
                                89,
                                255,
                              ).withValues(alpha: 0.003),
                              Colors.transparent,
                            ],
                            stops: const [
                              0.0,
                              0.15,
                              0.22,
                              0.42,
                              0.55,
                              0.65,
                              0.75,
                              0.8,
                              0.9,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

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
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFE68510), Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ).createShader(bounds),
                        child: const Text(
                          '1',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 1),
                      Image.asset(
                        'assets/images/Icons/streakicon.png',
                        width: 25,
                        height: 25,
                        fit: BoxFit.contain,
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    progressPaint.shader = const SweepGradient(
      startAngle: -math.pi / 2,
      colors: [Color(0xFFFFFFFF), Color(0xFFCCCCCC), Color(0xFFFFFFFF)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

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

// Community Screen
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedTab = 0; // 0 for Friends, 1 for Groups
  int _selectedFilter = 1; // 0 for Month, 1 for All time

  final List<Map<String, dynamic>> _friends = [
    {'rank': 1, 'name': 'Alex Wang', 'emoji': '18🔥', 'hours': '1252 h'},
    {'rank': 2, 'name': 'Amy Wills', 'emoji': '7🔥', 'hours': '952 h'},
    {'rank': 3, 'name': 'Mia Chemistry', 'emoji': '125🔥', 'hours': '897 h'},
    {'rank': 4, 'name': 'David Cal', 'emoji': '231🔥', 'hours': '723 h'},
    {'rank': 5, 'name': 'Me', 'emoji': '6🔥', 'hours': '241 h'},
    {'rank': 6, 'name': 'Luis Difal', 'emoji': '', 'hours': '212 h'},
    {'rank': 7, 'name': 'Gyenge Márk', 'emoji': '24🔥', 'hours': '197 h'},
  ];

  Widget _buildToggleButton(String text, IconData icon, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 13,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String text, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          color: isSelected ? const Color(0xFF3D3D3D) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendRow(Map<String, dynamic> friend) {
    final rank = friend['rank'] as int;
    final name = friend['name'] as String;
    final emoji = friend['emoji'] as String;
    final hours = friend['hours'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Profile Picture
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: const Icon(Icons.person, color: Color(0xFF8E8E93), size: 20),
          ),
          const SizedBox(width: 12),
          // Name and Emoji
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (emoji.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Inter'),
                  ),
                ],
              ],
            ),
          ),
          // Hours
          Text(
            hours,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Column(
        children: [
          // Controls row
          AppSafeArea(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
            child: Row(
              children: [
                // Container for Friends and Groups buttons
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: ShapeDecoration(
                    color: const Color(0xFF2C2C2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton('Friends', Icons.person, 0),
                      _buildToggleButton('Groups', Icons.group, 1),
                    ],
                  ),
                ),
                const Spacer(),
                if (_selectedTab == 0)
                  GestureDetector(
                    onTap: () {
                      // Add friends action
                    },
                    child: const Text(
                      '+ Add Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                if (_selectedTab == 1) ...[
                  Icon(Icons.ios_share, color: Colors.white, size: 20),
                  const SizedBox(width: 16),
                  Icon(Icons.more_vert, color: Colors.white, size: 20),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Month/All time Filter (only show for Friends tab)
          if (_selectedTab == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildFilterButton('Month', 0),
                  const SizedBox(width: 8),
                  _buildFilterButton('All time', 1),
                ],
              ),
            ),

          if (_selectedTab == 0) const SizedBox(height: 20),

          // Content - Friends List or Groups Page
          Expanded(
            child: _selectedTab == 0
                ? ListView.builder(
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      return _buildFriendRow(_friends[index]);
                    },
                  )
                : _buildGroupsPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsPage() {
    return Column(
      children: [
        // Group Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const Text(
                'The Focused Few',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, color: Color(0xFF8E8E93), size: 12),
                  const SizedBox(width: 4),
                  const Text(
                    '18 member',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Month/All time Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildFilterButton('Month', 0),
              const SizedBox(width: 8),
              _buildFilterButton('All time', 1),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Group Members List
        Expanded(
          child: ListView.builder(
            itemCount: _friends.length,
            itemBuilder: (context, index) {
              return _buildFriendRow(_friends[index]);
            },
          ),
        ),
      ],
    );
  }
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year
  int _currentOffset =
      0; // Offset for navigation (0 = current period, 1 = previous period, etc.)
  int? _selectedDayIndex; // Index of selected bar in the graph

  // Get the number of days based on selected period
  int get _daysInPeriod {
    switch (_selectedPeriod) {
      case 0: // Week
        return 7;
      case 1: // Month
        return 30;
      case 2: // Year
        return 365;
      default:
        return 7;
    }
  }

  // Get period label
  String get _periodLabel {
    final now = DateTime.now();
    final daysBack = _currentOffset * _daysInPeriod;

    if (_currentOffset == 0) {
      switch (_selectedPeriod) {
        case 0:
          return 'This Week';
        case 1:
          return 'This Month';
        case 2:
          return 'This Year';
        default:
          return 'This Week';
      }
    } else {
      final startDate = now.subtract(
        Duration(days: daysBack + _daysInPeriod - 1),
      );
      final endDate = now.subtract(Duration(days: daysBack));

      if (_selectedPeriod == 0) {
        // Week format
        return '${startDate.month}/${startDate.day} - ${endDate.month}/${endDate.day}';
      } else if (_selectedPeriod == 1) {
        // Month format
        final monthNames = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${monthNames[startDate.month - 1]} ${startDate.year}';
      } else {
        // Year format - show the year being viewed
        return '${now.year - _currentOffset}';
      }
    }
  }

  void _navigatePrevious() {
    setState(() {
      _currentOffset++;
      _selectedDayIndex = null; // Reset selection when navigating
    });
  }

  void _navigateNext() {
    if (_currentOffset > 0) {
      setState(() {
        _currentOffset--;
        _selectedDayIndex = null; // Reset selection when navigating
      });
    }
  }

  void _onBarTapped(int index) {
    setState(() {
      if (_selectedDayIndex == index) {
        _selectedDayIndex = null; // Deselect if already selected
      } else {
        _selectedDayIndex = index;
      }
    });
  }

  String _getSelectedDayLabel(int index, DateTime now, int daysBack) {
    if (_selectedPeriod == 0) {
      // Week: Show day name (index 0 = Monday, 6 = Sunday)
      final weekDays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekDays[index];
    } else if (_selectedPeriod == 1) {
      // Month: Show date
      final date = now.subtract(
        Duration(days: daysBack + _daysInPeriod - 1 - index),
      );
      final monthNames = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${monthNames[date.month - 1]} ${date.day}';
    } else {
      // Year: Show month name
      final monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return monthNames[index % 12];
    }
  }

  @override
  Widget build(BuildContext context) {
    final statisticsProvider = UserStatisticsProvider.of(context);
    final statistics =
        statisticsProvider?.statistics ?? UserStatistics.initial();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner and Profile Header Stack
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Banner Image with alpha fade and gradient overlay
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: Stack(
                    children: [
                      // Banner image with alpha fade
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black,
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.5, 0.7, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            'assets/images/pfbannerplaceholder.jpg',
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      // Gradient overlay for darkening
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.transparent,
                                const Color(0xFF000000).withValues(alpha: 0.05),
                                const Color(0xFF000000).withValues(alpha: 0.15),
                                const Color(0xFF000000).withValues(alpha: 0.3),
                                const Color(0xFF000000).withValues(alpha: 0.5),
                                const Color(0xFF000000).withValues(alpha: 0.7),
                                const Color(0xFF000000).withValues(alpha: 0.88),
                                const Color(0xFF000000),
                              ],
                              stops: const [
                                0.0,
                                0.15,
                                0.3,
                                0.42,
                                0.54,
                                0.65,
                                0.75,
                                0.85,
                                0.95,
                                1.0,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile picture overlaying the banner bottom
                Positioned(
                  top: 180,
                  left: 16,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF000000),
                        width: 4,
                      ),
                      color: const Color(0xFF2C2C2E),
                    ),
                    child: const ClipOval(
                      child: Icon(Icons.person, color: Colors.white, size: 45),
                    ),
                  ),
                ),
                // Settings icon on banner
                Positioned(
                  top: 180,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000).withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                // Profile info (Name and rank) positioned next to profile picture
                Positioned(
                  top: 180,
                  left: 120,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Serena',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              color: Color(0xFFFFD700),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statistics.rankPercentage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 80),

            // Rest of content with AppSafeArea padding
            AppSafeArea(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Achievement Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (index) {
                      final colors = [
                        [const Color(0xFF6B46C1), const Color(0xFF3B21A8)],
                        [const Color(0xFF06B6D4), const Color(0xFF0891B2)],
                        [const Color(0xFFDC2626), const Color(0xFF991B1B)],
                        [const Color(0xFF84CC16), const Color(0xFF65A30D)],
                        [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                        [const Color(0xFFF97316), const Color(0xFFEA580C)],
                        [const Color(0xFF10B981), const Color(0xFF059669)],
                      ];
                      return Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors[index],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors[index][0].withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Stats Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${statistics.dayStreak}',
                                style: const TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 48,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'DAY STREAK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${statistics.focusHours}',
                                style: const TextStyle(
                                  color: Color(0xFFB794F6),
                                  fontSize: 48,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'FOCUS HOURS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Small Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C2C2E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    statistics.currentBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statistics.currentBadgeProgress,
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 11,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C2C2E),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.military_tech,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    statistics.nextBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statistics.nextBadgeProgress,
                                    style: const TextStyle(
                                      color: Color(0xFF8E8E93),
                                      fontSize: 11,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Activity Graph
                  _buildActivityGraph(statistics),

                  const SizedBox(height: 16),

                  // Period Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _navigatePrevious,
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Text(
                        _periodLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: _navigateNext,
                        child: Icon(
                          Icons.chevron_right,
                          color: _currentOffset > 0
                              ? Colors.white
                              : const Color(0xFF3A3A3C),
                          size: 24,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityGraph(UserStatistics statistics) {
    final now = DateTime.now();
    final daysBack = _currentOffset * _daysInPeriod;

    // Get data for the current period
    List<double> periodData = [];
    List<String> labels = [];

    if (_selectedPeriod == 0) {
      // Week: Show current week (Monday-Sunday)
      final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Calculate the start of the week (Monday)
      final currentWeekday = now.weekday; // 1=Monday, 7=Sunday
      final mondayOffset = currentWeekday - 1; // Days since Monday
      final monday = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: mondayOffset + (_currentOffset * 7)));

      // Get data for Monday through Sunday
      for (int i = 0; i < 7; i++) {
        final date = monday.add(Duration(days: i));
        final hours = statistics.dailyActivityData[date] ?? 0.0;
        periodData.add(hours);
        labels.add(weekDays[i]);
      }
    } else if (_selectedPeriod == 1) {
      // Month view
      for (int i = _daysInPeriod - 1; i >= 0; i--) {
        final date = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: daysBack + i));
        final hours = statistics.dailyActivityData[date] ?? 0.0;
        periodData.add(hours);
      }
      // Month: Show every 5th day or fewer labels
      final step = _daysInPeriod > 15 ? 5 : 3;
      for (int i = 0; i < _daysInPeriod; i++) {
        if (i % step == 0 || i == _daysInPeriod - 1) {
          final date = now.subtract(
            Duration(days: daysBack + _daysInPeriod - 1 - i),
          );
          labels.add('${date.day}');
        } else {
          labels.add('');
        }
      }
    } else {
      // Year: Show month labels and aggregate data by month
      final months = [
        'J',
        'F',
        'M',
        'A',
        'M',
        'J',
        'J',
        'A',
        'S',
        'O',
        'N',
        'D',
      ];

      // Calculate which year we're looking at
      // For current offset (0), use current year
      // For past offsets, subtract years
      final targetYear = now.year - _currentOffset;

      // Create labels for all 12 months
      for (int i = 0; i < 12; i++) {
        labels.add(months[i]);
      }

      // Group data by month for year view
      List<double> monthlyData = [];
      for (int month = 1; month <= 12; month++) {
        double monthTotal = 0;

        // Get all days in this specific month of the target year
        final daysInThisMonth = DateTime(targetYear, month + 1, 0).day;

        for (int day = 1; day <= daysInThisMonth; day++) {
          final date = DateTime(targetYear, month, day);

          // Only include if the date is not in the future
          if (date.isBefore(now) ||
              date.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
            monthTotal += statistics.dailyActivityData[date] ?? 0.0;
          }
        }

        // Add total focused hours for the month
        monthlyData.add(monthTotal);
      }
      periodData = monthlyData;
    }

    // Find max value for scaling
    final maxValue = periodData.isEmpty
        ? 1.0
        : periodData.reduce((a, b) => a > b ? a : b);
    // Round up to next full hour for Y-axis, ensuring at least 1 hour gap above max bar
    final ceiledMax = maxValue.ceil();
    final yAxisMax = maxValue == 0
        ? 1
        : (ceiledMax - maxValue < 1.0 ? ceiledMax + 1 : ceiledMax);

    // Calculate average or selected day value
    final double displayValue;
    final String displayLabel;
    final bool showAverage;

    if (_selectedDayIndex != null && _selectedDayIndex! < periodData.length) {
      // Show selected day value
      displayValue = periodData[_selectedDayIndex!];
      displayLabel = _getSelectedDayLabel(_selectedDayIndex!, now, daysBack);
      showAverage = false;
    } else {
      // Show average
      if (_selectedPeriod == 2) {
        // For year view: only average non-zero months (ignore empty months)
        final nonEmptyMonths = periodData.where((value) => value > 0).toList();
        showAverage = nonEmptyMonths.length >= 2;
        displayValue = nonEmptyMonths.isEmpty
            ? 0.0
            : nonEmptyMonths.reduce((a, b) => a + b) / nonEmptyMonths.length;
        displayLabel = 'Monthly Average';
      } else {
        // For week/month view: only average non-zero days (ignore empty days)
        final nonZeroDays = periodData.where((value) => value > 0).toList();
        showAverage = nonZeroDays.length >= 2;
        displayValue = nonZeroDays.isEmpty
            ? 0.0
            : nonZeroDays.reduce((a, b) => a + b) / nonZeroDays.length;
        displayLabel = 'Daily Average';
      }
    }

    // Format hours and minutes
    final hours = displayValue.floor();
    final minutes = ((displayValue - hours) * 60).round();
    final timeString = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label showing average or selected day with period buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayLabel,
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeString,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                // Period selection buttons
                Row(
                  children: [
                    _buildPeriodButton('Week', 0),
                    const SizedBox(width: 8),
                    _buildPeriodButton('Month', 1),
                    const SizedBox(width: 8),
                    _buildPeriodButton('Year', 2),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bar chart with Y-axis
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Bars container with horizontal lines
                  Expanded(
                    child: Stack(
                      children: [
                        // Horizontal line at top (rounded-up max value position)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 0.5,
                            color: const Color(
                              0xFF8E8E93,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        // Horizontal line at bottom (0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 0.5,
                            color: const Color(
                              0xFF8E8E93,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        // Dashed line for average (only show when no bar is selected and there's enough data)
                        if (_selectedDayIndex == null && showAverage)
                          Positioned(
                            bottom:
                                150 * (displayValue / yAxisMax).clamp(0.0, 1.0),
                            left: 0,
                            right: 0,
                            child: CustomPaint(
                              size: const Size(double.infinity, 1),
                              painter: DashedLinePainter(
                                color: const Color(
                                  0xFF8E8E93,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        // Bars
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              _selectedPeriod == 2 && _daysInPeriod > 30
                                  ? 12
                                  : _daysInPeriod,
                              (index) {
                                final value = index < periodData.length
                                    ? periodData[index]
                                    : 0.0;
                                final heightPercent = yAxisMax > 0
                                    ? (value / yAxisMax).clamp(0.0, 1.0)
                                    : 0.0;
                                final isSelected = _selectedDayIndex == index;

                                // Determine if any bar is selected and this bar is not it
                                final hasSelection = _selectedDayIndex != null;
                                final shouldDim = hasSelection && !isSelected;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => _onBarTapped(index),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: _selectedPeriod == 1
                                            ? 2
                                            : 11,
                                      ),
                                      child: Opacity(
                                        opacity: shouldDim ? 0.2 : 1.0,
                                        child: Container(
                                          width: _selectedPeriod == 1 ? 3 : 6,
                                          height: 150 * heightPercent,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                              colors: [
                                                const Color.fromARGB(
                                                  255,
                                                  48,
                                                  48,
                                                  48,
                                                ),
                                                const Color.fromARGB(
                                                  255,
                                                  73,
                                                  73,
                                                  73,
                                                ),
                                                const Color.fromARGB(
                                                  255,
                                                  109,
                                                  109,
                                                  109,
                                                ),
                                                const Color.fromARGB(
                                                  255,
                                                  190,
                                                  190,
                                                  190,
                                                ),
                                              ],
                                              stops: const [
                                                0.0,
                                                0.25,
                                                0.5,
                                                1.0,
                                              ],
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  topRight: Radius.circular(6),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Y-axis labels on the right
                  SizedBox(
                    width: 13,
                    height: 150,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Top label (rounded max value)
                        Positioned(
                          top: -6,
                          child: Text(
                            '${yAxisMax}h',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                        // Average label (middle) - only show when no bar is selected and there's enough data
                        if (_selectedDayIndex == null && showAverage)
                          Positioned(
                            bottom:
                                150 *
                                    (displayValue / yAxisMax).clamp(0.0, 1.0) -
                                5,
                            child: Text(
                              'avg',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 9,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        // Bottom label (0)
                        const Positioned(
                          bottom: -5,
                          child: Text(
                            '0',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // X-axis labels
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: List.generate(
                      _selectedPeriod == 2 && _daysInPeriod > 30
                          ? 12
                          : _daysInPeriod,
                      (index) {
                        return Expanded(
                          child: Text(
                            index < labels.length ? labels[index] : '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 10,
                              fontFamily: 'Inter',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const SizedBox(width: 13),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String text, int index) {
    final isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = index;
          _currentOffset = 0; // Reset to current period when switching
          _selectedDayIndex = null; // Reset selection when switching period
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 11,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// Custom painter for dashed line
class DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  DashedLinePainter({
    required this.color,
    this.dashWidth = 4,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}

// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isGenerating = false;

  void _generateRandomData() {
    final statisticsProvider = UserStatisticsProvider.of(context);

    if (statisticsProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not access statistics provider'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    // Simulate data generation with delay
    Future.delayed(const Duration(seconds: 2), () {
      // Generate random statistics
      final newStatistics = UserStatistics.random();

      // Update the global state
      statisticsProvider.updateStatistics(newStatistics);

      setState(() {
        _isGenerating = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Random data generated!\n'
            'Day Streak: ${newStatistics.dayStreak}, '
            'Focus Hours: ${newStatistics.focusHours}',
          ),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Widget _buildSettingsItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF7C3AED)).withValues(
                  alpha: 0.2,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? const Color(0xFF7C3AED),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 13,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statisticsProvider = UserStatisticsProvider.of(context);
    final statistics =
        statisticsProvider?.statistics ?? UserStatistics.initial();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: AppSafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'General',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Account Settings
              _buildSettingsItem(
                title: 'Account',
                subtitle: 'Manage your account settings',
                icon: Icons.person_outline,
                onTap: () {},
              ),

              // Notifications
              _buildSettingsItem(
                title: 'Notifications',
                subtitle: 'Configure notification preferences',
                icon: Icons.notifications_outlined,
                onTap: () {},
              ),

              // Privacy
              _buildSettingsItem(
                title: 'Privacy',
                subtitle: 'Privacy and data settings',
                icon: Icons.lock_outline,
                onTap: () {},
              ),

              // About
              _buildSettingsItem(
                title: 'About',
                subtitle: 'Version info and licenses',
                icon: Icons.info_outline,
                onTap: () {},
              ),

              const SizedBox(height: 24),

              // Developer Options Section
              const Text(
                'Developer Options',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Active Generated Data Display (only if data is generated)
              if (statistics.isGeneratedData && statistics.generatedAt != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF9500,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TEST DATA ACTIVE',
                              style: TextStyle(
                                color: Color(0xFFFF9500),
                                fontSize: 10,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimestamp(
                              statistics.generatedAt ?? DateTime.now(),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 11,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Currently Displaying Generated Data:',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDataRow(
                        'Day Streak',
                        '${statistics.dayStreak} days',
                      ),
                      _buildDataRow(
                        'Focus Hours',
                        '${statistics.focusHours} hours',
                      ),
                      _buildDataRow('Rank', statistics.rankPercentage),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFDC2626),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: const Text(
                                'This is test data. Not from real user activity.',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 11,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Generate Random Data Button
              _buildSettingsItem(
                title: 'Generate Random Data',
                subtitle: 'Create test data for statistics and testing',
                icon: Icons.shuffle,
                iconColor: const Color(0xFFFF9500),
                onTap: _isGenerating ? () {} : _generateRandomData,
              ),

              // Clear Test Data Button (only if data is generated)
              if (statistics.isGeneratedData)
                _buildSettingsItem(
                  title: 'Clear Test Data',
                  subtitle: 'Restore original user data',
                  icon: Icons.restore,
                  iconColor: const Color(0xFFDC2626),
                  onTap: _isGenerating
                      ? () {}
                      : () {
                          statisticsProvider?.updateStatistics(
                            UserStatistics.initial(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Test data cleared. Restored original data.',
                              ),
                              backgroundColor: Color(0xFF00C853),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                ),

              if (_isGenerating)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF9500)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
