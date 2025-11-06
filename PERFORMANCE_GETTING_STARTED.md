# Performance Optimization - Getting Started Guide

Welcome! This guide will help you integrate all performance optimizations into your Flutter app.

## Quick Start (5 Minutes)

### 1. Initialize in main.dart

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Phase 5 imports
import 'app_startup_optimizer.dart';
import 'memory_leak_detector.dart';
import 'production_analytics.dart';

void main() async {
  // Record app start time
  AppStartupOptimizer.instance.recordAppStart();

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize critical services only
  await AppStartupOptimizer.instance.initializeCritical();

  // Setup deferred tasks
  AppStartupHelper.setupCommonDeferredTasks();

  // Initialize production analytics
  if (!kDebugMode) {
    await ProductionAnalytics.instance.initialize();
  }

  // Setup memory leak detection (debug only)
  if (kDebugMode) {
    Timer.periodic(const Duration(minutes: 5), (_) {
      MemoryLeakDetector.instance.checkForLeaks();
    });
  }

  runApp(MyApp());

  // Initialize deferred services after first frame
  AppStartupOptimizer.instance.initializeDeferred();

  // Print startup report (debug only)
  if (kDebugMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupOptimizer.instance.printReport();
    });
  }
}
```

### 2. Wrap Your App

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: kDebugMode
          ? PerformanceMonitoringWidget(
              child: HomePage(),
            )
          : HomePage(),
    );
  }
}
```

### 3. Track Your Screens

```dart
class HomePage extends StatelessWidget {
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
```

**That's it!** You now have basic performance tracking. Read on for advanced optimizations.

---

## Phase-by-Phase Integration

### Phase 1: Widget Optimization

#### Fix Timer Rebuilds

**Before:**
```dart
class FocusScreen extends StatefulWidget {
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _remainingSeconds = 1500;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {  // ❌ Rebuilds entire widget tree!
        _remainingSeconds--;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${_remainingSeconds ~/ 60}:${_remainingSeconds % 60}'),
        // ... rest of screen
      ],
    );
  }
}
```

**After:**
```dart
class _FocusScreenState extends State<FocusScreen> {
  late final ValueNotifier<int> _remainingSecondsNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSecondsNotifier = ValueNotifier(1500);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSecondsNotifier.value--;  // ✅ Only rebuilds listener!
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _remainingSecondsNotifier,
          builder: (context, seconds, child) {
            return Text('${seconds ~/ 60}:${seconds % 60}');
          },
        ),
        // ... rest of screen (doesn't rebuild)
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingSecondsNotifier.dispose();
    super.dispose();
  }
}
```

**Impact:** 91% reduction in rebuilds

#### Add RepaintBoundary

```dart
Widget _buildAchievementCard(Achievement achievement) {
  return RepaintBoundary(  // ✅ Isolates repaints
    child: Container(
      child: AppCard(
        // ... card content
      ),
    ),
  );
}
```

**When to use:**
- Complex widgets that don't change often
- List items
- Cards
- Custom painters

#### Remove shrinkWrap

**Before:**
```dart
ListView(
  shrinkWrap: true,  // ❌ Expensive!
  children: items.map((item) => ItemWidget(item)).toList(),
)
```

**After:**
```dart
ListView(
  children: items.map((item) => ItemWidget(item)).toList(),
)
```

---

### Phase 2: Caching and Request Deduplication

#### Add Caching to Services

```dart
import 'cache_manager.dart';

class UserDataService {
  final _cache = CacheManager<UserData>(
    name: 'UserDataService',
    ttl: const Duration(seconds: 30),  // Testing-friendly
  );

  Future<UserData?> loadUserData(String userId) async {
    return _cache.getOrFetch(userId, () async {
      // Actual Firestore fetch
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      return doc.exists ? UserData.fromMap(doc.data()!) : null;
    });
  }

  Future<void> saveUserData(String userId, UserData userData) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .set(userData.toMap());

    _cache.remove(userId);  // Invalidate cache
  }
}
```

**Impact:** 50-60% reduction in Firebase reads

#### Cache Invalidation Patterns

