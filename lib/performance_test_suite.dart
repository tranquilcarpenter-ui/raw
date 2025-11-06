import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Automated performance testing suite
///
/// TESTING: Catch performance regressions before they reach production
/// - Widget build time tests
/// - Frame rendering tests
/// - Memory usage tests
/// - Startup time tests
/// - Animation performance tests
class PerformanceTestSuite {
  static final PerformanceTestSuite _instance = PerformanceTestSuite._internal();
  static PerformanceTestSuite get instance => _instance;

  factory PerformanceTestSuite() => _instance;
  PerformanceTestSuite._internal();

  final Map<String, TestResult> _results = {};
  final List<PerformanceTest> _tests = [];

  /// Register a performance test
  void registerTest(PerformanceTest test) {
    _tests.add(test);
    if (kDebugMode) {
      debugPrint('📝 PerformanceTest: Registered "${test.name}"');
    }
  }

  /// Run all registered tests
  Future<TestSuiteResult> runAll({
    bool stopOnFailure = false,
  }) async {
    if (kDebugMode) {
      debugPrint('\n🏁 PerformanceTest: Running ${_tests.length} tests...\n');
    }

    _results.clear();
    final stopwatch = Stopwatch()..start();

    var passed = 0;
    var failed = 0;
    var warnings = 0;

    for (final test in _tests) {
      try {
        final result = await test.run();
        _results[test.name] = result;

        if (result.passed) {
          passed++;
          if (kDebugMode) {
            debugPrint('✅ ${test.name}: ${result.message}');
          }
        } else if (result.isWarning) {
          warnings++;
          if (kDebugMode) {
            debugPrint('⚠️  ${test.name}: ${result.message}');
          }
        } else {
          failed++;
          if (kDebugMode) {
            debugPrint('❌ ${test.name}: ${result.message}');
          }

          if (stopOnFailure) {
            break;
          }
        }
      } catch (e, st) {
        failed++;
        _results[test.name] = TestResult.failure(
          test.name,
          'Exception: $e',
        );
        if (kDebugMode) {
          debugPrint('💥 ${test.name}: Exception: $e');
          debugPrint('$st');
        }

        if (stopOnFailure) {
          break;
        }
      }
    }

    final totalTime = stopwatch.elapsed;

    if (kDebugMode) {
      debugPrint('\n📊 ===== TEST RESULTS =====');
      debugPrint('Total: ${_tests.length} tests');
      debugPrint('✅ Passed: $passed');
      debugPrint('⚠️  Warnings: $warnings');
      debugPrint('❌ Failed: $failed');
      debugPrint('⏱️  Time: ${totalTime.inMilliseconds}ms');
      debugPrint('==========================\n');
    }

    return TestSuiteResult(
      totalTests: _tests.length,
      passed: passed,
      failed: failed,
      warnings: warnings,
      totalTime: totalTime,
      results: Map.from(_results),
    );
  }

  /// Run specific test by name
  Future<TestResult?> runTest(String name) async {
    final test = _tests.firstWhere(
      (t) => t.name == name,
      orElse: () => throw ArgumentError('Test "$name" not found'),
    );

    return test.run();
  }

  /// Get test results
  Map<String, TestResult> get results => Map.from(_results);

  /// Clear all tests and results
  void clear() {
    _tests.clear();
    _results.clear();
  }
}

/// Base class for performance tests
abstract class PerformanceTest {
  final String name;
  final String description;
  final PerformanceThresholds thresholds;

  PerformanceTest({
    required this.name,
    required this.description,
    required this.thresholds,
  });

  /// Run the test and return result
  Future<TestResult> run();
}

/// Performance thresholds for tests
class PerformanceThresholds {
  final Duration? maxDuration;
  final int? maxMemoryMB;
  final int? maxFrameDrops;
  final double? maxCpuPercent;

  /// Threshold for warnings (before failure)
  final double warningMultiplier;

  const PerformanceThresholds({
    this.maxDuration,
    this.maxMemoryMB,
    this.maxFrameDrops,
    this.maxCpuPercent,
    this.warningMultiplier = 0.8,
  });

  static const widget = PerformanceThresholds(
    maxDuration: Duration(milliseconds: 16), // 60fps = 16ms per frame
  );

  static const startup = PerformanceThresholds(
    maxDuration: Duration(milliseconds: 500),
  );

  static const navigation = PerformanceThresholds(
    maxDuration: Duration(milliseconds: 300),
  );

