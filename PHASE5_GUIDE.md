# Phase 5: Advanced Performance - Memory, Startup, and Production Monitoring

## Overview

Phase 5 focuses on advanced performance optimizations for production-ready apps:

- **Memory Management**: Detect and prevent memory leaks
- **Startup Optimization**: Reduce app cold start time
- **Background Processing**: Offload heavy work to isolates
- **Automated Testing**: Catch performance regressions early
- **Production Monitoring**: Track real-world performance

## Files Created

1. `lib/memory_leak_detector.dart` - Memory leak detection and tracking
2. `lib/app_startup_optimizer.dart` - App startup and splash screen optimization
3. `lib/isolate_helper.dart` - Background computation helper
4. `lib/performance_test_suite.dart` - Automated performance testing
5. `lib/production_analytics.dart` - Production performance monitoring

---

## 1. Memory Leak Detection

### Problem

Memory leaks cause:
- Increasing memory usage over time
- App crashes on low-memory devices
- Poor user experience
- Difficult to detect during development

### Solution

`MemoryLeakDetector` helps identify retained objects that should have been disposed.

### Usage

#### Track Widgets for Leaks

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with LeakTrackerMixin {
  @override
  void initState() {
    super.initState();
    trackForLeaks(); // Automatically tracks this widget
  }

  // dispose() is handled by LeakTrackerMixin
}
```

#### Track Custom Objects

```dart
class MyService {
  MyService() {
    MemoryLeakDetector.instance.track(this, 'MyService');
  }

  void dispose() {
    MemoryLeakDetector.instance.untrack(this);
  }
}
```

#### Track Stream Subscriptions

```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget>
    with StreamSubscriptionTracker {
  @override
  void initState() {
    super.initState();

    // Automatically tracked
    trackSubscription(
      someStream.listen((data) {
        // Handle data
      }),
      name: 'data_stream',
    );
  }

  // dispose() automatically cancels all subscriptions
}
```

#### Check for Leaks

```dart
// In your app (debug build only):
void main() {
  if (kDebugMode) {
    // Check for leaks every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (_) {
      MemoryLeakDetector.instance.checkForLeaks();
    });
  }

  runApp(MyApp());
}
```

#### Monitor Memory Usage

```dart
void main() {
  if (kDebugMode) {
    // Monitor memory every 10 seconds
    MemoryMonitor.instance.startMonitoring(
      interval: const Duration(seconds: 10),
      warningThreshold: 200, // MB
    );
  }

  runApp(MyApp());
}
```

### Best Practices

1. ✅ Use `LeakTrackerMixin` for StatefulWidgets
2. ✅ Track long-lived objects (services, controllers)
3. ✅ Track stream subscriptions that live beyond widget lifecycle
4. ✅ Run leak checks periodically in debug builds
5. ❌ Don't track short-lived objects (temporary variables)
6. ❌ Don't ship leak detection code to production

---

## 2. App Startup Optimization

### Problem

Slow app startup causes:
- Poor first impression
- User frustration
- Lower retention rates
- Worse app store ratings

### Solution

Split initialization into **critical** (blocks first frame) and **deferred** (runs after first frame).

### Usage

#### Setup in main.dart

```dart
void main() async {
  // 1. Record app start time
  AppStartupOptimizer.instance.recordAppStart();

  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize ONLY critical services
  await AppStartupOptimizer.instance.initializeCritical();

  // 3. Setup deferred tasks (but don't run them yet)
  AppStartupHelper.setupCommonDeferredTasks();

  // Add your own deferred tasks
  AppStartupOptimizer.instance.addDeferredTask(
    'Firebase Analytics',
    () async {
      await FirebaseAnalytics.instance.initialize();
    },
    priority: 80, // High priority
  );

  AppStartupOptimizer.instance.addDeferredTask(
    'Background Sync',
    () async {
      await BackgroundSync.initialize();
    },
    priority: 20, // Low priority
  );

  // 4. Run app
  runApp(MyApp());

  // 5. Initialize deferred services (after first frame)
  AppStartupOptimizer.instance.initializeDeferred();
}
```

#### Add Critical Initialization

```dart
// In lib/app_startup_optimizer.dart, modify initializeCritical():
Future<void> initializeCritical() async {
  if (_isInitialized) return;

  await _measureInit('Firebase Core', () async {
    await Firebase.initializeApp();
  });

  await _measureInit('Authentication', () async {
    await AuthService.instance.initialize();
  });

  _isInitialized = true;
}
```

#### Using Splash Screen Coordinator

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashAwareApp(
        splash: SplashScreen(), // Your splash screen
        app: HomePage(), // Main app
        minimumDuration: Duration(milliseconds: 500),
      ),
    );
  }
}

// In your app initialization:
void _initializeApp() async {
  await AppStartupOptimizer.instance.initializeCritical();

  // Mark app as ready (dismisses splash)
  SplashScreenCoordinator.instance.markReady();
}
```

