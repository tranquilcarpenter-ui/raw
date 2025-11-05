import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
// Firebase types are accessed via `FirebaseService` where needed
import 'firebase_service.dart';
import 'auth_provider.dart';
import 'auth_screen.dart';
import 'test_users_screen.dart';
import 'user_data.dart';
import 'user_data_service.dart';
import 'friend.dart';
import 'friends_service.dart';
import 'group.dart';
import 'groups_service.dart';
import 'project.dart';
import 'project_service.dart';
import 'project_selector_popup.dart';
import 'user_profile_screen.dart';
import 'notification_service.dart';
import 'notification.dart';
import 'achievement.dart';
import 'achievements_service.dart';
import 'achievements_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

// Firebase initialization is managed by `FirebaseService` singleton.

// Optimized helper function to build image widget from either local file or network URL
Widget buildImageFromPath(
  String imagePath, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Alignment alignment = Alignment.center,
  Widget? errorWidget,
}) {
  final isNetworkImage =
      imagePath.startsWith('http://') || imagePath.startsWith('https://');

  // Helper to safely convert dimension to int, returns null if invalid
  int? safeDimensionToInt(double? value, double multiplier) {
    if (value == null) return null;
    final result = value * multiplier;
    if (!result.isFinite || result <= 0 || result > 10000) return null;
    return result.round();
  }

  if (isNetworkImage) {
    return CachedNetworkImage(
      imageUrl: imagePath,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: const Color(0xFF2C2C2E),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) =>
          errorWidget ?? const Icon(Icons.error),
      memCacheWidth: safeDimensionToInt(width, 2),
      memCacheHeight: safeDimensionToInt(height, 2),
      maxWidthDiskCache: safeDimensionToInt(width, 3),
      maxHeightDiskCache: safeDimensionToInt(height, 3),
    );
  } else {
    return Image.file(
      File(imagePath),
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      cacheWidth: safeDimensionToInt(width, 2),
      cacheHeight: safeDimensionToInt(height, 2),
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget
          : null,
    );
  }
}

// Profile Image Provider
class ProfileImageProvider extends InheritedWidget {
  final String? profileImagePath;
  final String? bannerImagePath;
  final Function(String?) updateProfileImage;
  final Function(String?) updateBannerImage;

  const ProfileImageProvider({
    super.key,
    required this.profileImagePath,
    required this.bannerImagePath,
    required this.updateProfileImage,
    required this.updateBannerImage,
    required super.child,
  });

  static ProfileImageProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProfileImageProvider>();
  }

  @override
  bool updateShouldNotify(ProfileImageProvider oldWidget) {
    return oldWidget.profileImagePath != profileImagePath ||
        oldWidget.bannerImagePath != bannerImagePath;
  }
}

// Global state management for user data
class UserDataProvider extends InheritedWidget {
  final UserData userData;
  final Function(UserData) updateUserData;

  const UserDataProvider({
    super.key,
    required this.userData,
    required this.updateUserData,
    required super.child,
  });

  static UserDataProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserDataProvider>();
  }

  @override
  bool updateShouldNotify(UserDataProvider oldWidget) {
    return userData != oldWidget.userData;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase via the centralized singleton service.
  // This ensures a single initialization path and avoids race conditions
  // that can occur when multiple parts of the app access Firebase directly
  // during startup or when using the VS Code debugger.
  await FirebaseService.instance.initialize();

  // Emulator configuration is handled centrally inside `FirebaseService`
  // (it will configure Storage, Firestore and Auth emulators in debug builds).

  runApp(const FocusFlowApp());
}

class FocusFlowApp extends StatefulWidget {
  const FocusFlowApp({super.key});

  @override
  State<FocusFlowApp> createState() => _FocusFlowAppState();
}

class _FocusFlowAppState extends State<FocusFlowApp> {
  late UserData _userData;
  String? _profileImagePath;
  String? _bannerImagePath;
  String? _currentUserId;
  StreamSubscription<User?>? _authChangeSubscription;

  @override
  void initState() {
    super.initState();
    _userData = UserData.newUser(email: 'guest@example.com', fullName: 'User');
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    // Listen for authentication state changes
    _authChangeSubscription = FirebaseService.instance.auth.authStateChanges().listen((user) async {
      if (user != null && user.uid != _currentUserId) {
        // User logged in or changed - load their data
        debugPrint('👤 User logged in: ${user.uid}');
        debugPrint('   Email: ${user.email}');
        _currentUserId = user.uid;

        // Load user data from Firestore
        final userData = await UserDataService.instance.loadUserData(user.uid);

        // If no data exists (shouldn't happen with new flow), wait a bit and retry
        if (userData == null) {
          debugPrint('⚠️ No data found for user, retrying...');
          // Wait for signup process to complete saving data
          await Future.delayed(const Duration(seconds: 1));
          final retryUserData = await UserDataService.instance.loadUserData(
            user.uid,
          );

          if (retryUserData == null) {
            debugPrint('⚠️ Still no data found, creating default user data');
            final newUserData = UserData.newUser(
              email: user.email ?? 'user@example.com',
              fullName:
                  'User', // Don't use email prefix - let user set their name
            );
            await UserDataService.instance.saveUserData(
              user.uid,
              newUserData,
              merge: false,
            );
            setState(() {
              _userData = newUserData;
            });
          } else {
            debugPrint(
              '📊 Loaded data on retry: ${retryUserData.fullName}, Streak=${retryUserData.dayStreak}',
            );
            setState(() {
              _userData = retryUserData;
              _profileImagePath = retryUserData.avatarUrl;
              _bannerImagePath = retryUserData.bannerImageUrl;
            });
          }
        } else {
          debugPrint(
            '📊 Loaded data: ${userData.fullName}, Streak=${userData.dayStreak}, Hours=${userData.focusHours}',
          );
          setState(() {
            _userData = userData;
            // Load profile and banner images from UserData
            // IMPORTANT: Set to null if user doesn't have images, to clear previous user's images
            _profileImagePath = userData.avatarUrl;
            _bannerImagePath = userData.bannerImageUrl;
          });
        }
      } else if (user == null) {
        // User logged out - reset to default data
        debugPrint('👋 User logged out');
        _currentUserId = null;
        setState(() {
          _userData = UserData.newUser(
            email: 'guest@example.com',
            fullName: 'User',
          );
          // Clear profile and banner images
          _profileImagePath = null;
          _bannerImagePath = null;
        });
      }
    });
  }

  void _updateUserData(UserData newUserData) async {
    setState(() {
      _userData = newUserData;
    });

    // Save to Firestore if user is logged in
    final user = FirebaseService.instance.auth.currentUser;
    if (user != null) {
      try {
        debugPrint(
          '🔄 Update requested - saving to Firestore for user: ${user.uid}',
        );
        await UserDataService.instance.saveUserData(user.uid, newUserData);
      } catch (e) {
        debugPrint('❌ Error saving user data: $e');
      }
    } else {
      debugPrint('⚠️ Cannot save data - no user logged in');
    }
  }

  void _updateProfileImage(String? imagePath) {
    setState(() {
      _profileImagePath = imagePath;
    });
  }

  void _updateBannerImage(String? imagePath) {
    setState(() {
      _bannerImagePath = imagePath;
    });
  }

  @override
  void dispose() {
    _authChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthStateProvider(
      child: ProfileImageProvider(
        profileImagePath: _profileImagePath,
        bannerImagePath: _bannerImagePath,
        updateProfileImage: _updateProfileImage,
        updateBannerImage: _updateBannerImage,
        child: UserDataProvider(
          userData: _userData,
          updateUserData: _updateUserData,
          child: MaterialApp(
            title: 'RAW',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: const Color(0xFF000000),
              primaryColor: const Color(0xFFFFFFFF),
              fontFamily: 'Inter',
            ),
            home: Builder(
              builder: (context) {
                final authProvider = AuthProvider.of(context);

                // Show loading screen while checking auth state
                if (authProvider?.isLoading ?? true) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF000000),
                    body: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }

                // Show auth screen if not logged in
                if (authProvider?.user == null) {
                  return const AuthScreen();
                }

                // Check if user data has been loaded
                final userDataProvider = UserDataProvider.of(context);
                if (userDataProvider?.userData == null) {
                  // User is authenticated but data hasn't loaded yet
                  return const Scaffold(
                    backgroundColor: Color(0xFF000000),
                    body: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                }

                // User is logged in and data is loaded - show main app
                return const MainScreen();
              },
            ),
          ),
        ),
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

// Reusable Card Widget with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(borderRadius ?? 12),
        boxShadow: boxShadow,
        border: border,
      ),
      child: child,
    );
  }
}