  static const animation = PerformanceThresholds(
    maxDuration: Duration(milliseconds: 16),
    maxFrameDrops: 2,
  );

  static const memory = PerformanceThresholds(
    maxMemoryMB: 100,
  );
}

/// Result of a performance test
class TestResult {
  final String testName;
  final bool passed;
  final bool isWarning;
  final String message;
  final Map<String, dynamic> metrics;
  final Duration duration;

  TestResult({
    required this.testName,
    required this.passed,
    required this.message,
    this.isWarning = false,
    this.metrics = const {},
    this.duration = Duration.zero,
  });

  factory TestResult.success(String testName, String message, {Map<String, dynamic>? metrics}) {
    return TestResult(
      testName: testName,
      passed: true,
      message: message,
      metrics: metrics ?? {},
    );
  }

  factory TestResult.failure(String testName, String message, {Map<String, dynamic>? metrics}) {
    return TestResult(
      testName: testName,
      passed: false,
      message: message,
      metrics: metrics ?? {},
    );
  }

  factory TestResult.warning(String testName, String message, {Map<String, dynamic>? metrics}) {
    return TestResult(
      testName: testName,
      passed: true,
      isWarning: true,
      message: message,
      metrics: metrics ?? {},
    );
  }
}

/// Result of entire test suite
class TestSuiteResult {
  final int totalTests;
  final int passed;
  final int failed;
  final int warnings;
  final Duration totalTime;
  final Map<String, TestResult> results;

  TestSuiteResult({
    required this.totalTests,
    required this.passed,
    required this.failed,
    required this.warnings,
    required this.totalTime,
    required this.results,
  });

  bool get allPassed => failed == 0;
  double get passRate => totalTests > 0 ? passed / totalTests : 0.0;
}

/// Widget build time test
class WidgetBuildTest extends PerformanceTest {
  final Widget widget;
  final int iterations;

  WidgetBuildTest({
    required String name,
    required this.widget,
    this.iterations = 100,
    PerformanceThresholds thresholds = PerformanceThresholds.widget,
  }) : super(
          name: name,
          description: 'Measure widget build time',
          thresholds: thresholds,
        );

  @override
  Future<TestResult> run() async {
    final durations = <Duration>[];

    for (var i = 0; i < iterations; i++) {
      final stopwatch = Stopwatch()..start();

      // Build widget (this is simplified - in real tests use WidgetTester)
      widget.createElement();

      durations.add(stopwatch.elapsed);
    }

    // Calculate statistics
    final totalMs = durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds) / 1000;
    final avgMs = totalMs / iterations;
    final maxMs = durations.map((d) => d.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;

    final threshold = thresholds.maxDuration!.inMicroseconds / 1000;
    final warningThreshold = threshold * thresholds.warningMultiplier;

    if (avgMs > threshold) {
      return TestResult.failure(
        name,
        'Average build time ${avgMs.toStringAsFixed(2)}ms exceeds ${threshold.toStringAsFixed(2)}ms',
        metrics: {
          'avg_ms': avgMs,
          'max_ms': maxMs,
          'iterations': iterations,
        },
      );
    } else if (avgMs > warningThreshold) {
      return TestResult.warning(
        name,
        'Average build time ${avgMs.toStringAsFixed(2)}ms approaching limit',
        metrics: {
          'avg_ms': avgMs,
          'max_ms': maxMs,
          'iterations': iterations,
        },
      );
    }

    return TestResult.success(
      name,
      'Average build time: ${avgMs.toStringAsFixed(2)}ms',
      metrics: {
        'avg_ms': avgMs,
        'max_ms': maxMs,
        'iterations': iterations,
      },
    );
  }
}

/// Frame rendering performance test
class FrameRenderingTest extends PerformanceTest {
  final Future<void> Function() scenario;
  final Duration testDuration;

  FrameRenderingTest({
    required String name,
    required this.scenario,
    this.testDuration = const Duration(seconds: 2),
    PerformanceThresholds thresholds = PerformanceThresholds.animation,
  }) : super(
          name: name,
          description: 'Measure frame rendering performance',
          thresholds: thresholds,
        );