#### Preload Critical Assets

```dart
class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Preload critical images
    await AssetPreloader.preloadCriticalAssets(context);

    // Initialize app
    await AppStartupOptimizer.instance.initializeCritical();

    // Mark ready
    SplashScreenCoordinator.instance.markReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
```

#### Print Startup Report

```dart
void main() async {
  // ... initialization ...

  if (kDebugMode) {
    // Print startup performance after app is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupOptimizer.instance.printReport();
      StartupBenchmarks.printBenchmarks();
    });
  }

  runApp(MyApp());
}
```

### Performance Targets

- **Excellent**: < 500ms to first frame
- **Good**: 500-1000ms
- **Needs Improvement**: > 1000ms

### Best Practices

1. ✅ Minimize critical initialization (only what's needed for first screen)
2. ✅ Defer analytics, background services, cache warmup
3. ✅ Use splash screen to hide initialization
4. ✅ Preload only critical assets (not all assets)
5. ✅ Measure and track startup time
6. ❌ Don't load all services before first frame
7. ❌ Don't make network requests in critical path
8. ❌ Don't parse large data during startup

---

## 3. Isolate Helper (Background Processing)

### Problem

Heavy computations on main thread cause:
- UI jank and freezing
- Dropped frames
- ANR (Application Not Responding) dialogs
- Poor user experience

### Solution

Offload CPU-intensive work to background isolates.

### Usage

#### One-off Computation

```dart
// Parse large JSON in background
final data = await IsolateHelper.compute(
  parseJsonInIsolate,
  largeJsonString,
  debugLabel: 'Parse user data',
);

// Top-level or static function
dynamic parseJsonInIsolate(String json) {
  return jsonDecode(json);
}
```

#### Common Tasks

```dart
// Parse JSON
final parsed = await IsolateTasks.parseJson(largeJsonString);

// Sort large list
final sorted = await IsolateTasks.sortList(
  largeList,
  (a, b) => b.compareTo(a),
);

// Filter large list
final filtered = await IsolateTasks.filterList(
  items,
  (item) => item.isActive,
);

// Compute statistics
final stats = await IsolateTasks.computeStats(values);
print('Mean: ${stats.mean}, StdDev: ${stats.stdDev}');
```

#### Pooled Isolates (for repeated tasks)

```dart
// Create pool once
await IsolateHelper.instance.getPool('image_processor', maxIsolates: 2);

// Run multiple tasks (automatically queued if all isolates busy)
for (var i = 0; i < 10; i++) {
  final result = await IsolateHelper.instance.runInPool(
    'image_processor',
    processImage,
    images[i],
    debugLabel: 'Process image $i',
  );
}

// Dispose pool when done
await IsolateHelper.instance.disposePool('image_processor');
```

### When to Use Isolates

✅ **Use isolates for:**
- JSON parsing for large responses (>100KB)
- Image processing and manipulation
- Encryption/decryption operations
- Complex calculations (>100ms on main thread)
- Large list sorting/filtering (>1000 items)
- Data transformations that are CPU-intensive

❌ **Don't use isolates for:**
- Simple operations (<10ms)
- Operations requiring UI context
- Network requests (use async/await instead)
- Database queries (already async)
- Operations with complex object graphs (serialization overhead)

### Best Practices

1. ✅ Use `compute()` for one-off tasks
2. ✅ Use pooled isolates for repeated similar tasks
3. ✅ Keep message data simple (primitives, lists, maps)
4. ✅ Test both with and without isolates to measure benefit
5. ❌ Avoid passing complex objects (classes with methods)
6. ❌ Don't over-isolate (spawning cost ~100-200ms)

---

## 4. Automated Performance Testing

### Problem

Performance regressions are:
- Hard to detect manually
- Often discovered too late
- Costly to fix after release
- Cause bad user experience

### Solution

Automated tests that fail when performance degrades.

### Usage

#### Register Tests

```dart
void main() {
  // Register widget build tests
  PerformanceTestSuite.instance.registerTest(
    WidgetBuildTest(
      name: 'Build HomeScreen',
      widget: HomeScreen(),
      iterations: 100,
      thresholds: PerformanceThresholds.widget, // 16ms per frame
    ),
  );

  // Register operation timing tests
  PerformanceTestSuite.instance.registerTest(
    OperationTimingTest(
      name: 'Load User Data',
      operation: () async {
        await UserDataService.instance.loadUserData('test_user');
      },
      iterations: 10,
      thresholds: const PerformanceThresholds(
        maxDuration: Duration(milliseconds: 100),
      ),
    ),
  );

  // Register memory tests
  PerformanceTestSuite.instance.registerTest(
    MemoryUsageTest(
      name: 'Cache 1000 Items',
      scenario: () async {
        final cache = CacheManager<String>();
        for (var i = 0; i < 1000; i++) {
          cache.set('key_$i', 'value_$i');
        }
      },
      thresholds: const PerformanceThresholds(maxMemoryMB: 50),
    ),
  );
}
```

#### Run Tests

```dart
void main() async {
  // Register all tests
  ExamplePerformanceTests.registerAll();

  // Run all tests
  final result = await PerformanceTestSuite.instance.runAll(
    stopOnFailure: false,
  );

  // Check results
  if (!result.allPassed) {
    print('❌ ${result.failed} tests failed!');
    exit(1);
  }

  print('✅ All tests passed!');
}
```

#### Integration with Flutter Tests

```dart
testWidgets('HomeScreen builds quickly', (WidgetTester tester) async {
  await FlutterPerformanceTestHelper.testWidgetPerformance(
    tester,
    HomeScreen(),
    name: 'HomeScreen',
    thresholds: PerformanceThresholds.widget,
  );
});

testWidgets('ListView scrolls smoothly', (WidgetTester tester) async {
  await tester.pumpWidget(MyApp());

  // Benchmark scrolling performance
  final stopwatch = Stopwatch()..start();
  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();

  expect(stopwatch.elapsedMilliseconds, lessThan(300));
});
```

#### Regression Detection

```dart
final detector = PerformanceRegressionDetector();

// Record baseline metrics
for (var i = 0; i < 100; i++) {
  final stopwatch = Stopwatch()..start();
  await someOperation();
  detector.recordMetric('operation_time', stopwatch.elapsedMilliseconds.toDouble());
}

// Later, check for regression
final currentTime = await measureOperation();
if (detector.hasRegression('operation_time', currentTime)) {
  print('⚠️ Performance regression detected!');
}
```

### Best Practices

1. ✅ Run performance tests in CI/CD pipeline
2. ✅ Set realistic thresholds based on actual measurements
3. ✅ Test critical user flows (login, navigation, data loading)
4. ✅ Track baseline metrics over time
5. ✅ Use warnings (80% of threshold) to catch issues early
6. ❌ Don't set thresholds too tight (flaky tests)
7. ❌ Don't skip performance tests to save time

---

## 5. Production Analytics

### Problem

Development performance doesn't always match production:
- Different devices (CPU, memory, screen size)
- Real network conditions
- Actual user behavior patterns
- Production data volumes

### Solution

Track real-world performance metrics in production.

### Usage

#### Initialize in main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize analytics
  await ProductionAnalytics.instance.initialize();

  runApp(MyApp());
}
```

#### Track Screen Load Times

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnalyticsScreenWrapper(
      screenName: 'home',
      child: Scaffold(
        appBar: AppBar(title: Text('Home')),
        body: HomeContent(),
      ),
    );
  }
}

// Automatically tracks load time and sends to analytics
```