// Global Pro Badge Widget
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
          fontSize: 10,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
        ),
      ),
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
  bool _isFocusRunning = false;
  bool _isScrollingDown = false;

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

  void _updateNavBarVisibility() {
    // Hide nav bar if either focus is running OR user is scrolling down
    if (_isFocusRunning || _isScrollingDown) {
      _navBarController?.forward();
    } else {
      _navBarController?.reverse();
    }
  }

  void _onFocusStateChanged(bool isRunning) {
    setState(() {
      _isFocusRunning = isRunning;
    });
    _updateNavBarVisibility();
  }

  void _onScrollDirectionChanged(bool isScrollingDown) {
    setState(() {
      _isScrollingDown = isScrollingDown;
    });
    _updateNavBarVisibility();
  }

  Widget _buildNavItem(
    String iconPath,
    int index,
    String label, {
    bool useMaterialIcon = false,
    IconData? materialIcon,
    bool isProfilePicture = false,
    bool isCustomImage = false,
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
                    child: isCustomImage
                        ? Image.file(
                            File(iconPath),
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
                          )
                        : Image.asset(
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
                  size: 35,
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
        return CommunityScreen(
          onScrollDirectionChanged: _onScrollDirectionChanged,
        );
      case 2:
        return SettingsScreen(
          onScrollDirectionChanged: _onScrollDirectionChanged,
        );
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
                            '',
                            2,
                            'Settings',
                            useMaterialIcon: true,
                            materialIcon: Icons.settings,
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

  // Project tracking
  String _selectedProjectId = 'unset';
  String? _selectedSubprojectId;
  String _selectedProjectName = 'Unset';

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

    // Update currentlyFocusing status in Firestore
    _updateFocusingStatus(true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _onTimerComplete();
        _stopTimer();
      }
    });
  }

  Future<void> _onTimerComplete() async {
    // Timer completed - save session and check achievements
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDataProvider = UserDataProvider.of(context);
      if (userDataProvider == null) return;

      final currentUserData = userDataProvider.userData;
      final sessionDuration = Duration(seconds: _totalSeconds);
      final sessionHours = sessionDuration.inMinutes / 60.0;

      // Create new focus session
      final newSession = FocusSession(
        start: DateTime.now().subtract(sessionDuration),
        duration: sessionDuration,
        projectId: _selectedProjectId,
        subprojectId: _selectedSubprojectId,
      );

      // Update user data with new session and increment focus hours
      final updatedUserData = currentUserData.copyWith(
        focusHours: currentUserData.focusHours + sessionHours.ceil(),
        focusSessions: [...currentUserData.focusSessions, newSession],
        updatedAt: DateTime.now(),
      );

      // Save updated user data
      userDataProvider.updateUserData(updatedUserData);

      // Check and unlock achievements
      final newAchievements = await AchievementsService.instance
          .checkAndUnlockAchievements(user.uid, updatedUserData);

      // Show notification if new achievements unlocked
      if (newAchievements.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🏆 Unlocked ${newAchievements.length} achievement${newAchievements.length > 1 ? 's' : ''}!',
            ),
            backgroundColor: const Color(0xFFFFD700),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      debugPrint('✅ Session saved and achievements checked!');
    } catch (e) {
      debugPrint('❌ Error saving session or checking achievements: $e');
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    _timerScaleController.reverse();
    widget.onFocusStateChanged?.call(false);

    // Update currentlyFocusing status in Firestore
    _updateFocusingStatus(false);
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
    _timerScaleController.reverse();
    widget.onFocusStateChanged?.call(false);

    // Update currentlyFocusing status in Firestore
    _updateFocusingStatus(false);
  }

  Future<void> _updateFocusingStatus(bool isFocusing) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'currentlyFocusing': isFocusing},
      );
    } catch (e) {
      debugPrint('❌ Error updating focusing status: $e');
    }
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

  void _showProjectSelector() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ProjectSelectorPopup(
        currentProjectId: _selectedProjectId,
        currentSubprojectId: _selectedSubprojectId,
        onProjectSelected: (projectId, subprojectId) async {
          // Load the project to get its name
          final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            final project = await ProjectService.instance.loadProject(
              userId,
              projectId,
            );
            setState(() {
              _selectedProjectId = projectId;
              _selectedSubprojectId = subprojectId;
              _selectedProjectName = project?.name ?? 'Unset';
            });
          }
        },
      ),
    );
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

                // Project selector button - Below start/stop buttons
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 100,
                  child: Center(
                    child: GestureDetector(
                      onTap: _isRunning ? null : _showProjectSelector,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D1D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              color: Color(0xFF007AFF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedProjectName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (!_isRunning) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Color(0xFF8E8E93),
                                size: 20,
                              ),
                            ],
                          ],
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
                    child: RepaintBoundary(
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
                ),

                // Welcome message - 16px from left, 50px from top
                Positioned(
                  left: 16,
                  top: 50,
                  right: 120, // Leave space for profile picture on the right
                  child: Builder(
                    builder: (context) {
                      final userDataProvider = UserDataProvider.of(context);
                      final userData =
                          userDataProvider?.userData ??
                          UserData.newUser(
                            email: 'guest@example.com',
                            fullName: 'User',
                          );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 13,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            userData.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Profile picture and streak counter - 16px from right, 50px from top
                Positioned(
                  right: 16,
                  top: 50,
                  child: Builder(
                    builder: (context) {
                      final profileImageProvider = ProfileImageProvider.of(
                        context,
                      );
                      final profileImagePath =
                          profileImageProvider?.profileImagePath;
                      final userDataProvider = UserDataProvider.of(context);
                      final userData =
                          userDataProvider?.userData ??
                          UserData.newUser(
                            email: 'guest@example.com',
                            fullName: 'User',
                          );

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Streak counter with Pro badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Color(0xFFE68510),
                                            Colors.white,
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ).createShader(bounds),
                                    child: Text(
                                      '${userData.dayStreak}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 0),
                                  Image.asset(
                                    'assets/images/Icons/streakicon.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                              if (userData.isPro) ...[
                                const SizedBox(height: 2),
                                const ProBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Profile picture with status indicator
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileScreen(
                                    onScrollDirectionChanged: null,
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF2C2C2E),
                                  ),
                                  child: ClipOval(
                                    child: profileImagePath != null
                                        ? buildImageFromPath(
                                            profileImagePath,
                                            fit: BoxFit.cover,
                                            errorWidget: const Icon(
                                              Icons.person,
                                              color: Color(0xFF8E8E93),
                                              size: 28,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person,
                                            color: Color(0xFF8E8E93),
                                            size: 28,
                                          ),
                                  ),
                                ),
                                // Online/offline status indicator
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color.fromARGB(
                                        255,
                                        96,
                                        221,
                                        101,
                                      ), // Green for online, use Colors.grey for offline
                                      border: Border.all(
                                        color: const Color(0xFF1C1C1E),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
  final Function(bool)? onScrollDirectionChanged;

  const CommunityScreen({super.key, this.onScrollDirectionChanged});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedTab = 0; // 0 for Friends, 1 for Groups
  int _selectedFilter = 1; // 0 for Month, 1 for All time

  final ScrollController _friendsScrollController = ScrollController();
  final ScrollController _groupsScrollController = ScrollController();
  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;

  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  List<Friend> _outgoingRequests = [];
  bool _loadingFriends = false;

  List<Group> _groups = [];
  bool _loadingGroups = false;

  @override
  void initState() {
    super.initState();
    _friendsScrollController.addListener(_onScroll);
    _groupsScrollController.addListener(_onScroll);
    _loadFriends();
    _loadPendingRequests();
    _loadOutgoingRequests();
    _loadGroups();
  }

  Future<void> _loadFriends() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loadingFriends = true;
    });

    try {
      final friends = await FriendsService.instance.getFriends(user.uid);
      if (mounted) {
        setState(() {
          _friends = friends;
          _loadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) {
        setState(() {
          _loadingFriends = false;
        });
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    try {
      final requests = await FriendsService.instance.getPendingRequests(
        user.uid,
      );
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
    }
  }

  Future<void> _loadOutgoingRequests() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    try {
      final requests = await FriendsService.instance.getOutgoingRequests(
        user.uid,
      );
      if (mounted) {
        setState(() {
          _outgoingRequests = requests;
        });
      }
    } catch (e) {
      debugPrint('Error loading outgoing requests: $e');
    }
  }

  Future<void> _loadGroups() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    setState(() {
      _loadingGroups = true;
    });

    try {
      final groups = await GroupsService.instance.getUserGroups(user.uid);
      if (mounted) {
        setState(() {
          _groups = groups;
          _loadingGroups = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) {
        setState(() {
          _loadingGroups = false;
        });
      }
    }
  }

  Future<void> _refreshCommunity() async {
    if (_selectedTab == 0) {
      // Friends tab
      await Future.wait([
        _loadFriends(),
        _loadPendingRequests(),
        _loadOutgoingRequests(),
      ]);
    } else {
      // Groups tab
      await _loadGroups();
    }
  }

  @override
  void dispose() {
    _friendsScrollController.removeListener(_onScroll);
    _groupsScrollController.removeListener(_onScroll);
    _friendsScrollController.dispose();
    _groupsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final ScrollController activeController = _selectedTab == 0
        ? _friendsScrollController
        : _groupsScrollController;

    if (activeController.hasClients) {
      final currentOffset = activeController.offset;
      final scrollDelta = currentOffset - _lastScrollOffset;

      // Only trigger if scroll is significant (more than 5 pixels)
      if (scrollDelta.abs() > 5) {
        final isScrollingDown = scrollDelta > 0;

        if (_isScrollingDown != isScrollingDown) {
          setState(() {
            _isScrollingDown = isScrollingDown;
          });
          widget.onScrollDirectionChanged?.call(isScrollingDown);
        }
      }

      _lastScrollOffset = currentOffset;
    }
  }

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

  Future<void> _showAddFriendDialog() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    final searchController = TextEditingController();
    Map<String, UserData> searchResults = {};
    bool isSearching = false;

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text(
              'Add Friend',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search by name or user ID',
                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Name or ID...',
                    hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF8E8E93),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.trim().isEmpty) {
                      setDialogState(() {
                        searchResults = {};
                      });
                      return;
                    }

                    setDialogState(() {
                      isSearching = true;
                    });

                    // Search by name or ID
                    Map<String, UserData> results;
                    if (query.trim().length < 20) {
                      // Search by name
                      results = await FriendsService.instance.searchUsersByName(
                        query.trim(),
                      );
                    } else {
                      // Search by ID (if query looks like a user ID)
                      final userById = await FriendsService.instance
                          .getUserById(query.trim());
                      results = userById != null
                          ? {query.trim(): userById}
                          : {};
                    }

                    // Filter out the current user from search results
                    results.remove(user.uid);

                    // Also filter out users who are already friends or have pending requests
                    final existingUserIds = await FriendsService.instance
                        .getExistingConnectionIds(user.uid);

                    results.removeWhere(
                      (userId, _) => existingUserIds.contains(userId),
                    );

                    setDialogState(() {
                      searchResults = results;
                      isSearching = false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (isSearching)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  )
                else if (searchResults.isEmpty &&
                    searchController.text.isNotEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No users found',
                        style: TextStyle(color: Color(0xFF8E8E93)),
                      ),
                    ),
                  )
                else if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final entry = searchResults.entries.elementAt(index);
                        final userId = entry.key;
                        final userData = entry.value;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2C2C2E),
                            child: userData.avatarUrl != null
                                ? ClipOval(
                                    child: buildImageFromPath(
                                      userData.avatarUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.person,
                                        color: Color(0xFF8E8E93),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Color(0xFF8E8E93),
                                  ),
                          ),
                          title: Text(
                            userData.fullName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            userData.email,
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.person_add,
                            color: Color(0xFF8B5CF6),
                          ),
                          onTap: () async {
                            Navigator.pop(context);

                            // Show loading
                            showDialog(
                              context: mounted ? this.context : context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            );

                            // Send friend request
                            final success = await FriendsService.instance
                                .sendFriendRequest(user.uid, userId);

                            // Close loading
                            if (mounted) Navigator.pop(this.context);

                            // Show result
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Friend request sent to ${userData.fullName}!'
                                        : 'Failed to send friend request',
                                  ),
                                  backgroundColor: success
                                      ? const Color(0xFF00C853)
                                      : const Color(0xFFDC2626),
                                ),
                              );

                              if (success) {
                                _loadOutgoingRequests();
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ],
        ),
      ),
      );
    } finally {
      // Always dispose controller when dialog closes
      searchController.dispose();
    }
  }

  Widget _buildFilterButton(String text, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
          // Re-sort friends based on selected filter
          if (index == 0) {
            // Sort by monthly hours
            _friends.sort(
              (a, b) => b.focusHoursMonth.compareTo(a.focusHoursMonth),
            );
          } else {
            // Sort by all-time hours
            _friends.sort((a, b) => b.focusHours.compareTo(a.focusHours));
          }
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

  List<Widget> _buildFriendRequestSections() {
    final List<Widget> sections = [];

    // Only show if there are any requests
    if (_pendingRequests.isEmpty && _outgoingRequests.isEmpty) {
      return sections;
    }

    // Show incoming friend requests if any
    if (_pendingRequests.isNotEmpty) {
      sections.addAll([
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Color(0xFF2C2C2E)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Friend Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendingRequests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'These users want to be your friend',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._pendingRequests.map((request) => _buildFriendRequestRow(request)),
      ]);
    }

    // Show outgoing friend requests if any
    if (_outgoingRequests.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(color: Color(0xFF2C2C2E)),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pending Friend Requests Sent',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Waiting for these users to accept your request',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 13,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._outgoingRequests.map(
          (request) => _buildOutgoingRequestRow(request),
        ),
        const SizedBox(height: 24),
      ]);
    }

    return sections;
  }

  Widget _buildOutgoingRequestRow(Friend request) {
    final name = request.fullName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: ClipOval(
              child: request.avatarUrl != null
                  ? buildImageFromPath(
                      request.avatarUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(
                        Icons.person,
                        color: Color(0xFF8E8E93),
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Color(0xFF8E8E93),
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Pending indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.schedule, color: Color(0xFF8B5CF6), size: 14),
                SizedBox(width: 4),
                Text(
                  'Pending',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 12,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestRow(Friend request) {
    final name = request.fullName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Profile Picture
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
            child: ClipOval(
              child: request.avatarUrl != null
                  ? buildImageFromPath(
                      request.avatarUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(
                        Icons.person,
                        color: Color(0xFF8E8E93),
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Color(0xFF8E8E93),
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          // Accept Button
          GestureDetector(
            onTap: () => _acceptFriendRequest(request),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Accept',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Reject Button
          GestureDetector(
            onTap: () => _rejectFriendRequest(request),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Reject',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptFriendRequest(Friend request) async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    final success = await FriendsService.instance.acceptFriendRequest(
      user.uid,
      request.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'You and ${request.fullName} are now friends!'
                : 'Failed to accept friend request',
          ),
          backgroundColor: success
              ? const Color(0xFF00C853)
              : const Color(0xFFDC2626),
        ),
      );

      if (success) {
        _loadFriends();
        _loadPendingRequests();
      }
    }
  }

  Future<void> _rejectFriendRequest(Friend request) async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) return;

    final success = await FriendsService.instance.rejectFriendRequest(
      user.uid,
      request.userId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Friend request from ${request.fullName} rejected'
                : 'Failed to reject friend request',
          ),
          backgroundColor: success
              ? const Color(0xFF8E8E93)
              : const Color(0xFFDC2626),
        ),
      );

      if (success) {
        _loadPendingRequests();
      }
    }
  }

  Widget _buildFriendRow(Friend friend, int rank) {
    final name = friend.fullName;
    final streakEmoji = friend.dayStreak > 0 ? '${friend.dayStreak}🔥' : '';
    // Show monthly or all-time hours based on filter (0 = Month, 1 = All time)
    final hours = _selectedFilter == 0
        ? '${friend.focusHoursMonth} h'
        : '${friend.focusHours} h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          // Load full user data and navigate to profile
          final userData = await FriendsService.instance.getUserById(
            friend.userId,
          );
          if (userData != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userData: userData,
                  userId: friend.userId,
                ),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: ClipOval(
                  child: friend.avatarUrl != null
                      ? buildImageFromPath(
                          friend.avatarUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorWidget: const Icon(
                            Icons.person,
                            color: Color(0xFF8E8E93),
                            size: 20,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFF8E8E93),
                          size: 20,
                        ),
                ),
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
                    if (streakEmoji.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        streakEmoji,
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
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
        ),
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
                if (_selectedTab == 0) ...[
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationCenterScreen(),
                        ),
                      );
                    },
                    child: StreamBuilder<int>(
                      stream:
                          firebase_auth
                                  .FirebaseAuth
                                  .instance
                                  .currentUser
                                  ?.uid !=
                              null
                          ? NotificationService.instance.streamUnreadCount(
                              firebase_auth
                                  .FirebaseAuth
                                  .instance
                                  .currentUser!
                                  .uid,
                            )
                          : Stream.value(0),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data ?? 0;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            // Unread badge
                            if (unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF3B30),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 20,
                    ),
                    color: const Color(0xFF1C1C1E),
                    onSelected: (value) {
                      if (value == 'add_friend') {
                        _showAddFriendDialog();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_friend',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add Friends',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
                ? _loadingFriends
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8B5CF6),
                          ),
                        )
                      : _friends.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _refreshCommunity,
                          color: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF1C1C1E),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                const Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Color(0xFF8E8E93),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No friends yet',
                                  style: TextStyle(
                                    color: Color(0xFF8E8E93),
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _showAddFriendDialog,
                                  child: const Text(
                                    'Tap the menu to add friends',
                                    style: TextStyle(
                                      color: Color(0xFF8B5CF6),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                // Friend request sections at the bottom
                                ..._buildFriendRequestSections(),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshCommunity,
                          color: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF1C1C1E),
                          child: CustomScrollView(
                            controller: _friendsScrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // Friends List
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final friend = _friends[index];
                                    return RepaintBoundary(
                                      key: ValueKey(friend.userId),
                                      child: _buildFriendRow(friend, index + 1),
                                    );
                                  },
                                  childCount: _friends.length,
                                  addRepaintBoundaries:
                                      false, // We manually added them
                                ),
                              ),
                              // Friend request sections at the bottom
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _buildFriendRequestSections(),
                                ),
                              ),
                            ],
                          ),
                        )
                : _buildGroupsPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsPage() {
    if (_loadingGroups) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCommunity,
      color: const Color(0xFF8B5CF6),
      backgroundColor: const Color(0xFF1C1C1E),
      child: CustomScrollView(
        controller: _groupsScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header with create and join buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateGroupDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showJoinGroupDialog,
                      icon: const Icon(Icons.group_add, size: 18),
                      label: const Text('Join Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Groups List
          if (_groups.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      color: Color(0xFF8E8E93),
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Groups Yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a group or join one with an invite code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final group = _groups[index];
                  return RepaintBoundary(
                    key: ValueKey(group.groupId),
                    child: _buildGroupCard(group),
                  );
                },
                childCount: _groups.length,
                addRepaintBoundaries: false, // We manually added them
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Group group) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGroupDetails(group),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                            Icons.person,
                            color: Color(0xFF8E8E93),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group.memberCount}',
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (group.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    group.description!,
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.vpn_key,
                              color: Color(0xFF8E8E93),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              group.inviteCode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _copyInviteCode(group.inviteCode),
                      icon: const Icon(
                        Icons.copy,
                        color: Color(0xFF8E8E93),
                        size: 20,
                      ),
                      tooltip: 'Copy Invite Code',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyInviteCode(String inviteCode) {
    // TODO: Implement clipboard copy with flutter/services Clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code $inviteCode copied!'),
        backgroundColor: const Color(0xFF1C1C1E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Group Name',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter group name',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description (Optional)',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter group description',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (name.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a group name'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
                return;
              }

              navigator.pop();

              final user = FirebaseService.instance.auth.currentUser;
              if (user == null) return;

              final description = descriptionController.text.trim();
              final group = await GroupsService.instance.createGroup(
                userId: user.uid,
                name: name,
                description: description.isNotEmpty ? description : null,
              );

              if (!mounted) return;

              if (group != null) {
                _loadGroups();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Group "${group.name}" created!'),
                    backgroundColor: const Color(0xFF1C1C1E),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to create group'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      // Always dispose controllers when dialog closes
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Join Group',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-character invite code',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: const TextStyle(
                  color: Color(0xFF8E8E93),
                  letterSpacing: 4,
                ),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

              if (code.length != 6) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid 6-character code'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
                return;
              }

              navigator.pop();

              final user = FirebaseService.instance.auth.currentUser;
              if (user == null) return;

              final success = await GroupsService.instance.joinGroup(
                user.uid,
                code,
              );

              if (!mounted) return;

              if (success) {
                _loadGroups();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Successfully joined group!'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Invalid code or already a member'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      // Always dispose controller when dialog closes
      codeController.dispose();
    });
  }

  void _showGroupDetails(Group group) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => GroupDetailsScreen(group: group),
          ),
        )
        .then((_) => _loadGroups()); // Reload groups when returning
  }
}