```dart
// Pattern 1: Remove specific item
_cache.remove(userId);

// Pattern 2: Clear entire cache
_cache.clear();

// Pattern 3: Clear by prefix (if using namespaced keys)
void invalidateUserCache(String userId) {
  _cache.remove('user_$userId');
  _cache.remove('user_stats_$userId');
  _cache.remove('user_achievements_$userId');
}
```

---

### Phase 3: Monitoring and Tooling

#### Add Performance Monitoring

```dart
import 'performance_monitor.dart';

class MyService {
  final _monitor = PerformanceMonitor.instance;

  Future<void> loadData() async {
    await _monitor.timeAsync('loadData', () async {
      // Your data loading logic
    });

    // Check stats later
    final stats = _monitor.getStats('loadData');
    if (stats != null) {
      debugPrint('Avg: ${stats['avg']}ms');
      debugPrint('p95: ${stats['p95']}ms');
    }
  }
}
```

#### Optimize Image Loading

```dart
import 'image_cache_helper.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ImageCacheHelper.buildImageFromPath(
      imagePath,
      width: 100,
      height: 100,
      fit: BoxFit.cover,
    );
  }
}
```

---

### Phase 4: Lazy Loading and Prefetching

#### Add Lazy Loading to Lists

**Before:**
```dart
class LeaderboardScreen extends StatefulWidget {
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<User> users = [];

  @override
  void initState() {
    super.initState();
    _loadAllUsers();  // ❌ Loads all 10,000 users at once!
  }

  Future<void> _loadAllUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .get();

    setState(() {
      users = snapshot.docs.map((doc) => User.fromMap(doc.data())).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) => UserTile(users[index]),
    );
  }
}
```

**After:**
```dart
import 'lazy_loading_controller.dart';

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    return LazyLoadingListView<User>(  // ✅ Loads 20 items at a time
      fetchPage: (page, pageSize) async {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .orderBy('score', descending: true)
            .limit(pageSize)
            .startAfter(page * pageSize)
            .get();

        return snapshot.docs
            .map((doc) => User.fromMap(doc.data()))
            .toList();
      },
      itemBuilder: (context, user) => UserTile(user),
      pageSize: 20,
      loadingIndicator: CircularProgressIndicator(),
    );
  }
}
```

**Impact:** 96% reduction in initial memory usage and load time

#### Add Data Prefetching

```dart
import 'data_prefetcher.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefetcher = DataPrefetcher.instance;

  @override
  void initState() {
    super.initState();

    // Prefetch data user will likely need
    _prefetcher.prefetch('user_profile', () async {
      return await UserService.loadUserData(userId);
    }, priority: 100);

    _prefetcher.prefetch('leaderboard', () async {
      return await LeaderboardService.loadTopUsers();
    }, priority: 50);
  }

  void _navigateToProfile() {
    // Data already loaded - instant navigation!
    _prefetcher.getOrFetch('user_profile', () async {
      return await UserService.loadUserData(userId);
    }).then((data) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(data)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _navigateToProfile,
            child: Text('View Profile'),  // ✅ Instant!
          ),
        ],
      ),
    );
  }
}
```

**Impact:** 96% faster perceived navigation

#### Use Firebase Batch Operations

```dart
import 'firebase_batch_helper.dart';

Future<void> updateMultipleUsers(List<User> users) async {
  final operations = users.map((user) {
    return BatchOperation.update(
      FirebaseFirestore.instance.collection('users').doc(user.id),
      user.toMap(),
    );
  }).toList();

  await FirebaseBatchHelper.instance.executeBatch(operations);
}
```

---

### Phase 5: Memory, Startup, and Production

#### Detect Memory Leaks

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with LeakTrackerMixin {
  @override
  void initState() {
    super.initState();
    trackForLeaks();  // ✅ Auto-detects if widget isn't disposed
  }
}
```

#### Offload Heavy Work to Isolates

```dart
import 'isolate_helper.dart';

Future<void> processLargeDataset() async {
  // ❌ Blocks UI thread
  // final result = parseHugeJson(jsonString);

  // ✅ Keeps UI responsive
  final result = await IsolateHelper.compute(
    _parseJsonInBackground,
    jsonString,
    debugLabel: 'Parse user data',
  );
}