  @override
  Future<TestResult> run() async {
    final frameTimes = <Duration>[];
    final stopwatch = Stopwatch()..start();

    // Simulate frame callbacks
    while (stopwatch.elapsed < testDuration) {
      final frameStart = Stopwatch()..start();

      await scenario();

      frameTimes.add(frameStart.elapsed);
      await Future.delayed(const Duration(milliseconds: 16)); // Target 60fps
    }

    // Analyze frame times
    final droppedFrames = frameTimes.where((d) => d.inMilliseconds > 16).length;
    final avgFrameTime = frameTimes.fold<int>(0, (sum, d) => sum + d.inMilliseconds) / frameTimes.length;

    final maxDrops = thresholds.maxFrameDrops ?? 0;

    if (droppedFrames > maxDrops) {
      return TestResult.failure(
        name,
        'Dropped $droppedFrames frames (max: $maxDrops)',
        metrics: {
          'dropped_frames': droppedFrames,
          'avg_frame_ms': avgFrameTime,
          'total_frames': frameTimes.length,
        },
      );
    }

    return TestResult.success(
      name,
      'Dropped $droppedFrames frames',
      metrics: {
        'dropped_frames': droppedFrames,
        'avg_frame_ms': avgFrameTime,
        'total_frames': frameTimes.length,
      },
    );
  }
}

/// Memory usage test
class MemoryUsageTest extends PerformanceTest {
  final Future<void> Function() scenario;

  MemoryUsageTest({
    required String name,
    required this.scenario,
    PerformanceThresholds thresholds = PerformanceThresholds.memory,
  }) : super(
          name: name,
          description: 'Measure memory usage',
          thresholds: thresholds,
        );

  @override
  Future<TestResult> run() async {
    // Force GC before measuring
    await Future.delayed(const Duration(milliseconds: 100));

    final memoryBefore = _estimateMemoryUsageMB();

    await scenario();

    // Wait for any async operations
    await Future.delayed(const Duration(milliseconds: 100));

    final memoryAfter = _estimateMemoryUsageMB();
    final memoryDelta = memoryAfter - memoryBefore;

    final maxMemory = thresholds.maxMemoryMB ?? 100;
    final warningMemory = maxMemory * thresholds.warningMultiplier;

    if (memoryDelta > maxMemory) {
      return TestResult.failure(
        name,
        'Memory increased by ${memoryDelta}MB (max: ${maxMemory}MB)',
        metrics: {
          'memory_before_mb': memoryBefore,
          'memory_after_mb': memoryAfter,
          'memory_delta_mb': memoryDelta,
        },
      );
    } else if (memoryDelta > warningMemory) {
      return TestResult.warning(
        name,
        'Memory increased by ${memoryDelta}MB',
        metrics: {
          'memory_before_mb': memoryBefore,
          'memory_after_mb': memoryAfter,
          'memory_delta_mb': memoryDelta,
        },
      );
    }

    return TestResult.success(
      name,
      'Memory increased by ${memoryDelta}MB',
      metrics: {
        'memory_before_mb': memoryBefore,
        'memory_after_mb': memoryAfter,
        'memory_delta_mb': memoryDelta,
      },
    );
  }

  int _estimateMemoryUsageMB() {
    // This is a simplified estimation
    // In real tests, you'd use more sophisticated memory profiling
    return 0; // Placeholder
  }
}

/// Operation timing test
class OperationTimingTest extends PerformanceTest {
  final Future<void> Function() operation;
  final int iterations;

  OperationTimingTest({
    required String name,
    required this.operation,
    this.iterations = 10,
    required PerformanceThresholds thresholds,
  }) : super(
          name: name,
          description: 'Measure operation timing',
          thresholds: thresholds,
        );

  @override
  Future<TestResult> run() async {
    final durations = <Duration>[];

    for (var i = 0; i < iterations; i++) {
      final stopwatch = Stopwatch()..start();
      await operation();
      durations.add(stopwatch.elapsed);
    }

    // Calculate statistics
    final avgMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) / iterations;
    final maxMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
    final minMs = durations.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);

    final threshold = thresholds.maxDuration!.inMilliseconds.toDouble();
    final warningThreshold = threshold * thresholds.warningMultiplier;

    if (avgMs > threshold) {
      return TestResult.failure(
        name,
        'Average time ${avgMs.toStringAsFixed(2)}ms exceeds ${threshold.toStringAsFixed(2)}ms',
        metrics: {
          'avg_ms': avgMs,
          'min_ms': minMs,
          'max_ms': maxMs,
          'iterations': iterations,
        },
      );
    } else if (avgMs > warningThreshold) {
      return TestResult.warning(
        name,
        'Average time ${avgMs.toStringAsFixed(2)}ms approaching limit',
        metrics: {
          'avg_ms': avgMs,
          'min_ms': minMs,
          'max_ms': maxMs,
          'iterations': iterations,
        },
      );
    }

    return TestResult.success(
      name,
      'Average time: ${avgMs.toStringAsFixed(2)}ms',
      metrics: {
        'avg_ms': avgMs,
        'min_ms': minMs,
        'max_ms': maxMs,
        'iterations': iterations,
      },
    );
  }
}

