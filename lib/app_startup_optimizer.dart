import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App startup optimization coordinator
///
/// PERFORMANCE: Reduce app cold start time by deferring non-critical initialization
/// - Prioritize critical initialization
/// - Defer heavy operations
/// - Track startup performance
/// - Optimize first frame time
class AppStartupOptimizer {
  static final AppStartupOptimizer _instance = AppStartupOptimizer._internal();
  static AppStartupOptimizer get instance => _instance;

  factory AppStartupOptimizer() => _instance;
  AppStartupOptimizer._internal();

  final Map<String, Duration> _initTimes = {};
  DateTime? _appStartTime;
  DateTime? _firstFrameTime;
  bool _isInitialized = false;

  final List<_DeferredTask> _deferredTasks = [];

  /// Record app start time
  void recordAppStart() {
    _appStartTime = DateTime.now();
    if (kDebugMode) {
      debugPrint('⏱️  AppStartup: App started');
    }
  }

  /// Record first frame render
  void recordFirstFrame() {
    _firstFrameTime = DateTime.now();
    if (_appStartTime != null && kDebugMode) {
      final timeToFirstFrame = _firstFrameTime!.difference(_appStartTime!);
      debugPrint('🎨 AppStartup: First frame in ${timeToFirstFrame.inMilliseconds}ms');
    }
  }

  /// Initialize critical services synchronously
  ///
  /// PERFORMANCE: Only include services needed for first screen
  Future<void> initializeCritical() async {
    if (_isInitialized) return;

    final stopwatch = Stopwatch()..start();

    try {
      if (kDebugMode) {
        debugPrint('🚀 AppStartup: Initializing critical services...');
      }

      // Add your critical initialization here
      // Example: Firebase, Auth, Essential Services

      await _measureInit('Critical Services', () async {
        // await FirebaseService.instance.initialize();
        // await AuthService.instance.initialize();
        await Future.delayed(const Duration(milliseconds: 10)); // Placeholder
      });

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ AppStartup: Critical init completed in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      debugPrint('❌ AppStartup: Critical init failed: $e');
      rethrow;
    }
  }

  /// Initialize non-critical services after first frame
  ///
  /// PERFORMANCE: Defer these to speed up perceived startup
  Future<void> initializeDeferred() async {
    // Wait for first frame
    await WidgetsBinding.instance.endOfFrame;

    if (kDebugMode) {
      debugPrint('🔄 AppStartup: Initializing deferred services...');
    }

    // Initialize in order of priority
    _deferredTasks.sort((a, b) => b.priority.compareTo(a.priority));

    for (final task in _deferredTasks) {
      try {
        await _measureInit(task.name, task.initializer);
      } catch (e) {
        debugPrint('⚠️  AppStartup: Deferred task ${task.name} failed: $e');
        // Continue with other tasks even if one fails
      }
    }

    _deferredTasks.clear();

    if (kDebugMode) {
      debugPrint('✅ AppStartup: All deferred services initialized');
    }
  }

  /// Add a deferred initialization task
  ///
  /// [priority] higher = runs earlier (0-100)
  void addDeferredTask(
    String name,
    Future<void> Function() initializer, {
    int priority = 50,
  }) {
    _deferredTasks.add(_DeferredTask(
      name: name,
      initializer: initializer,
      priority: priority,
    ));

    if (kDebugMode) {
      debugPrint('📋 AppStartup: Added deferred task "$name" (priority: $priority)');
    }
  }

  /// Measure initialization time for a service
  Future<T> _measureInit<T>(String name, Future<T> Function() initializer) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await initializer();

      _initTimes[name] = stopwatch.elapsed;