// Must be top-level or static function
dynamic _parseJsonInBackground(String json) {
  return jsonDecode(json);
}
```

#### Add Performance Tests

```dart
// In test/performance_test.dart
void main() {
  test('HomeScreen builds quickly', () async {
    final suite = PerformanceTestSuite.instance;

    suite.registerTest(WidgetBuildTest(
      name: 'Build HomeScreen',
      widget: HomeScreen(),
      iterations: 100,
      thresholds: PerformanceThresholds.widget,  // 16ms
    ));

    final result = await suite.runAll();
    expect(result.allPassed, true);
  });
}
```

---

## Common Integration Patterns

### Pattern 1: Complete Screen Setup

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Imports
import 'production_analytics.dart';
import 'cache_manager.dart';
import 'data_prefetcher.dart';

class OptimizedScreen extends StatefulWidget {
  @override
  State<OptimizedScreen> createState() => _OptimizedScreenState();
}

class _OptimizedScreenState extends State<OptimizedScreen>
    with LeakTrackerMixin, StreamSubscriptionTracker {

  final _cache = CacheManager<Data>();
  final _prefetcher = DataPrefetcher.instance;

  @override
  void initState() {
    super.initState();

    // Phase 5: Track for memory leaks
    trackForLeaks();

    // Phase 2: Load with caching
    _loadData();

    // Phase 4: Prefetch next screen
    _prefetcher.prefetch('next_screen', _loadNextScreenData);

    // Phase 1: Track subscriptions
    trackSubscription(
      someStream.listen(_handleData),
      name: 'data_stream',
    );
  }

  Future<void> _loadData() async {
    // Phase 5: Track performance
    ProductionAnalytics.instance.startTrace('load_data');

    try {
      // Phase 2: Use cache
      final data = await _cache.getOrFetch('key', () async {
        return await _fetchFromServer();
      });

      setState(() {
        // Update UI
      });

      ProductionAnalytics.instance.stopTrace('load_data');
    } catch (e) {
      ProductionAnalytics.instance.stopTrace('load_data');
      ProductionAnalytics.instance.logError(e.toString(), StackTrace.current);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 5: Analytics wrapper
    return AnalyticsScreenWrapper(
      screenName: 'optimized',
      child: Scaffold(
        appBar: AppBar(title: Text('Optimized Screen')),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Phase 4: Lazy loading list
    return LazyLoadingListView<Item>(
      fetchPage: _fetchPage,
      itemBuilder: (context, item) => _buildItem(item),
      pageSize: 20,
    );
  }

  Widget _buildItem(Item item) {
    // Phase 1: RepaintBoundary
    return RepaintBoundary(
      child: ItemWidget(item),
    );
  }

  // dispose() handled by mixins
}
```

### Pattern 2: Service with Full Optimization

```dart
import 'cache_manager.dart';
import 'performance_monitor.dart';
import 'production_analytics.dart';

class OptimizedService {
  static final OptimizedService instance = OptimizedService._();
  OptimizedService._();

  // Phase 2: Caching
  final _cache = CacheManager<Data>(
    name: 'OptimizedService',
    ttl: Duration(seconds: 30),
  );

  // Phase 3: Monitoring
  final _monitor = PerformanceMonitor.instance;

  Future<Data?> loadData(String id) async {
    // Phase 3: Monitor timing
    return _monitor.timeAsync('loadData', () async {
      // Phase 2: Cache with deduplication
      return _cache.getOrFetch(id, () async {
        // Phase 5: Track network request
        return NetworkTracker.track('/api/data/$id', () async {
          final response = await http.get(
            Uri.parse('$baseUrl/api/data/$id'),
          );

          if (response.statusCode == 200) {
            return Data.fromJson(jsonDecode(response.body));
          }
          return null;
        });
      });
    });
  }

  Future<void> saveData(String id, Data data) async {
    await http.post(
      Uri.parse('$baseUrl/api/data/$id'),
      body: jsonEncode(data.toJson()),
    );

    // Phase 2: Invalidate cache
    _cache.remove(id);
  }

  void dispose() {
    _cache.clear();
  }
}
```