#### Track Custom Operations

```dart
Future<void> loadUserData(String userId) async {
  ProductionAnalytics.instance.startTrace('load_user_data');

  try {
    final userData = await _fetchUserData(userId);

    ProductionAnalytics.instance.stopTrace(
      'load_user_data',
      attributes: {'user_id': userId},
    );

    return userData;
  } catch (e) {
    ProductionAnalytics.instance.stopTrace('load_user_data');
    ProductionAnalytics.instance.logError(e.toString(), StackTrace.current);
    rethrow;
  }
}
```

#### Track User Interactions

```dart
void onButtonPressed() {
  InteractionTracker.instance.start('submit_form');

  // Handle form submission
  submitForm().then((_) {
    InteractionTracker.instance.end('submit_form');
  });
}
```

#### Track Network Requests

```dart
Future<Map<String, dynamic>> fetchData() async {
  return NetworkTracker.track(
    '/api/users',
    () async {
      final response = await http.get(Uri.parse('$baseUrl/api/users'));
      return jsonDecode(response.body);
    },
  );
}
```

#### Track App Startup

```dart
void main() async {
  final startupStart = DateTime.now();

  WidgetsFlutterBinding.ensureInitialized();

  final criticalStart = DateTime.now();
  await initializeCriticalServices();
  final criticalTime = DateTime.now().difference(criticalStart);

  runApp(MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final firstFrameTime = DateTime.now().difference(startupStart);
    final totalTime = DateTime.now().difference(startupStart);

    ProductionAnalytics.instance.logAppStartup(
      timeToFirstFrame: firstFrameTime,
      criticalInitTime: criticalTime,
      totalStartupTime: totalTime,
    );
  });
}
```