// Group Details Screen
class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<GroupMember> _members = [];
  bool _loading = false;
  // Reuse filter state defined in CommunityScreen; no local filter needed here.

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
    });

    try {
      final members = await GroupsService.instance.getGroupMembers(
        widget.group.groupId,
      );
      if (mounted) {
        setState(() {
          _members = members;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group members: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshMembers() async {
    await _loadMembers();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.instance.auth.currentUser;
    final isCreator = user != null && widget.group.isCreator(user.uid);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.group.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1C1C1E),
            onSelected: (value) {
              if (value == 'leave') {
                _confirmLeaveGroup();
              } else if (value == 'delete') {
                _confirmDeleteGroup();
              }
            },
            itemBuilder: (context) => [
              if (isCreator)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Group', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Leave Group', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _refreshMembers,
              color: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFF1C1C1E),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Group Info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (widget.group.description != null) ...[
                            Text(
                              widget.group.description!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Color(0xFF8E8E93),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${widget.group.memberCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Text(
                                      'Members',
                                      style: TextStyle(
                                        color: Color(0xFF8E8E93),
                                        fontSize: 12,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: const Color(0xFF2C2C2E),
                                ),
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.vpn_key,
                                      color: Color(0xFF8E8E93),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.group.inviteCode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const Text(
                                      'Invite Code',
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
                        ],
                      ),
                    ),
                  ),

                  // Members Header
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Members Leaderboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Members List
                  if (_members.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No members yet',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 14,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildMemberRow(_members[index], index + 1);
                      }, childCount: _members.length),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildMemberRow(GroupMember member, int rank) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Load full user data and navigate to profile
            final userData = await FriendsService.instance.getUserById(
              member.userId,
            );
            if (userData != null && mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(
                    userData: userData,
                    userId: member.userId,
                  ),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Rank
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? (rank == 1
                              ? const Color(0xFFFFD700)
                              : rank == 2
                              ? const Color(0xFFC0C0C0)
                              : const Color(0xFFCD7F32))
                        : const Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank <= 3 ? Colors.black : Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF2C2C2E),
                  backgroundImage: member.avatarUrl != null
                      ? (member.avatarUrl!.startsWith('http')
                            ? NetworkImage(member.avatarUrl!) as ImageProvider
                            : FileImage(File(member.avatarUrl!)))
                      : null,
                  child: member.avatarUrl == null
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFF8E8E93),
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Name
                Expanded(
                  child: Text(
                    member.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${member.focusHours}h',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${member.dayStreak} day streak',
                      style: const TextStyle(
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
        ),
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Group?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to leave "${widget.group.name}"?',
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              final user = FirebaseService.instance.auth.currentUser;
              if (user == null) return;

              final success = await GroupsService.instance.leaveGroup(
                user.uid,
                widget.group.groupId,
              );

              if (!mounted) return;

              if (success) {
                navigator.pop(); // Go back to groups list
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Left group successfully'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to leave group'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Leave',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Group?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.group.name}"? This action cannot be undone and will remove all members.',
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              navigator.pop();

              final success = await GroupsService.instance.deleteGroup(
                widget.group.groupId,
              );

              if (!mounted) return;

              if (success) {
                navigator.pop(); // Go back to groups list
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Group deleted successfully'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete group'),
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  final Function(bool)? onScrollDirectionChanged;

  const ProfileScreen({super.key, this.onScrollDirectionChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedPeriod = 0; // 0: Week, 1: Month, 2: Year
  int _currentOffset =
      0; // Offset for navigation (0 = current period, 1 = previous period, etc.)
  int? _selectedDayIndex; // Index of selected bar in the graph
  int? _selectedHourIndex; // Index of selected hour in the time of day graph

  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;

  int _friendsCount = 0;
  int _groupsCount = 0;
  bool _isLoadingCounts = true;

  List<Achievement> _achievements = [];
  bool _isLoadingAchievements = true;

  final ScreenshotController _screenshotController = ScreenshotController();

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload achievements whenever UserData changes (from UserDataProvider)
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ Cannot load achievements: No user logged in');
      return;
    }

    try {
      debugPrint('🏆 Loading achievements for user: ${user.uid}');

      // First, check and unlock any achievements based on current stats
      final userDataProvider = UserDataProvider.of(context);
      if (userDataProvider != null) {
        debugPrint(
          '🏆 UserData available: focusHours=${userDataProvider.userData.focusHours}, dayStreak=${userDataProvider.userData.dayStreak}',
        );
        await AchievementsService.instance.checkAndUnlockAchievements(
          user.uid,
          userDataProvider.userData,
        );
      } else {
        debugPrint('⚠️ UserDataProvider not available yet');
      }

      // Then load the updated achievements
      final achievements = await AchievementsService.instance
          .getUserAchievements(user.uid);

      debugPrint('🏆 Loaded ${achievements.length} achievements');
      final unlockedCount = achievements.where((a) => a.isUnlocked).length;
      debugPrint(
        '🏆 Unlocked achievements: $unlockedCount/${achievements.length}',
      );

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoadingAchievements = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading achievements: $e');
      if (mounted) {
        setState(() {
          _isLoadingAchievements = false;
        });
      }
    }
  }

  // Build the statistics card for sharing
  Widget _buildShareableStatisticsCard(UserData userData, String? profileImagePath) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1C1E),
            Color(0xFF000000),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B5CF6),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile picture and name
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: profileImagePath != null
                      ? buildImageFromPath(
                          profileImagePath,
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${userData.username}',
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Statistics cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${userData.dayStreak}',
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 36,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'DAY STREAK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${userData.focusHours}',
                        style: const TextStyle(
                          color: Color(0xFFB794F6),
                          fontSize: 36,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'FOCUS HOURS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
          const SizedBox(height: 24),
          // Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.remove_red_eye,
                      color: Color(0xFF8B5CF6),
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Focus App',
                      style: TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Show share dialog with screenshot
  Future<void> _shareStatistics() async {
    final userDataProvider = UserDataProvider.of(context);
    final userData = userDataProvider?.userData;
    if (userData == null) return;

    final profileImageProvider = ProfileImageProvider.of(context);
    final profileImagePath = profileImageProvider?.profileImagePath;

    try {
      // Capture the statistics card as image
      final imageBytes = await _screenshotController.captureFromWidget(
        _buildShareableStatisticsCard(userData, profileImagePath),
        pixelRatio: 3.0,
      );

      if (!mounted) return;

      // Show dialog with preview and share options
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF2C2C2E),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Share Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                // Image preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              // Save to temporary directory
                              final tempDir = await getTemporaryDirectory();
                              final filePath = '${tempDir.path}/focus_stats_${DateTime.now().millisecondsSinceEpoch}.png';
                              final file = File(filePath);
                              await file.writeAsBytes(imageBytes);

                              // Share the file
                              await Share.shareXFiles(
                                [XFile(filePath)],
                                text: 'Check out my Focus App statistics!',
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              debugPrint('Error sharing: $e');
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Share',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            try {
                              // Save to temporary directory first (no permissions needed)
                              final tempDir = await getTemporaryDirectory();
                              final fileName = 'focus_stats_${DateTime.now().millisecondsSinceEpoch}.png';
                              final filePath = path.join(tempDir.path, fileName);
                              final file = File(filePath);

                              debugPrint('💾 Saving to temp: $filePath');
                              await file.writeAsBytes(imageBytes);
                              debugPrint('✅ File saved to temp successfully');

                              // Use share functionality to save/export the file
                              // This lets the user choose where to save without needing permissions
                              final result = await Share.shareXFiles(
                                [XFile(filePath)],
                                text: 'Focus App Statistics',
                              );

                              debugPrint('📤 Share result: ${result.status}');

                              if (context.mounted) {
                                if (result.status == ShareResultStatus.success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Image saved successfully!'),
                                      backgroundColor: Color(0xFF30D158),
                                    ),
                                  );
                                  Navigator.pop(context);
                                } else if (result.status == ShareResultStatus.dismissed) {
                                  // User cancelled, just close the dialog
                                  Navigator.pop(context);
                                }
                              }
                            } catch (e) {
                              debugPrint('❌ Error saving: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save: ${e.toString()}'),
                                    backgroundColor: const Color(0xFFFF3B30),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.download,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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
      );
    } catch (e) {
      debugPrint('Error capturing screenshot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate statistics image'),
            backgroundColor: Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Reload counts
    await _loadCounts();

    // Reload user data from Firestore
    final userData = await UserDataService.instance.loadUserData(user.uid);
    if (userData != null && mounted) {
      final userDataProvider = UserDataProvider.of(context);
      userDataProvider?.updateUserData(userData);
    }
  }

  Future<void> _loadCounts() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final friends = await FriendsService.instance.getFriends(user.uid);
      final groups = await GroupsService.instance.getUserGroups(user.uid);

      if (mounted) {
        setState(() {
          _friendsCount = friends.length;
          _groupsCount = groups.length;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading counts: $e');
      if (mounted) {
        setState(() {
          _isLoadingCounts = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentOffset = _scrollController.offset;
      final scrollDelta = currentOffset - _lastScrollOffset;

      // Only trigger if scroll is significant (more than 5 pixels)
      if (scrollDelta.abs() > 5) {
        final isScrollingDown = scrollDelta > 0;

        if (_isScrollingDown != isScrollingDown) {
          setState(() {
            _isScrollingDown = isScrollingDown;
          });
          widget.onScrollDirectionChanged?.call(isScrollingDown);
        }
      }

      _lastScrollOffset = currentOffset;
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
    final userDataProvider = UserDataProvider.of(context);
    final userData = userDataProvider!.userData;

    final profileImageProvider = ProfileImageProvider.of(context);
    final profileImagePath = profileImageProvider?.profileImagePath;
    final bannerImagePath = profileImageProvider?.bannerImagePath;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshProfile,
            color: const Color(0xFF8B5CF6),
            backgroundColor: const Color(0xFF1C1C1E),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
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
                                child: bannerImagePath != null
                                    ? buildImageFromPath(
                                        bannerImagePath,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        width: double.infinity,
                                      )
                                    : Image.asset(
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
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.05),
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.15),
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.3),
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.5),
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.7),
                                      const Color(
                                        0xFF000000,
                                      ).withValues(alpha: 0.88),
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
                      // Profile picture centered overlaying the banner bottom
                      Positioned(
                        top: 140,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF000000),
                                    width: 4,
                                  ),
                                  color: const Color(0xFF2C2C2E),
                                ),
                                child: ClipOval(
                                  child: profileImagePath != null
                                      ? buildImageFromPath(
                                          profileImagePath,
                                          fit: BoxFit.cover,
                                          width: 120,
                                          height: 120,
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 60,
                                        ),
                                ),
                              ),
                              // Currently Focusing indicator
                              if (userData.currentlyFocusing) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF2C2C2E),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF30D158),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Currently Focusing',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Back button on banner (top left)
                      Positioned(
                        top: 50,
                        left: 16,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      // Share button on banner (top left, next to back button)
                      Positioned(
                        top: 50,
                        left: 68,
                        child: GestureDetector(
                          onTap: _shareStatistics,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // Profile name, counters, and username (centered)
                  Column(
                    children: [
                      // Full Name
                      Text(
                        userData.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Friends counter, username, and clubs counter row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Friends counter (hidden if 0)
                          if (!_isLoadingCounts && _friendsCount > 0) ...[
                            Text(
                              '$_friendsCount ${_friendsCount == 1 ? 'Friend' : 'Friends'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],

                          // Username
                          if (userData.username != null &&
                              userData.username!.isNotEmpty)
                            Text(
                              '@${userData.username}',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                          // Clubs counter (hidden if 0)
                          if (!_isLoadingCounts && _groupsCount > 0) ...[
                            const SizedBox(width: 16),
                            Text(
                              '$_groupsCount ${_groupsCount == 1 ? 'Club' : 'Clubs'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Horizontally scrollable achievements row
                  SizedBox(
                    height: 50,
                    child: _isLoadingAchievements
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _achievements.length,
                            addRepaintBoundaries: true,
                            cacheExtent: 500,
                            itemBuilder: (context, index) {
                              final achievement = _achievements[index];
                              return RepaintBoundary(
                                key: ValueKey(achievement.id),
                                child: GestureDetector(
                                  onTap: () {
                                    final user = firebase_auth
                                        .FirebaseAuth
                                        .instance
                                        .currentUser;
                                    if (user != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AchievementsScreen(
                                                userId: user.uid,
                                              ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: EdgeInsets.only(
                                      right: index < _achievements.length - 1
                                          ? 8
                                          : 0,
                                    ),
                                    width: 50,
                                    height: 50,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: achievement.isUnlocked
                                          ? Image.asset(
                                              achievement.iconUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    // Fallback to stone if badge image not found
                                                    return Image.asset(
                                                      'assets/images/achievements/stone.png',
                                                      fit: BoxFit.cover,
                                                    );
                                                  },
                                            )
                                          : ColorFiltered(
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    Colors.black45,
                                                    BlendMode.darken,
                                                  ),
                                              child: Opacity(
                                                opacity: 0.4,
                                                child: Image.asset(
                                                  'assets/images/achievements/stone.png',
                                                  fit: BoxFit.cover,
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

                  const SizedBox(height: 24),

                  // Rest of content with AppSafeArea padding
                  AppSafeArea(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 140,
                                child: AppCard(
                                  borderRadius: 16,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${userData.dayStreak}',
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
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 140,
                                child: AppCard(
                                  borderRadius: 16,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${userData.focusHours}',
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
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Period selection buttons and navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Period navigation
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _navigatePrevious,
                                  child: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _periodLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                            // Period buttons
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

                        // Activity Graph
                        _buildActivityGraph(userData),

                        const SizedBox(height: 24),

                        // Project Distribution Pie Chart
                        _buildProjectDistributionGraph(userData),

                        const SizedBox(height: 24),

                        // Time of Day Performance Graph
                        _buildTimeOfDayGraph(userData),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGraph(UserData userData) {
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
        final hours = userData.dailyActivityData[date] ?? 0.0;
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
        final hours = userData.dailyActivityData[date] ?? 0.0;
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
            monthTotal += userData.dailyActivityData[date] ?? 0.0;
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

    return SizedBox(
      height: 290, // Fixed height to prevent bouncing when switching periods
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label showing average or selected day
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
            const SizedBox(height: 16),
            // Bar chart with Y-axis (fixed height to prevent bouncing)
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bars container with horizontal lines
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
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

  Widget _buildTimeOfDayGraph(UserData userData) {
    // Filter focus sessions based on selected period and offset
    final now = DateTime.now();
    final daysBack = _currentOffset * _daysInPeriod;
    final startDate = now.subtract(Duration(days: daysBack + _daysInPeriod));
    final endDate = now.subtract(Duration(days: daysBack));

    // Filter sessions that fall within the selected period
    final filteredSessions = userData.focusSessions.where((session) {
      final sessionDate = DateTime(
        session.start.year,
        session.start.month,
        session.start.day,
      );
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      return (sessionDate.isAfter(start) ||
              sessionDate.isAtSameMomentAs(start)) &&
          (sessionDate.isBefore(end) || sessionDate.isAtSameMomentAs(end));
    }).toList();

    // Calculate time of day performance from filtered sessions
    final timePerformance = UserData.calculateTimeOfDayPerformance(
      filteredSessions,
    );

    // Convert to sorted list
    final sortedData = List.generate(24, (i) => timePerformance[i] ?? 0.0);

    // Y-axis max is always 60 minutes (maximum possible focus time in one hour)
    final yAxisMax = 60.0;

    // Find peak hour and its value
    double maxMinutes = 0;
    int peakHour = 10; // Default to 10:00
    for (int i = 0; i < sortedData.length; i++) {
      if (sortedData[i] > maxMinutes) {
        maxMinutes = sortedData[i];
        peakHour = i;
      }
    }

    // Determine what to display
    final String displayLabel;

    if (_selectedHourIndex != null && _selectedHourIndex! < sortedData.length) {
      // Show selected hour
      final hour = _selectedHourIndex!;
      final hourString = hour.toString().padLeft(2, '0');
      displayLabel = 'Focus time at $hourString:00';
    } else {
      // Show peak hour
      final hourString = peakHour.toString().padLeft(2, '0');
      displayLabel = 'Most focused at $hourString:00 every day in general';
    }

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main title
          const Text(
            'Most Focused Period of the Day',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            displayLabel,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          // Line chart with tap detection
          GestureDetector(
            onTapDown: (details) {
              _onTimeGraphTapped(details, sortedData);
            },
            child: RepaintBoundary(
              child: SizedBox(
                height: 150,
                child: CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: LineChartPainter(
                    data: sortedData,
                    maxValue: yAxisMax,
                    selectedHourIndex: _selectedHourIndex,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20), // Space for x-axis labels
        ],
      ),
    );
  }

  void _onTimeGraphTapped(TapDownDetails details, List<double> data) {
    // Calculate which hour was tapped
    final leftPadding = 8.0;
    final rightPadding = 18.0;
    final graphWidth = details.localPosition.dx - leftPadding;
    final totalWidth =
        MediaQuery.of(context).size.width -
        32 -
        24 -
        leftPadding -
        rightPadding; // screen - padding - card - graph padding

    if (graphWidth >= 0 && graphWidth <= totalWidth) {
      final hourIndex = ((graphWidth / totalWidth) * 24).floor().clamp(0, 23);
      setState(() {
        if (_selectedHourIndex == hourIndex) {
          _selectedHourIndex = null; // Deselect if tapping same hour
        } else {
          _selectedHourIndex = hourIndex;
        }
      });
    }
  }

  Widget _buildProjectDistributionGraph(UserData userData) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, String>>(
      future: _loadProjectNames(user.uid),
      builder: (context, snapshot) {
        final projectNames = snapshot.data ?? {};
        return _buildProjectDistributionContent(userData, projectNames);
      },
    );
  }

  Future<Map<String, String>> _loadProjectNames(String userId) async {
    try {
      final projects = await ProjectService.instance.loadAllProjects(userId);
      final Map<String, String> projectNames = {};
      for (final project in projects) {
        projectNames[project.id] = project.name;
      }
      return projectNames;
    } catch (e) {
      debugPrint('Error loading project names: $e');
      return {};
    }
  }

  String _getProjectDisplayName(
    String projectId,
    Map<String, String> projectNames,
  ) {
    // First check if we have the actual project name
    if (projectNames.containsKey(projectId)) {
      return projectNames[projectId]!;
    }

    // Handle "unset" special case
    if (projectId == 'unset') {
      return 'Unset';
    }

    // Format generated project IDs like "project_1" to "Project 1"
    final match = RegExp(r'^project_(\d+)$').firstMatch(projectId);
    if (match != null) {
      return 'Project ${match.group(1)}';
    }

    // Format generated subproject IDs like "project_1_sub_0" to "Project 1 - Subtask 1"
    final subMatch = RegExp(r'^project_(\d+)_sub_(\d+)$').firstMatch(projectId);
    if (subMatch != null) {
      final projectNum = int.parse(subMatch.group(1)!);
      final subNum =
          int.parse(subMatch.group(2)!) + 1; // Add 1 for 1-based indexing
      return 'Project $projectNum - Subtask $subNum';
    }

    // Default: return the ID as-is
    return projectId;
  }

  Widget _buildProjectDistributionContent(
    UserData userData,
    Map<String, String> projectNames,
  ) {
    // Calculate total minutes per project from all focus sessions
    final Map<String, double> projectMinutes = {};

    for (final session in userData.focusSessions) {
      final projectId = session.projectId;
      final minutes = session.duration.inMinutes.toDouble();
      projectMinutes[projectId] = (projectMinutes[projectId] ?? 0.0) + minutes;
    }

    // Convert to hours and sort by value
    final projectHours = projectMinutes.map(
      (key, value) => MapEntry(key, value / 60.0),
    );

    // Sort by hours (descending)
    final sortedEntries = projectHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // If no data, show empty state
    if (sortedEntries.isEmpty || sortedEntries.every((e) => e.value == 0)) {
      return AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project Distribution',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No focus sessions recorded yet',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 12,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            const Center(
              child: Icon(
                Icons.pie_chart_outline,
                color: Color(0xFF8E8E93),
                size: 64,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    // Calculate total hours
    final totalHours = sortedEntries.fold(
      0.0,
      (total, entry) => total + entry.value,
    );

    // Predefined colors for projects (matching the app's color scheme)
    final List<Color> projectColors = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFFF9500), // Orange
      const Color(0xFF34C759), // Green
      const Color(0xFFFF3B30), // Red
      const Color(0xFFFFCC00), // Yellow
      const Color(0xFFFF2D55), // Pink
      const Color(0xFF5856D6), // Indigo
    ];

    // Build data for pie chart
    final List<PieChartData> chartData = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final percentage = (entry.value / totalHours) * 100;
      chartData.add(
        PieChartData(
          projectId: entry.key,
          hours: entry.value,
          percentage: percentage,
          color: projectColors[i % projectColors.length],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${totalHours.toStringAsFixed(1)} hours',
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),
          // Pie chart
          RepaintBoundary(
            child: SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: PieChartPainter(data: chartData),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend
          ...chartData.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getProjectDisplayName(item.projectId, projectNames),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${item.hours.toStringAsFixed(1)}h (${item.percentage.toStringAsFixed(1)}%)',
                    style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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

// Custom painter for line chart
class LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final int? selectedHourIndex;

  LineChartPainter({
    required this.data,
    required this.maxValue,
    this.selectedHourIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue == 0) return;

    final paint = Paint()
      ..color = const Color.fromARGB(255, 190, 190, 190)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          const Color.fromARGB(255, 150, 150, 150).withValues(alpha: 0.8),
          const Color.fromARGB(255, 80, 80, 80).withValues(alpha: 0.3),
          const Color.fromARGB(255, 50, 50, 50).withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0], // Color stops
      )
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFF3A3A3C).withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Reserve space on the left and right for padding
    final leftPadding = 8.0;
    final rightPadding = 18.0;
    final graphWidth = size.width - leftPadding - rightPadding;

    // Draw horizontal grid lines (4 lines: 0, 20, 40, 60)
    for (int i = 0; i <= 3; i++) {
      final y = (size.height / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + graphWidth, y),
        gridPaint,
      );
    }

    // Calculate points
    final points = <Offset>[];
    final spacing = graphWidth / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = leftPadding + (i * spacing);
      final normalizedValue = data[i] / maxValue;
      final y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }

    // Draw filled area under the line
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points.first.dx, size.height);
      path.lineTo(points.first.dx, points.first.dy);

      for (final point in points) {
        path.lineTo(point.dx, point.dy);
      }

      path.lineTo(points.last.dx, size.height);
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    // Draw the line
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(linePath, paint);
    }

    // Draw hour labels on X-axis (specific hours: 0, 6, 12, 18, 23)
    final xAxisHours = [0, 6, 12, 18, 23];
    for (int hour in xAxisHours) {
      final x = leftPadding + (hour * spacing);
      final hourString = hour.toString().padLeft(2, '0');
      textPainter.text = TextSpan(
        text: '$hourString:00',
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 10),
      );
    }

    // Draw Y-axis labels (minutes: 60, 40, 20, 0) on the right side
    final yLabels = ['60', '40', '20', '0'];
    for (int i = 0; i <= 3; i++) {
      final y = (size.height / 3) * i;
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 9,
          fontFamily: 'Inter',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width, y - textPainter.height / 2),
      );
    }

    // Draw vertical indicator line for selected hour
    if (selectedHourIndex != null && selectedHourIndex! < data.length) {
      final x = leftPadding + (selectedHourIndex! * spacing);

      // Draw dashed vertical line
      final indicatorPaint = Paint()
        ..color = const Color(0xFF8E8E93).withValues(alpha: 0.5)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      // Draw dashed line from top to bottom
      double dashHeight = 4;
      double dashSpace = 4;
      double startY = 0;

      while (startY < size.height) {
        canvas.drawLine(
          Offset(x, startY),
          Offset(x, startY + dashHeight),
          indicatorPaint,
        );
        startY += dashHeight + dashSpace;
      }

      // Draw black circle at the data point
      final normalizedValue = data[selectedHourIndex!] / maxValue;
      final y = size.height - (normalizedValue * size.height);

      // Draw outer black circle
      final blackCirclePaint = Paint()
        ..color = Color.fromARGB(255, 102, 102, 105)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 4.5, blackCirclePaint);

      // Draw inner white circle
      final whiteCirclePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 2.5, whiteCirclePaint);
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedHourIndex != selectedHourIndex;
  }
}

// Pie Chart Data Model
class PieChartData {
  final String projectId;
  final double hours;
  final double percentage;
  final Color color;

  PieChartData({
    required this.projectId,
    required this.hours,
    required this.percentage,
    required this.color,
  });
}

// Custom painter for pie chart
class PieChartPainter extends CustomPainter {
  final List<PieChartData> data;

  PieChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 * 0.8; // 80% of half height

    double startAngle = -math.pi / 2; // Start from top

    for (final segment in data) {
      final sweepAngle = (segment.percentage / 100) * 2 * math.pi;

      // Draw pie segment
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw border between segments
      final borderPaint = Paint()
        ..color = const Color(0xFF000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

// Settings Screen
// Account Settings Screen
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _logout() async {
    try {
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF8E8E93)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
      );

      if (shouldLogout == true && mounted) {
        // Sign out from Firebase
        await FirebaseService.instance.auth.signOut();

        if (mounted) {
          // Pop all screens and return to root (auth screen will show automatically)
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Copy image from temporary cache to permanent app storage
  Future<String> _copyImageToPermanentStorage(
    String sourcePath,
    String fileName,
  ) async {
    try {
      // Get app's permanent document directory
      final Directory appDir = await getApplicationDocumentsDirectory();

      // Create 'profile_images' subdirectory if it doesn't exist
      final Directory profileImagesDir = Directory(
        '${appDir.path}/profile_images',
      );
      if (!await profileImagesDir.exists()) {
        await profileImagesDir.create(recursive: true);
      }

      // Create destination path with unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = path.extension(sourcePath);
      final String destinationPath =
          '${profileImagesDir.path}/${fileName}_$timestamp$extension';

      // Copy the file
      final File sourceFile = File(sourcePath);
      await sourceFile.copy(destinationPath);

      debugPrint('✅ Image copied to permanent storage: $destinationPath');
      return destinationPath;
    } catch (e) {
      debugPrint('❌ Error copying image to permanent storage: $e');
      rethrow;
    }
  }

  Future<void> _showChangeUsernameDialog() async {
    final userDataProvider = UserDataProvider.of(context);
    if (userDataProvider == null) return;

    final currentName = userDataProvider.userData.fullName;
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Change Username',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: Color(0xFF8E8E93)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8E8E93)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF8B5CF6)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
          TextButton(
            onPressed: () {
              final trimmedName = controller.text.trim();
              if (trimmedName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Username cannot be empty'),
                    backgroundColor: Color(0xFFDC2626),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              Navigator.pop(context, trimmedName);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Color(0xFF8B5CF6)),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName != currentName && mounted) {
      // Update the user data with new full name
      final updatedUserData = userDataProvider.userData.copyWith(
        fullName: newName,
        updatedAt: DateTime.now(),
      );
      userDataProvider.updateUserData(updatedUserData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username updated successfully'),
          backgroundColor: Color(0xFF00C853),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final userDataProvider = UserDataProvider.of(context);
    if (userDataProvider == null) return;

    final currentUser = FirebaseService.instance.auth.currentUser;
    if (currentUser == null) return;

    final currentEmail = currentUser.email ?? '';
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Update Email Address',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current email: $currentEmail',
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New Email',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8E8E93)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFF59E0B)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Current Password (for verification)',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8E8E93)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFF59E0B)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8E8E93)),
            ),
          ),
          TextButton(
            onPressed: () {
              final newEmail = emailController.text.trim();
              final password = passwordController.text;

              if (newEmail.isEmpty || !newEmail.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid email address'),
                    backgroundColor: Color(0xFFDC2626),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password is required for verification'),
                    backgroundColor: Color(0xFFDC2626),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }

              Navigator.pop(context, {'email': newEmail, 'password': password});
            },
            child: const Text(
              'Update',
              style: TextStyle(color: Color(0xFFF59E0B)),
            ),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final newEmail = result['email']!;
      final password = result['password']!;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );

      try {
        // Re-authenticate user with current password
        final credential = firebase_auth.EmailAuthProvider.credential(
          email: currentEmail,
          password: password,
        );
        await currentUser.reauthenticateWithCredential(credential);

        // TODO: FOR RELEASE - Switch to email verification flow
        // For production, use verifyBeforeUpdateEmail() which:
        // 1. Sends verification email to new address
        // 2. Only updates Auth after user clicks verification link
        // 3. Add listener to sync Firestore when Auth email changes
        // 4. Handle edge cases (user doesn't verify, expired links, etc.)

        // DEVELOPMENT/DEBUG SOLUTION:
        // updateEmail() has been removed from Firebase Auth SDK
        // For debugging with emulators, we update Firestore only
        // Auth email remains unchanged (this is OK for local testing)
        // User can still login with their original email

        // Note: In production, use verifyBeforeUpdateEmail() which requires
        // the user to verify the new email before it's updated

        debugPrint('DEBUG MODE: Updating email in Firestore only');
        debugPrint('Auth email will remain: $currentEmail');
        debugPrint('Firestore email will be: $newEmail');

        // Update email in Firestore and local state only
        // updateUserData automatically saves to Firestore
        final updatedUserData = userDataProvider.userData.copyWith(
          email: newEmail,
          updatedAt: DateTime.now(),
        );
        userDataProvider.updateUserData(updatedUserData);

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Email updated to $newEmail in profile (Debug mode: Login still uses $currentEmail)',
              ),
              backgroundColor: const Color(0xFF00C853),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog
        if (mounted) Navigator.pop(context);

        // Show error message
        String errorMessage = 'Failed to update email';
        if (e.toString().contains('wrong-password')) {
          errorMessage = 'Incorrect password';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'Email is already in use';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email address';
        } else if (e.toString().contains('requires-recent-login')) {
          errorMessage = 'Please log out and log back in before changing email';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 3),
            ),
          );
        }

        debugPrint('Error updating email: $e');
      }
    }
  }

  Future<void> _pickProfilePicture() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show bottom sheet to choose between camera and gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF06B6D4),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF06B6D4),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          // Copy image to permanent storage
          final String permanentPath = await _copyImageToPermanentStorage(
            image.path,
            'profile',
          );

          if (!mounted) return;

          // Save the profile picture path to ProfileImageProvider (for immediate display)
          final profileImageProvider = ProfileImageProvider.of(context);
          profileImageProvider?.updateProfileImage(permanentPath);

          // Save the permanent profile picture URL to UserData (for persistence)
          final userDataProvider = UserDataProvider.of(context);
          if (userDataProvider != null) {
            debugPrint(
              '📸 Saving profile picture permanent path: $permanentPath',
            );
            // Attempt to upload to Firebase Storage (emulator in debug)
            String? uploadedUrl;
            final currentUser = FirebaseService.instance.auth.currentUser;
            if (currentUser != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading profile picture...')),
              );
              try {
                uploadedUrl = await UserDataService.instance.uploadAvatarFile(
                  currentUser.uid,
                  File(permanentPath),
                );
              } catch (e) {
                debugPrint('📸 Upload failed: $e');
              }
            }

            final updatedUserData = userDataProvider.userData.copyWith(
              avatarUrl: uploadedUrl ?? permanentPath,
              updatedAt: DateTime.now(),
            );
            debugPrint(
              '📸 Updated avatarUrl in UserData: ${updatedUserData.avatarUrl}',
            );
            userDataProvider.updateUserData(updatedUserData);

            if (uploadedUrl != null && mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Profile picture uploaded successfully'),
                ),
              );
            } else if (mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Profile saved locally (upload skipped or failed)',
                  ),
                ),
              );
            }
          }

          messenger.showSnackBar(
            SnackBar(
              content: Text('Profile picture updated: ${image.name}'),
              backgroundColor: const Color(0xFF00C853),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _pickBannerPicture() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Show bottom sheet to choose between camera and gallery
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Banner Picture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFFEC4899),
                  ),
                  title: const Text(
                    'Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFFEC4899),
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      );

      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );

        if (image != null && mounted) {
          // Copy image to permanent storage
          final String permanentPath = await _copyImageToPermanentStorage(
            image.path,
            'banner',
          );

          if (!mounted) return;

          // Save the banner picture path to ProfileImageProvider (for immediate display)
          final profileImageProvider = ProfileImageProvider.of(context);
          profileImageProvider?.updateBannerImage(permanentPath);

          // Save the permanent banner picture URL to UserData (for persistence)
          final userDataProvider = UserDataProvider.of(context);
          if (userDataProvider != null) {
            debugPrint(
              '🖼️ Saving banner picture permanent path: $permanentPath',
            );
            // Attempt to upload to Firebase Storage (emulator in debug)
            String? uploadedUrl;
            final currentUser = FirebaseService.instance.auth.currentUser;
            if (currentUser != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading banner picture...')),
              );
              try {
                uploadedUrl = await UserDataService.instance.uploadBannerFile(
                  currentUser.uid,
                  File(permanentPath),
                );
              } catch (e) {
                debugPrint('🖼️ Upload failed: $e');
              }
            }

            final updatedUserData = userDataProvider.userData.copyWith(
              bannerImageUrl: uploadedUrl ?? permanentPath,
              updatedAt: DateTime.now(),
            );
            debugPrint(
              '🖼️ Updated bannerImageUrl in UserData: ${updatedUserData.bannerImageUrl}',
            );
            userDataProvider.updateUserData(updatedUserData);

            if (uploadedUrl != null && mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Banner picture uploaded successfully'),
                ),
              );
            } else if (mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Banner saved locally (upload skipped or failed)',
                  ),
                ),
              );
            }
          }

          messenger.showSnackBar(
            SnackBar(
              content: Text('Banner picture updated: ${image.name}'),
              backgroundColor: const Color(0xFF00C853),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
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
                  const SizedBox(height: 4),
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
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Account Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: AppSafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Profile Picture
              _buildSettingsItem(
                context: context,
                title: 'Profile Picture',
                subtitle: 'Change your profile picture',
                icon: Icons.account_circle,
                iconColor: const Color(0xFF06B6D4),
                onTap: _pickProfilePicture,
              ),

              // Banner Picture
              _buildSettingsItem(
                context: context,
                title: 'Banner Picture',
                subtitle: 'Change your profile banner',
                icon: Icons.wallpaper,
                iconColor: const Color(0xFFEC4899),
                onTap: _pickBannerPicture,
              ),

              const SizedBox(height: 24),

              const Text(
                'Account Information',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Username
              _buildSettingsItem(
                context: context,
                title: 'Username',
                subtitle: 'Change your username',
                icon: Icons.person,
                iconColor: const Color(0xFF8B5CF6),
                onTap: _showChangeUsernameDialog,
              ),

              // Email
              _buildSettingsItem(
                context: context,
                title: 'Email',
                subtitle: 'Update your email address',
                icon: Icons.email,
                iconColor: const Color(0xFFF59E0B),
                onTap: _showChangeEmailDialog,
              ),

              const SizedBox(height: 24),

              const Text(
                'Session',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Logout
              _buildSettingsItem(
                context: context,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                icon: Icons.logout,
                iconColor: const Color(0xFFDC2626),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Notification Center Screen
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
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
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Please sign in to view notifications',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

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
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.instance.markAllAsRead(userId);
            },
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.streamNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading notifications',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationTile(context, notification, userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotification notification,
    String userId,
  ) {
    IconData icon;
    Color iconColor;
    String title;

    switch (notification.type) {
      case 'nudge':
        icon = Icons.notifications_active;
        iconColor = const Color(0xFFFF9500);
        title = '${notification.fromUserName} nudged you!';
        break;
      case 'friend_request':
        icon = Icons.person_add;
        iconColor = const Color(0xFF007AFF);
        title = '${notification.fromUserName} sent you a friend request';
        break;
      default:
        icon = Icons.info;
        iconColor = const Color(0xFF8E8E93);
        title = notification.fromUserName;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFFF3B30),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        NotificationService.instance.deleteNotification(
          userId,
          notification.id,
        );
      },
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            await NotificationService.instance.markAsRead(
              userId,
              notification.id,
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : const Color(0xFF1C1C1E).withValues(alpha: 0.5),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontFamily: 'Inter',
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    if (notification.message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message!,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF007AFF),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }
}

class SettingsScreen extends StatefulWidget {
  final bool showBackButton;
  final Function(bool)? onScrollDirectionChanged;

  const SettingsScreen({
    super.key,
    this.showBackButton = false,
    this.onScrollDirectionChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isGenerating = false;
  final ScrollController _scrollController = ScrollController();
  double _lastScrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onScrollDirectionChanged == null) return;

    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    if (delta.abs() > 5) {
      // Threshold to prevent jitter
      widget.onScrollDirectionChanged!(delta > 0); // true if scrolling down
      _lastScrollOffset = currentOffset;
    }
  }

  UserData _generateRandomDataWithProjects(
    UserData currentUserData,
    List<String> projectIds,
    List<Project> allProjects,
  ) {
    final random = math.Random();
    final now = DateTime.now();

    // Generate random statistics
    final dayStreak = random.nextInt(365) + 1;
    final focusHours = random.nextInt(1950) + 50;
    final rankPercent = random.nextInt(99) + 1;
    final rankPercentage = 'Top $rankPercent%';

    // Generate activity data
    final Map<DateTime, double> activityData = {};
    for (int i = 0; i < 365; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      activityData[date] = random.nextDouble() * 8;
    }

    // Build map of project IDs to their subprojects
    final Map<String, List<String>> subprojectsByProject = {};
    for (final project in allProjects) {
      if (project.subprojects.isNotEmpty) {
        subprojectsByProject[project.id] = project.subprojects
            .map((s) => s.id)
            .toList();
      }
    }

    // Generate focus sessions with real project IDs
    final List<FocusSession> sessions = [];
    for (int day = 0; day < 60; day++) {
      final date = now.subtract(Duration(days: day));
      final sessionsPerDay = 1 + random.nextInt(6);

      for (int s = 0; s < sessionsPerDay; s++) {
        final hour = 6 + random.nextInt(17);
        final minute = random.nextInt(60);
        final sessionStart = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );
        final durationMinutes = 10 + random.nextInt(111);

        // Randomly assign a project from actual projects
        final projectId = projectIds[random.nextInt(projectIds.length)];

        // If project has subprojects, maybe assign one (50% chance)
        String? subprojectId;
        if (subprojectsByProject.containsKey(projectId) && random.nextBool()) {
          final subprojects = subprojectsByProject[projectId]!;
          subprojectId = subprojects[random.nextInt(subprojects.length)];
        }

        sessions.add(
          FocusSession(
            start: sessionStart,
            duration: Duration(minutes: durationMinutes),
            projectId: projectId,
            subprojectId: subprojectId,
          ),
        );
      }
    }

    // Calculate time of day performance
    final timePerformance = UserData.calculateTimeOfDayPerformance(sessions);

    // Return copy with only statistics replaced, keeping all profile data
    return currentUserData.copyWith(
      dayStreak: dayStreak,
      focusHours: focusHours,
      rankPercentage: rankPercentage,
      currentBadge: 'Radiant',
      currentBadgeProgress: '${dayStreak % 30}/30 days',
      nextBadge: 'Dutiful',
      nextBadgeProgress: '$focusHours/500 days',
      dailyActivityData: activityData,
      focusSessions: sessions,
      timeOfDayPerformance: timePerformance,
      isGeneratedData: true,
      generatedAt: now,
      updatedAt: now,
      currentlyFocusing: false,
    );
  }

  Future<void> _generateRandomData() async {
    final statisticsProvider = UserDataProvider.of(context);
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    if (statisticsProvider == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Could not access user data'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // First, delete all existing projects (except "unset")
      debugPrint('🗑️ Clearing existing projects...');
      final existingProjects = await ProjectService.instance.loadAllProjects(
        user.uid,
      );
      for (final project in existingProjects) {
        if (project.id != 'unset') {
          try {
            await ProjectService.instance.deleteProject(user.uid, project.id);
          } catch (e) {
            debugPrint('⚠️ Failed to delete project ${project.id}: $e');
          }
        }
      }
      debugPrint(
        '✅ Cleared ${existingProjects.where((p) => p.id != "unset").length} projects',
      );

      // Generate random project names, colors, and emojis
      final projectNames = [
        'Work',
        'Personal',
        'Study',
        'Fitness',
        'Hobby',
        'Reading',
      ];
      final projectColors = [
        '#FF5733',
        '#33FF57',
        '#3357FF',
        '#FF33F5',
        '#F5FF33',
        '#33F5FF',
      ];
      final projectEmojis = ['💼', '🏠', '📚', '💪', '🎨', '📖'];

      final random = math.Random();
      final projectCount = 3 + random.nextInt(3); // 3-5 projects

      // Create random projects in Firestore
      for (int i = 1; i <= projectCount; i++) {
        final projectName = projectNames[i % projectNames.length];
        final projectColor = projectColors[i % projectColors.length];
        final projectEmoji = projectEmojis[i % projectEmojis.length];

        // Create project using ProjectService (it handles Project.create internally)
        await ProjectService.instance.createProject(
          user.uid,
          name: projectName,
          color: projectColor,
          emoji: projectEmoji,
        );

        // We need to get the project ID that was just created
        // Load all projects and get the latest one
        final projects = await ProjectService.instance.loadAllProjects(
          user.uid,
        );
        if (projects.isEmpty) continue;

        final project = projects.last;

        // Maybe add subprojects (50% chance)
        if (random.nextBool()) {
          final subprojectCount = 1 + random.nextInt(3); // 1-3 subprojects
          for (int j = 0; j < subprojectCount; j++) {
            await ProjectService.instance.addSubproject(
              user.uid,
              project.id,
              'Task ${j + 1}',
            );
          }
        }
      }

      // Load all projects to get the real project IDs
      final allProjects = await ProjectService.instance.loadAllProjects(
        user.uid,
      );
      final projectIds = allProjects.map((p) => p.id).toList();

      // Include 'unset' as well
      if (!projectIds.contains('unset')) {
        projectIds.insert(0, 'unset');
      }

      // Simulate data generation with delay
      await Future.delayed(const Duration(seconds: 1));

      // Generate random statistics using actual project IDs
      final currentUserData = statisticsProvider.userData;
      final newUserData = _generateRandomDataWithProjects(
        currentUserData,
        projectIds,
        allProjects,
      );

      // Update the global state
      statisticsProvider.updateUserData(newUserData);

      setState(() {
        _isGenerating = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Random data generated!\n'
              'Day Streak: ${newUserData.dayStreak}, '
              'Focus Hours: ${newUserData.focusHours}, '
              'Projects: $projectCount',
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating data: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
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
    final userDataProvider = UserDataProvider.of(context);
    final userData =
        userDataProvider?.userData ??
        UserData.newUser(email: 'guest@example.com', fullName: 'User');

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
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
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountSettingsScreen(),
                    ),
                  );
                },
              ),

              // Dev test tile removed (use the normal pickers to test uploads)

              // Notifications
              _buildSettingsItem(
                title: 'Notifications',
                subtitle: 'Configure notification preferences',
                icon: Icons.notifications_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsSettingsScreen(),
                    ),
                  );
                },
              ),

              // Privacy
              _buildSettingsItem(
                title: 'Privacy',
                subtitle: 'Privacy and data settings',
                icon: Icons.lock_outline,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyScreen(),
                    ),
                  );
                },
              ),

              // About
              _buildSettingsItem(
                title: 'About',
                subtitle: 'Version info and licenses',
                icon: Icons.info_outline,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutScreen(),
                    ),
                  );
                },
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
              if (userData.isGeneratedData && userData.generatedAt != null)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  border: Border.all(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.3),
                    width: 1,
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
                              userData.generatedAt ?? DateTime.now(),
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
                      _buildDataRow('Day Streak', '${userData.dayStreak} days'),
                      _buildDataRow(
                        'Focus Hours',
                        '${userData.focusHours} hours',
                      ),
                      _buildDataRow('Rank', userData.rankPercentage),
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

              // Create Test Users Button
              _buildSettingsItem(
                title: 'Create Test Users',
                subtitle: 'Generate test user accounts for debugging',
                icon: Icons.group_add,
                iconColor: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TestUsersScreen(),
                    ),
                  );
                },
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
              if (userData.isGeneratedData)
                _buildSettingsItem(
                  title: 'Clear Test Data',
                  subtitle: 'Restore original user data',
                  icon: Icons.restore,
                  iconColor: const Color(0xFFDC2626),
                  onTap: _isGenerating
                      ? () {}
                      : () {
                          // Reset statistics while preserving profile data
                          final clearedData = userData.withDefaultStatistics();
                          userDataProvider?.updateUserData(clearedData);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Test data cleared. Statistics reset to default.',
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

// Privacy Settings Screen
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // Privacy settings state
  bool _profileVisibility = true;
  bool _showOnlineStatus = true;
  bool _allowFriendRequests = true;
  bool _showFocusActivity = true;
  bool _showStatistics = true;
  bool _allowGroupInvites = true;

  @override
  Widget build(BuildContext context) {
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
          'Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: AppSafeArea(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Privacy Section
              const Text(
                'Profile Privacy',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleItem(
                title: 'Public Profile',
                subtitle: 'Allow others to view your profile',
                value: _profileVisibility,
                onChanged: (value) {
                  setState(() {
                    _profileVisibility = value;
                  });
                },
                icon: Icons.public,
              ),

              _buildToggleItem(
                title: 'Show Online Status',
                subtitle: 'Display when you\'re currently focusing',
                value: _showOnlineStatus,
                onChanged: (value) {
                  setState(() {
                    _showOnlineStatus = value;
                  });
                },
                icon: Icons.circle,
              ),

              _buildToggleItem(
                title: 'Show Statistics',
                subtitle: 'Display focus hours and streaks on profile',
                value: _showStatistics,
                onChanged: (value) {
                  setState(() {
                    _showStatistics = value;
                  });
                },
                icon: Icons.bar_chart,
              ),

              _buildToggleItem(
                title: 'Show Focus Activity',
                subtitle: 'Display your current project when focusing',
                value: _showFocusActivity,
                onChanged: (value) {
                  setState(() {
                    _showFocusActivity = value;
                  });
                },
                icon: Icons.remove_red_eye,
              ),

              const SizedBox(height: 24),

              // Social Privacy Section
              const Text(
                'Social Privacy',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleItem(
                title: 'Allow Friend Requests',
                subtitle: 'Let others send you friend requests',
                value: _allowFriendRequests,
                onChanged: (value) {
                  setState(() {
                    _allowFriendRequests = value;
                  });
                },
                icon: Icons.person_add_outlined,
              ),

              _buildToggleItem(
                title: 'Allow Group Invites',
                subtitle: 'Let friends invite you to groups',
                value: _allowGroupInvites,
                onChanged: (value) {
                  setState(() {
                    _allowGroupInvites = value;
                  });
                },
                icon: Icons.group_outlined,
              ),

              const SizedBox(height: 24),

              // Data & Permissions Section
              const Text(
                'Data & Permissions',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildActionItem(
                title: 'Storage Permission',
                subtitle: 'Manage app storage access',
                icon: Icons.storage_outlined,
                onTap: () {
                  // Open app settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open device settings to manage permissions'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              _buildActionItem(
                title: 'Notifications Permission',
                subtitle: 'Manage notification access',
                icon: Icons.notifications_outlined,
                onTap: () {
                  // Open notification settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Open device settings to manage permissions'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Account Actions Section
              const Text(
                'Account Actions',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildActionItem(
                title: 'Download My Data',
                subtitle: 'Export all your account data',
                icon: Icons.download_outlined,
                onTap: () {
                  _showDownloadDataDialog();
                },
              ),

              _buildActionItem(
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                icon: Icons.delete_outline,
                iconColor: const Color(0xFFFF3B30),
                onTap: () {
                  _showDeleteAccountDialog();
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF8B5CF6),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF8B5CF6),
            activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
            inactiveThumbColor: const Color(0xFF8E8E93),
            inactiveTrackColor: const Color(0xFF3A3A3C),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? const Color(0xFF8B5CF6);
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
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
            Icon(Icons.chevron_right, color: const Color(0xFF8E8E93), size: 20),
          ],
        ),
      ),
    );
  }

  void _showDownloadDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Download Your Data',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'We\'ll prepare a file with all your account data and send it to your email. This may take a few minutes.',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data export started. Check your email soon.'),
                  backgroundColor: Color(0xFF30D158),
                ),
              );
            },
            child: const Text(
              'Download',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Delete Account?',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'This action cannot be undone. All your data, including focus sessions, achievements, and friends will be permanently deleted.',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion not implemented yet'),
                  backgroundColor: Color(0xFFFF3B30),
                ),
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF3B30),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Notifications Settings Screen
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  // Notification settings state
  bool _notificationsEnabled = true;
  bool _friendRequestNotifications = true;
  bool _groupInviteNotifications = true;
  bool _achievementNotifications = true;
  bool _streakReminderNotifications = true;
  bool _focusStartNotifications = false;
  bool _focusEndNotifications = true;
  bool _dailySummaryNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _badgeEnabled = true;

  @override
  Widget build(BuildContext context) {
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
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: AppSafeArea(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Toggle
              _buildToggleItem(
                title: 'Enable Notifications',
                subtitle: 'Receive all app notifications',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
                icon: Icons.notifications_active,
                isMain: true,
              ),

              const SizedBox(height: 24),

              // Social Notifications Section
              const Text(
                'Social Notifications',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleItem(
                title: 'Friend Requests',
                subtitle: 'When someone sends you a friend request',
                value: _friendRequestNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _friendRequestNotifications = value;
                  });
                } : null,
                icon: Icons.person_add_outlined,
              ),

              _buildToggleItem(
                title: 'Group Invites',
                subtitle: 'When you\'re invited to a group',
                value: _groupInviteNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _groupInviteNotifications = value;
                  });
                } : null,
                icon: Icons.group_outlined,
              ),

              const SizedBox(height: 24),

              // Activity Notifications Section
              const Text(
                'Activity Notifications',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleItem(
                title: 'Focus Started',
                subtitle: 'When you start a focus session',
                value: _focusStartNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _focusStartNotifications = value;
                  });
                } : null,
                icon: Icons.play_circle_outline,
              ),

              _buildToggleItem(
                title: 'Focus Completed',
                subtitle: 'When you complete a focus session',
                value: _focusEndNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _focusEndNotifications = value;
                  });
                } : null,
                icon: Icons.check_circle_outline,
              ),

              _buildToggleItem(
                title: 'Achievements Unlocked',
                subtitle: 'When you unlock a new achievement',
                value: _achievementNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _achievementNotifications = value;
                  });
                } : null,
                icon: Icons.emoji_events_outlined,
              ),

              _buildToggleItem(
                title: 'Streak Reminders',
                subtitle: 'Daily reminder to maintain your streak',
                value: _streakReminderNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _streakReminderNotifications = value;
                  });
                } : null,
                icon: Icons.local_fire_department_outlined,
              ),

              _buildToggleItem(
                title: 'Daily Summary',
                subtitle: 'End of day focus summary',
                value: _dailySummaryNotifications,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _dailySummaryNotifications = value;
                  });
                } : null,
                icon: Icons.summarize_outlined,
              ),

              const SizedBox(height: 24),

              // Notification Behavior Section
              const Text(
                'Notification Behavior',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildToggleItem(
                title: 'Sound',
                subtitle: 'Play sound for notifications',
                value: _soundEnabled,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _soundEnabled = value;
                  });
                } : null,
                icon: Icons.volume_up_outlined,
              ),

              _buildToggleItem(
                title: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: _vibrationEnabled,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _vibrationEnabled = value;
                  });
                } : null,
                icon: Icons.vibration_outlined,
              ),

              _buildToggleItem(
                title: 'Badge',
                subtitle: 'Show notification badges on app icon',
                value: _badgeEnabled,
                onChanged: _notificationsEnabled ? (value) {
                  setState(() {
                    _badgeEnabled = value;
                  });
                } : null,
                icon: Icons.lens_outlined,
              ),

              const SizedBox(height: 24),

              // Quiet Hours Section
              const Text(
                'Quiet Hours',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              _buildActionItem(
                title: 'Schedule Quiet Hours',
                subtitle: 'Set times to mute notifications',
                icon: Icons.nightlight_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Quiet hours coming soon!'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
    bool isMain = false,
  }) {
    final isDisabled = onChanged == null;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isMain
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                : const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDisabled
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                : const Color(0xFF8B5CF6),
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
                  style: TextStyle(
                    color: isDisabled
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.white,
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDisabled
                      ? const Color(0xFF8E8E93).withValues(alpha: 0.5)
                      : const Color(0xFF8E8E93),
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF8B5CF6),
            activeTrackColor: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
            inactiveThumbColor: const Color(0xFF8E8E93),
            inactiveTrackColor: const Color(0xFF3A3A3C),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8B5CF6),
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
}