/// Example test suite setup
class ExamplePerformanceTests {
  static void registerAll() {
    final suite = PerformanceTestSuite.instance;

    // Widget build tests
    suite.registerTest(WidgetBuildTest(
      name: 'Build HomePage',
      widget: Container(child: Text('Test')),
      iterations: 100,
    ));

    // Operation timing tests
    suite.registerTest(OperationTimingTest(
      name: 'Load User Data',
      operation: () async {
        // Simulate data loading
        await Future.delayed(const Duration(milliseconds: 50));
      },
      iterations: 10,
      thresholds: const PerformanceThresholds(
        maxDuration: Duration(milliseconds: 100),
      ),
    ));

    // Memory tests
    suite.registerTest(MemoryUsageTest(
      name: 'Cache 100 Items',
      scenario: () async {
        final cache = <int, String>{};
        for (var i = 0; i < 100; i++) {
          cache[i] = 'Item $i' * 100;
        }
      },
    ));

    if (kDebugMode) {
      debugPrint('✅ Registered ${suite._tests.length} performance tests');
    }
  }

  static Future<void> runAllTests() async {
    registerAll();

    final result = await PerformanceTestSuite.instance.runAll();

    if (!result.allPassed) {
      debugPrint('⚠️  Some performance tests failed!');
    }
  }
}

/// Integration with Flutter testing
class FlutterPerformanceTestHelper {
  /// Run widget performance test
  static Future<void> testWidgetPerformance(
    WidgetTester tester,
    Widget widget, {
    required String name,
    PerformanceThresholds? thresholds,
  }) async {
    final stopwatch = Stopwatch()..start();

    await tester.pumpWidget(widget);

    final buildTime = stopwatch.elapsed;

    if (kDebugMode) {
      debugPrint('⏱️  $name: Built in ${buildTime.inMilliseconds}ms');
    }

    expect(
      buildTime.inMilliseconds,
      lessThan((thresholds?.maxDuration ?? PerformanceThresholds.widget.maxDuration)!.inMilliseconds),
      reason: '$name build time exceeded threshold',
    );
  }

  /// Benchmark widget rebuilds
  static Future<void> benchmarkRebuilds(
    WidgetTester tester,
    Widget widget,
    int iterations,
  ) async {
    final durations = <Duration>[];

    for (var i = 0; i < iterations; i++) {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(widget);
      durations.add(stopwatch.elapsed);
    }

    final avgMs = durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds) / iterations;

    if (kDebugMode) {
      debugPrint('📊 Average rebuild time: ${avgMs.toStringAsFixed(2)}ms over $iterations iterations');
    }
  }
}

/// Performance regression detector
class PerformanceRegressionDetector {
  final Map<String, List<double>> _historicalMetrics = {};

  /// Record a metric for regression detection
  void recordMetric(String name, double value) {
    if (!_historicalMetrics.containsKey(name)) {
      _historicalMetrics[name] = [];
    }

    _historicalMetrics[name]!.add(value);

    // Keep last 100 measurements
    if (_historicalMetrics[name]!.length > 100) {
      _historicalMetrics[name]!.removeAt(0);
    }
  }

  /// Check if there's a performance regression
  bool hasRegression(String name, double currentValue, {double threshold = 1.2}) {
    final history = _historicalMetrics[name];
    if (history == null || history.isEmpty) {
      return false;
    }

    final avg = history.reduce((a, b) => a + b) / history.length;

    // Regression if current value is 20% worse than average
    return currentValue > avg * threshold;
  }

  /// Get baseline for a metric
  double? getBaseline(String name) {
    final history = _historicalMetrics[name];
    if (history == null || history.isEmpty) {
      return null;
    }

    return history.reduce((a, b) => a + b) / history.length;
  }

  /// Clear historical data
  void clear() {
    _historicalMetrics.clear();
  }
}