#### Monitor Frame Drops

```dart
void main() {
  runApp(
    PerformanceMonitoringWidget(
      sampleInterval: Duration(seconds: 10),
      child: MyApp(),
    ),
  );
}
```

#### View Statistics

```dart
// Get stats for a specific metric
final stats = ProductionAnalytics.instance.getStats('screen_home');
if (stats != null) {
  print('Home screen average load: ${stats.avg.toStringAsFixed(2)}ms');
  print('p95: ${stats.p95.toStringAsFixed(2)}ms');
  print('p99: ${stats.p99.toStringAsFixed(2)}ms');
}

// Show debug dashboard (debug builds only)
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    content: SizedBox(
      width: 400,
      height: 600,
      child: AnalyticsDashboard(),
    ),
  ),
);
```

### Integration with Analytics Providers

#### Firebase Performance Monitoring

```dart
// In _sendPerformanceMetric:
void _sendPerformanceMetric(String name, double value, {Map<String, dynamic>? attributes}) {
  final trace = FirebasePerformance.instance.newTrace(name);
  trace.start();

  attributes?.forEach((key, value) {
    if (value is int) {
      trace.setMetric(key, value);
    }
  });

  trace.stop();
}
```

#### Custom Backend

```dart
void _sendPerformanceMetric(String name, double value, {Map<String, dynamic>? attributes}) {
  http.post(
    Uri.parse('https://api.example.com/metrics'),
    body: jsonEncode({
      'name': name,
      'value': value,
      'attributes': attributes,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'app_version': packageInfo.version,
    }),
  );
}
```

### Best Practices