// About Screen
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: AppSafeArea(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // App Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B5CF6),
                      Color(0xFF7C3AED),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.remove_red_eye,
                  color: Colors.white,
                  size: 50,
                ),
              ),

              const SizedBox(height: 20),

              // App Name
              const Text(
                'Focus App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              // Version Info
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Version 1.0.0 (Build 1)',
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              const Text(
                'Stay focused, achieve more',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 15,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // App Information Section
              _buildSectionTitle('App Information'),
              const SizedBox(height: 12),

              _buildInfoItem(
                title: 'What\'s New',
                subtitle: 'See the latest features and updates',
                icon: Icons.new_releases_outlined,
                onTap: () {
                  // Show changelog dialog
                  _showChangelogDialog(context);
                },
              ),

              _buildInfoItem(
                title: 'Rate Us',
                subtitle: 'Share your feedback on the App Store',
                icon: Icons.star_outline,
                onTap: () {
                  // Open app store
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening App Store...'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Legal Section
              _buildSectionTitle('Legal'),
              const SizedBox(height: 12),

              _buildInfoItem(
                title: 'Terms of Service',
                subtitle: 'Read our terms and conditions',
                icon: Icons.description_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening Terms of Service...'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              _buildInfoItem(
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                icon: Icons.privacy_tip_outlined,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening Privacy Policy...'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              _buildInfoItem(
                title: 'Open Source Licenses',
                subtitle: 'View third-party licenses',
                icon: Icons.code_outlined,
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Focus App',
                    applicationVersion: '1.0.0',
                    applicationIcon: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFF7C3AED),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.remove_red_eye,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Support Section
              _buildSectionTitle('Support'),
              const SizedBox(height: 12),

              _buildInfoItem(
                title: 'Help Center',
                subtitle: 'Get help and support',
                icon: Icons.help_outline,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Opening Help Center...'),
                      backgroundColor: Color(0xFF8B5CF6),
                    ),
                  );
                },
              ),

              _buildInfoItem(
                title: 'Contact Us',
                subtitle: 'Send us your feedback',
                icon: Icons.email_outlined,
                onTap: () {
                  _showContactDialog(context);
                },
              ),

              _buildInfoItem(
                title: 'Report a Bug',
                subtitle: 'Help us improve the app',
                icon: Icons.bug_report_outlined,
                onTap: () {
                  _showBugReportDialog(context);
                },
              ),

              const SizedBox(height: 40),

              // Footer
              const Text(
                'Made with 💜 for focused individuals',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                '© 2025 Focus App. All rights reserved.',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 13,
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Widget _buildInfoItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8B5CF6),
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

  static void _showChangelogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'What\'s New in 1.0.0',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildChangelogItem('🎉', 'Initial release of Focus App'),
              _buildChangelogItem('⏱️', 'Focus timer with project tracking'),
              _buildChangelogItem('📊', 'Statistics and analytics dashboard'),
              _buildChangelogItem('👥', 'Friends and groups functionality'),
              _buildChangelogItem('🏆', 'Achievements and streak system'),
              _buildChangelogItem('🔔', 'Smart notifications'),
              _buildChangelogItem('📱', 'Beautiful, intuitive interface'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildChangelogItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Contact Us',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Email us at:\nsupport@focusapp.com\n\nWe typically respond within 24 hours.',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening email app...'),
                  backgroundColor: Color(0xFF8B5CF6),
                ),
              );
            },
            child: const Text(
              'Send Email',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showBugReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Report a Bug',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Thank you for helping us improve!\n\nPlease email bug reports to:\nbugs@focusapp.com\n\nInclude:\n• Description of the issue\n• Steps to reproduce\n• Screenshots if possible',
          style: TextStyle(
            color: Color(0xFF8E8E93),
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening email app...'),
                  backgroundColor: Color(0xFF8B5CF6),
                ),
              );
            },
            child: const Text(
              'Send Report',
              style: TextStyle(
                color: Color(0xFF8B5CF6),
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