---

## Performance Checklist

Use this checklist to ensure you've covered all optimizations:

### Phase 1: Widget Optimization
- [ ] Timer widgets use ValueNotifier instead of setState
- [ ] Complex widgets wrapped in RepaintBoundary
- [ ] Removed shrinkWrap from lists
- [ ] List items have keys
- [ ] No unnecessary rebuilds

### Phase 2: Caching
- [ ] Services use CacheManager
- [ ] Cache TTL appropriate for testing (30s)
- [ ] Cache invalidation on data changes
- [ ] Request deduplication working

### Phase 3: Monitoring
- [ ] Performance monitoring on critical operations
- [ ] Images use ImageCacheHelper
- [ ] Debug mode guards on logging
- [ ] Performance documentation exists

### Phase 4: Lazy Loading
- [ ] Large lists use LazyLoadingListView
- [ ] Next screens prefetch data
- [ ] Batch operations for bulk updates
- [ ] Adaptive performance based on connection

### Phase 5: Advanced
- [ ] App startup optimized (<500ms)
- [ ] Memory leak detection active (debug)
- [ ] Heavy work offloaded to isolates
- [ ] Performance tests in CI/CD
- [ ] Production analytics integrated

---

## Troubleshooting

### "Cache is too aggressive, I can't see my changes!"

**Solution:** Reduce TTL during active development
```dart
final _cache = CacheManager<Data>(
  ttl: Duration(seconds: 10),  // Shorter for testing
);
```

### "Isolate overhead is worse than direct execution"

**Solution:** Only use for truly heavy work (>100ms)
```dart
// ❌ Too small for isolate
await IsolateHelper.compute(_addNumbers, [1, 2]);

// ✅ Good use case
await IsolateHelper.compute(_parseHugeJson, largeJsonString);
```

### "Performance tests are flaky"

**Solution:** Increase thresholds or add tolerance
```dart
PerformanceThresholds(
  maxDuration: Duration(milliseconds: 20),  // Add margin
  warningMultiplier: 0.7,  // Earlier warnings
)
```

### "Memory leaks not detected"

**Solution:** Ensure you're using the mixin
```dart
class _MyState extends State<MyWidget>
    with LeakTrackerMixin {  // ✅ Add this

  @override
  void initState() {
    super.initState();
    trackForLeaks();  // ✅ Call this
  }
}
```

---

## What's Next?

1. **Start Small**: Add Phase 1 optimizations first
2. **Measure**: Use monitoring to find bottlenecks
3. **Iterate**: Add phases 2-5 based on needs
4. **Test**: Run performance tests regularly
5. **Monitor**: Track production metrics
6. **Optimize**: Use data to guide improvements

## Resources

- **PERFORMANCE.md**: Comprehensive optimization guide
- **PHASE4_GUIDE.md**: Lazy loading and prefetching
- **PHASE5_GUIDE.md**: Memory, startup, and analytics
- **OPTIMIZATION_SUMMARY.md**: Metrics and impact

---

## Quick Reference

### Import Cheat Sheet

```dart
// Phase 1
// (No imports - standard Flutter)

// Phase 2
import 'cache_manager.dart';

// Phase 3
import 'performance_monitor.dart';
import 'image_cache_helper.dart';

// Phase 4
import 'lazy_loading_controller.dart';
import 'data_prefetcher.dart';
import 'firebase_batch_helper.dart';
import 'connection_manager.dart';

// Phase 5
import 'memory_leak_detector.dart';
import 'app_startup_optimizer.dart';
import 'isolate_helper.dart';
import 'performance_test_suite.dart';
import 'production_analytics.dart';
```

### Performance Targets

| Metric | Excellent | Good | Needs Work |
|--------|-----------|------|------------|
| Startup time | <500ms | 500-1000ms | >1000ms |
| Frame time | <16ms (60fps) | <33ms (30fps) | >33ms |
| Screen load | <300ms | 300-1000ms | >1000ms |
| Cache hit rate | >70% | 50-70% | <50% |
| Memory growth | <50MB/hr | 50-100MB/hr | >100MB/hr |

---

Happy optimizing! 🚀