1. ✅ Track critical user flows
2. ✅ Monitor startup time and first meaningful paint
3. ✅ Track error rates and types
4. ✅ Monitor frame drops and jank
5. ✅ Sample large-scale metrics (don't track every event)
6. ✅ Set up alerts for performance degradation
7. ❌ Don't track personally identifiable information (PII)
8. ❌ Don't send too much data (cost and privacy)
9. ❌ Don't block UI for analytics

---

## Testing Phase 5 Features

### 1. Test Memory Leak Detection

```dart
// Create a widget with intentional leak
class LeakyWidget extends StatefulWidget {
  @override
  State<LeakyWidget> createState() => _LeakyWidgetState();
}

class _LeakyWidgetState extends State<LeakyWidget> {
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Stream.periodic(Duration(seconds: 1)).listen((_) {});
    // BUG: Never cancel subscription!
  }

  // Missing dispose()
}

// Test: Navigate to this screen multiple times, then check for leaks
MemoryLeakDetector.instance.checkForLeaks();
// Should report the leak!
```

### 2. Test Startup Optimization

```dart
void main() async {
  AppStartupOptimizer.instance.recordAppStart();

  // ... initialization ...

  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppStartupOptimizer.instance.recordFirstFrame();
    AppStartupOptimizer.instance.printReport();

    // Should show:
    // - Time to first frame
    // - Initialization times
    // - Performance grade
  });

  runApp(MyApp());
}
```

### 3. Test Isolate Performance

```dart
void main() async {
  // Test with isolate
  final stopwatch1 = Stopwatch()..start();
  final result1 = await IsolateHelper.compute(
    heavyComputation,
    1000000,
    debugLabel: 'Heavy task',
  );
  print('With isolate: ${stopwatch1.elapsedMilliseconds}ms');

  // Test without isolate
  final stopwatch2 = Stopwatch()..start();
  final result2 = heavyComputation(1000000);
  print('Without isolate: ${stopwatch2.elapsedMilliseconds}ms');

  // Should see UI remain responsive with isolate
}
```

### 4. Test Performance Suite

```dart
void main() async {
  ExamplePerformanceTests.registerAll();

  final result = await PerformanceTestSuite.instance.runAll();

  print('Tests: ${result.totalTests}');
  print('Passed: ${result.passed}');
  print('Failed: ${result.failed}');
  print('Pass rate: ${(result.passRate * 100).toStringAsFixed(1)}%');
}
```

### 5. Test Production Analytics

```dart
void main() async {
  await ProductionAnalytics.instance.initialize();

  // Generate some test metrics
  for (var i = 0; i < 10; i++) {
    ProductionAnalytics.instance.logMetric('test_metric', i.toDouble());
  }

  // Check stats
  final stats = ProductionAnalytics.instance.getStats('test_metric');
  print(stats); // Should show avg, p95, p99, etc.
}
```

---

## Performance Metrics

### Before Phase 5

- **Startup time**: Unknown (not measured)
- **Memory leaks**: Undetected
- **Heavy computations**: Block UI thread
- **Performance regressions**: Discovered by users
- **Production metrics**: Not tracked

### After Phase 5

- **Startup time**: Measured and optimized (<500ms target)
- **Memory leaks**: Detected during development
- **Heavy computations**: Offloaded to isolates (UI stays responsive)
- **Performance regressions**: Caught by automated tests
- **Production metrics**: Tracked and analyzed

---

## Troubleshooting

### Memory Leaks Not Detected

1. Make sure you're calling `trackForLeaks()` or using `LeakTrackerMixin`
2. Check that `dispose()` is being called on your widgets
3. Run `checkForLeaks()` after navigating away from screen
4. Increase check interval for longer-lived leaks

### Startup Too Slow

1. Check what's in `initializeCritical()` - move non-critical to deferred
2. Use `printReport()` to see which services are slow
3. Consider lazy initialization for services
4. Preload only critical assets
5. Defer network requests to after first frame

### Isolate Not Helping Performance

1. Check if task is actually CPU-intensive (>100ms)
2. Measure overhead - isolate spawning costs ~100-200ms
3. Consider using pooled isolates for repeated tasks
4. Simplify message data (avoid complex objects)

### Performance Tests Flaky

1. Increase threshold to allow for variance
2. Use warning threshold (80% of max) for early detection
3. Run tests multiple times and average results
4. Consider environment factors (CI vs local)

### Analytics Not Sending

1. Check that `initialize()` was called
2. Implement `_sendPerformanceMetric()` with your provider
3. Verify network connectivity
4. Check debug logs for errors
5. Test with simple metric first

---

## Next Steps

1. ✅ Review all Phase 5 files
2. ✅ Add memory leak detection to critical widgets
3. ✅ Optimize app startup time
4. ✅ Identify CPU-intensive tasks for isolates
5. ✅ Set up automated performance tests in CI
6. ✅ Integrate production analytics with your provider
7. ✅ Monitor production metrics and set up alerts
8. ✅ Iterate based on real-world data

---

## Summary

Phase 5 provides enterprise-grade performance tools:

- **Memory Management**: Detect leaks before they reach production
- **Fast Startup**: Optimized cold start for better first impressions
- **Responsive UI**: Isolates keep UI smooth during heavy work
- **Quality Assurance**: Automated tests catch regressions early
- **Data-Driven**: Production metrics guide optimization efforts

These tools work together to create a production-ready, high-performance app that delights users and scales reliably.