      if (kDebugMode) {
        debugPrint('   ✓ $name: ${stopwatch.elapsedMilliseconds}ms');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('   ✗ $name: Failed after ${stopwatch.elapsedMilliseconds}ms');
      }
      rethrow;
    }
  }

  /// Get startup statistics
  Map<String, dynamic> getStats() {
    final timeToFirstFrame = _appStartTime != null && _firstFrameTime != null
        ? _firstFrameTime!.difference(_appStartTime!)
        : null;

    return {
      'time_to_first_frame_ms': timeToFirstFrame?.inMilliseconds,
      'initialization_times': _initTimes.map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
      'is_initialized': _isInitialized,
      'pending_deferred_tasks': _deferredTasks.length,
    };
  }

  /// Print startup performance report
  void printReport() {
    debugPrint('\n⏱️  ===== STARTUP PERFORMANCE REPORT =====');

    if (_appStartTime != null && _firstFrameTime != null) {
      final ttff = _firstFrameTime!.difference(_appStartTime!);
      debugPrint('Time to First Frame: ${ttff.inMilliseconds}ms');

      if (ttff.inMilliseconds < 500) {
        debugPrint('   ✅ Excellent (<500ms)');
      } else if (ttff.inMilliseconds < 1000) {
        debugPrint('   ⚠️  Good (500-1000ms)');
      } else {
        debugPrint('   ❌ Needs improvement (>1000ms)');
      }
    }

    if (_initTimes.isNotEmpty) {
      debugPrint('\nInitialization Times:');
      final sortedTimes = _initTimes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (final entry in sortedTimes) {
        debugPrint('   ${entry.key}: ${entry.value.inMilliseconds}ms');
      }

      final total = _initTimes.values.fold<Duration>(
        Duration.zero,
        (sum, duration) => sum + duration,
      );
      debugPrint('\nTotal init time: ${total.inMilliseconds}ms');
    }

    debugPrint('======================================\n');
  }

  /// Clear all data (for testing)
  void clear() {
    _initTimes.clear();
    _deferredTasks.clear();
    _appStartTime = null;
    _firstFrameTime = null;
    _isInitialized = false;
  }
}

class _DeferredTask {
  final String name;
  final Future<void> Function() initializer;
  final int priority;

  _DeferredTask({
    required this.name,
    required this.initializer,
    required this.priority,
  });
}

/// Helper for optimizing main() function
///
/// Usage in main.dart:
/// ```dart
/// void main() async {
///   AppStartupHelper.recordStart();
///
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Critical initialization only
///   await AppStartupOptimizer.instance.initializeCritical();
///
///   // Run app
///   runApp(const MyApp());
///
///   // Defer non-critical initialization
///   AppStartupOptimizer.instance.initializeDeferred();
/// }
/// ```
class AppStartupHelper {
  /// Record app start time
  static void recordStart() {
    AppStartupOptimizer.instance.recordAppStart();
  }

  /// Schedule first frame callback
  static void scheduleFirstFrameCallback(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupOptimizer.instance.recordFirstFrame();
      callback();
    });
  }

  /// Add common deferred initializations
  static void setupCommonDeferredTasks() {
    // High priority (runs first after first frame)
    AppStartupOptimizer.instance.addDeferredTask(
      'Analytics',
      () async {
        // await AnalyticsService.instance.initialize();
        await Future.delayed(const Duration(milliseconds: 50)); // Placeholder
      },
      priority: 80,
    );

    // Medium priority
    AppStartupOptimizer.instance.addDeferredTask(
      'Cache Warmup',
      () async {
        // Warm up caches, preload common data
        await Future.delayed(const Duration(milliseconds: 100)); // Placeholder
      },
      priority: 50,
    );

    // Low priority (runs last)
    AppStartupOptimizer.instance.addDeferredTask(
      'Background Services',
      () async {
        // Start background sync, notifications, etc.
        await Future.delayed(const Duration(milliseconds: 150)); // Placeholder
      },
      priority: 20,
    );
  }
}

/// Splash screen coordinator for smooth transitions
///
/// PERFORMANCE: Keep splash visible until app is ready
class SplashScreenCoordinator {
  static final SplashScreenCoordinator _instance = SplashScreenCoordinator._internal();
  static SplashScreenCoordinator get instance => _instance;

  factory SplashScreenCoordinator() => _instance;
  SplashScreenCoordinator._internal();

  bool _isAppReady = false;
  final _readyCompleter = Completer<void>();

  /// Check if app is ready to show main content
  bool get isReady => _isAppReady;

  /// Future that completes when app is ready
  Future<void> get ready => _readyCompleter.future;

  /// Mark app as ready (dismiss splash)
  void markReady() {
    if (!_isAppReady) {
      _isAppReady = true;
      _readyCompleter.complete();

      if (kDebugMode) {
        debugPrint('✅ SplashScreen: App ready, can dismiss splash');
      }
    }
  }

  /// Reset (for testing)
  void reset() {
    _isAppReady = false;
  }
}

/// Widget that shows splash until app is ready
class SplashAwareApp extends StatelessWidget {
  final Widget splash;
  final Widget app;
  final Duration minimumDuration;

  const SplashAwareApp({
    super.key,
    required this.splash,
    required this.app,
    this.minimumDuration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.wait([
        SplashScreenCoordinator.instance.ready,
        Future.delayed(minimumDuration), // Minimum splash time
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return app;
        }
        return splash;
      },
    );
  }
}

/// Preload critical assets during splash
class AssetPreloader {
  static Future<void> preloadCriticalAssets(BuildContext context) async {
    final stopwatch = Stopwatch()..start();

    if (kDebugMode) {
      debugPrint('🖼️  AssetPreloader: Starting preload...');
    }

    // Preload critical images
    final imagesToPreload = [
      // Add your critical images here
      // 'assets/images/logo.png',
      // 'assets/images/background.jpg',
    ];

    try {
      await Future.wait(
        imagesToPreload.map((path) => precacheImage(AssetImage(path), context)),
      );

      if (kDebugMode) {
        debugPrint(
          '✅ AssetPreloader: Preloaded ${imagesToPreload.length} assets in ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      debugPrint('⚠️  AssetPreloader: Error preloading assets: $e');
    }
  }
}

/// Startup performance benchmarks
class StartupBenchmarks {
  // Target metrics for good performance
  static const Duration targetFirstFrame = Duration(milliseconds: 500);
  static const Duration targetCriticalInit = Duration(milliseconds: 200);
  static const Duration targetTotalStartup = Duration(seconds: 1);

  /// Check if startup performance meets targets
  static bool meetsTargets() {
    final stats = AppStartupOptimizer.instance.getStats();
    final ttff = stats['time_to_first_frame_ms'] as int?;

    if (ttff == null) return false;

    return ttff <= targetFirstFrame.inMilliseconds;
  }

  /// Get performance grade
  static String getPerformanceGrade() {
    final stats = AppStartupOptimizer.instance.getStats();
    final ttff = stats['time_to_first_frame_ms'] as int?;

    if (ttff == null) return 'N/A';

    if (ttff < 500) return 'A+ (Excellent)';
    if (ttff < 800) return 'A (Great)';
    if (ttff < 1200) return 'B (Good)';
    if (ttff < 2000) return 'C (Fair)';
    return 'D (Needs Improvement)';
  }

  /// Print benchmark results
  static void printBenchmarks() {
    debugPrint('\n📊 ===== STARTUP BENCHMARKS =====');

    final stats = AppStartupOptimizer.instance.getStats();
    final ttff = stats['time_to_first_frame_ms'] as int?;

    if (ttff != null) {
      debugPrint('Time to First Frame: ${ttff}ms');
      debugPrint('Target: ${targetFirstFrame.inMilliseconds}ms');
      debugPrint('Grade: ${getPerformanceGrade()}');

      final diff = ttff - targetFirstFrame.inMilliseconds;
      if (diff > 0) {
        debugPrint('⚠️  ${diff}ms slower than target');
      } else {
        debugPrint('✅ ${diff.abs()}ms faster than target');
      }
    } else {
      debugPrint('⚠️  No timing data available');
    }

    debugPrint('==============================\n');
  }
}
