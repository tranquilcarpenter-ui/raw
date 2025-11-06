# Performance Optimization Integration Examples

This document provides complete, copy-paste ready examples for integrating performance optimizations into your Flutter app.

## Table of Contents

1. [Main.dart Setup](#maindart-setup)
2. [Complete Screen Example](#complete-screen-example)
3. [Optimized Service Example](#optimized-service-example)
4. [List Screen with Lazy Loading](#list-screen-with-lazy-loading)
5. [Navigation with Prefetching](#navigation-with-prefetching)
6. [Performance Testing Setup](#performance-testing-setup)
7. [Production Analytics Integration](#production-analytics-integration)

---

## Main.dart Setup

Complete main.dart with all performance optimizations:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

// Phase 5 imports
import 'app_startup_optimizer.dart';
import 'memory_leak_detector.dart';
import 'production_analytics.dart';
import 'performance_monitor.dart';

void main() async {
  // Record app start time
  AppStartupOptimizer.instance.recordAppStart();

  WidgetsFlutterBinding.ensureInitialized();

  // Critical initialization only (blocks first frame)
  await AppStartupOptimizer.instance.initializeCritical();

  // Setup deferred tasks (will run after first frame)
  _setupDeferredTasks();

  // Initialize production analytics (production only)
  if (!kDebugMode) {
    await ProductionAnalytics.instance.initialize();
  }

  // Setup memory leak detection (debug only)
  if (kDebugMode) {
    _setupMemoryLeakDetection();
  }

  runApp(MyApp());

  // Initialize deferred services after first frame
  AppStartupOptimizer.instance.initializeDeferred();

  // Print startup report (debug only)
  if (kDebugMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppStartupOptimizer.instance.printReport();
      PerformanceMonitor.instance.printSummary();
    });
  }
}

void _setupDeferredTasks() {
  // High priority (run first after first frame)
  AppStartupOptimizer.instance.addDeferredTask(
    'Firebase Analytics',
    () async {
      // await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      debugPrint('Firebase Analytics initialized');
    },
    priority: 80,
  );

  // Medium priority
  AppStartupOptimizer.instance.addDeferredTask(
    'User Preferences',
    () async {
      // await SharedPreferences.getInstance();
      debugPrint('User Preferences initialized');
    },
    priority: 50,
  );

  // Low priority (run last)
  AppStartupOptimizer.instance.addDeferredTask(
    'Background Sync',
    () async {
      // await BackgroundSync.initialize();
      debugPrint('Background Sync initialized');
    },
    priority: 20,
  );
}

void _setupMemoryLeakDetection() {
  // Check for leaks every 5 minutes
  Timer.periodic(const Duration(minutes: 5), (_) {
    MemoryLeakDetector.instance.checkForLeaks();
  });

  // Monitor memory every 30 seconds
  MemoryMonitor.instance.startMonitoring(
    interval: const Duration(seconds: 30),
    warningThreshold: 200, // MB
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp(
      title: 'My Optimized App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );

    // Wrap with performance monitoring in debug mode
    if (kDebugMode) {
      app = PerformanceMonitoringWidget(
        sampleInterval: Duration(seconds: 10),
        child: app,
      );
    }

    return app;
  }
}
```

---

## Complete Screen Example

A fully optimized screen using all performance techniques:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Phase 2: Caching
import 'cache_manager.dart';

// Phase 3: Monitoring
import 'performance_monitor.dart';
import 'image_cache_helper.dart';

// Phase 4: Prefetching
import 'data_prefetcher.dart';

// Phase 5: Analytics and leak detection
import 'production_analytics.dart';
import 'memory_leak_detector.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with LeakTrackerMixin, StreamSubscriptionTracker {

  // Phase 2: Caching
  final _cache = CacheManager<UserProfile>();

  // Phase 4: Prefetching
  final _prefetcher = DataPrefetcher.instance;

  // Phase 3: Performance monitoring
  final _monitor = PerformanceMonitor.instance;

  UserProfile? _profile;
  bool _isLoading = true;

  // Phase 1: ValueNotifier for isolated updates
  late final ValueNotifier<int> _followersNotifier;

  @override
  void initState() {
    super.initState();

    // Phase 5: Track for memory leaks
    trackForLeaks();

    // Phase 1: Initialize notifiers
    _followersNotifier = ValueNotifier(0);

    // Load data
    _loadProfile();

    // Phase 4: Prefetch related data
    _prefetchRelatedData();

    // Phase 1: Track stream subscriptions
    trackSubscription(
      _listenToProfileUpdates(),
      name: 'profile_updates',
    );
  }

  Future<void> _loadProfile() async {
    // Phase 5: Track loading time
    ProductionAnalytics.instance.startTrace('load_profile');

    try {
      // Phase 3: Monitor performance
      final profile = await _monitor.timeAsync('loadProfile', () async {
        // Phase 2: Use cache
        return _cache.getOrFetch(widget.userId, () async {
          // Actual API call
          return await _fetchProfileFromServer(widget.userId);
        });
      });

      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
          _followersNotifier.value = profile?.followers ?? 0;
        });
      }

      // Phase 5: Stop trace
      ProductionAnalytics.instance.stopTrace('load_profile');
    } catch (e, st) {
      ProductionAnalytics.instance.stopTrace('load_profile');
      ProductionAnalytics.instance.logError(e.toString(), st);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _prefetchRelatedData() {
    // Phase 4: Prefetch data user might need next
    _prefetcher.prefetch('user_posts_${widget.userId}', () async {
      return await _fetchUserPosts(widget.userId);
    }, priority: 80);

    _prefetcher.prefetch('user_photos_${widget.userId}', () async {
      return await _fetchUserPhotos(widget.userId);
    }, priority: 50);
  }

  StreamSubscription _listenToProfileUpdates() {
    return Stream.periodic(Duration(seconds: 30)).listen((_) {
      // Refresh profile data every 30 seconds
      _cache.remove(widget.userId);
      _loadProfile();
    });
  }

  Future<UserProfile> _fetchProfileFromServer(String userId) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500));
    return UserProfile(
      id: userId,
      name: 'John Doe',
      followers: 1234,
      photoUrl: 'https://example.com/photo.jpg',
    );
  }

  Future<List<Post>> _fetchUserPosts(String userId) async {
    await Future.delayed(Duration(milliseconds: 300));
    return [];
  }

  Future<List<Photo>> _fetchUserPhotos(String userId) async {
    await Future.delayed(Duration(milliseconds: 300));
    return [];
  }

  void _navigateToPhotos() {
    // Phase 5: Track interaction
    InteractionTracker.instance.start('view_photos');

    // Phase 4: Data already prefetched - instant navigation!
    _prefetcher.getOrFetch('user_photos_${widget.userId}', () async {
      return await _fetchUserPhotos(widget.userId);
    }).then((photos) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotosScreen(photos: photos),
        ),
      );

      InteractionTracker.instance.end('view_photos');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Phase 5: Analytics wrapper
    return AnalyticsScreenWrapper(
      screenName: 'profile',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_profile?.name ?? 'Profile'),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _buildProfileContent(),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(),
          _buildFollowersSection(),
          _buildPhotosButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    // Phase 1: RepaintBoundary for expensive widget
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Phase 3: Optimized image loading
            ClipOval(
              child: ImageCacheHelper.buildImageFromPath(
                _profile!.photoUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '@${_profile!.id}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowersSection() {
    // Phase 1: ValueListenableBuilder for isolated updates
    return ValueListenableBuilder<int>(
      valueListenable: _followersNotifier,
      builder: (context, followers, child) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Posts', '42'),
              _buildStat('Followers', followers.toString()),
              _buildStat('Following', '156'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value) {
    // Phase 1: const constructor for performance
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildPhotosButton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _navigateToPhotos,
        child: Text('View Photos'),
      ),
    );
  }

  // dispose() handled by mixins
}

class UserProfile {
  final String id;
  final String name;
  final int followers;
  final String photoUrl;

  UserProfile({
    required this.id,
    required this.name,
    required this.followers,
    required this.photoUrl,
  });
}

class Post {}
class Photo {}
class PhotosScreen extends StatelessWidget {
  final List<Photo> photos;
  const PhotosScreen({Key? key, required this.photos}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold();
}
```

---

## Optimized Service Example

A complete service with all performance optimizations:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

// Phase 2: Caching
import 'cache_manager.dart';

// Phase 3: Monitoring
import 'performance_monitor.dart';

// Phase 5: Analytics
import 'production_analytics.dart';

class UserService {
  static final UserService instance = UserService._();
  UserService._();

  // Phase 2: Caching with request deduplication
  final _cache = CacheManager<User>(
    name: 'UserService',
    ttl: Duration(seconds: 30), // Testing-friendly
  );

  // Phase 3: Performance monitoring
  final _monitor = PerformanceMonitor.instance;

  /// Load user by ID (cached with deduplication)
  Future<User?> loadUser(String userId) async {
    // Phase 3: Monitor timing
    return _monitor.timeAsync('loadUser', () async {
      // Phase 2: Cache with deduplication
      return _cache.getOrFetch(userId, () async {
        // Phase 5: Track network request
        return NetworkTracker.track('/api/users/$userId', () async {
          // Simulate API call
          await Future.delayed(Duration(milliseconds: 100));

          if (kDebugMode) {
            debugPrint('📥 Fetched user $userId from server');
          }

          return User(
            id: userId,
            name: 'User $userId',
            email: 'user$userId@example.com',
          );
        });
      });
    });
  }

  /// Save user (invalidates cache)
  Future<void> saveUser(User user) async {
    // Phase 5: Track performance
    ProductionAnalytics.instance.startTrace('save_user');

    try {
      // Save to server
      await Future.delayed(Duration(milliseconds: 100));

      // Phase 2: Invalidate cache
      _cache.remove(user.id);

      if (kDebugMode) {
        debugPrint('💾 Saved user ${user.id}');
      }

      ProductionAnalytics.instance.stopTrace('save_user');
    } catch (e, st) {
      ProductionAnalytics.instance.stopTrace('save_user');
      ProductionAnalytics.instance.logError(e.toString(), st);
      rethrow;
    }
  }

  /// Load multiple users (batch request)
  Future<List<User>> loadUsers(List<String> userIds) async {
    // Check cache first
    final cachedUsers = <User>[];
    final uncachedIds = <String>[];

    for (final id in userIds) {
      final cached = _cache.get(id);
      if (cached != null) {
        cachedUsers.add(cached);
      } else {
        uncachedIds.add(id);
      }
    }

    // Fetch uncached users
    if (uncachedIds.isNotEmpty) {
      final fetchedUsers = await _fetchUsersFromServer(uncachedIds);

      // Cache fetched users
      for (final user in fetchedUsers) {
        _cache.set(user.id, user);
      }

      return [...cachedUsers, ...fetchedUsers];
    }

    return cachedUsers;
  }

  Future<List<User>> _fetchUsersFromServer(List<String> userIds) async {
    return NetworkTracker.track('/api/users/batch', () async {
      await Future.delayed(Duration(milliseconds: 200));
      return userIds.map((id) => User(
        id: id,
        name: 'User $id',
        email: 'user$id@example.com',
      )).toList();
    });
  }

  /// Invalidate cache for user
  void invalidateUser(String userId) {
    _cache.remove(userId);

    if (kDebugMode) {
      debugPrint('🗑️  Invalidated cache for user $userId');
    }
  }

  /// Clear all cached users
  void clearCache() {
    _cache.clear();

    if (kDebugMode) {
      debugPrint('🗑️  Cleared all user cache');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _cache.getStats();
  }

  /// Dispose service
  void dispose() {
    _cache.clear();
  }
}

class User {
  final String id;
  final String name;
  final String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });
}
```

---

## List Screen with Lazy Loading

Complete example using lazy loading for large lists:

```dart
import 'package:flutter/material.dart';

// Phase 4: Lazy loading
import 'lazy_loading_controller.dart';

// Phase 5: Analytics
import 'production_analytics.dart';

class LeaderboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnalyticsScreenWrapper(
      screenName: 'leaderboard',
      child: Scaffold(
        appBar: AppBar(title: Text('Leaderboard')),
        body: LazyLoadingListView<LeaderboardEntry>(
          fetchPage: _fetchLeaderboardPage,
          itemBuilder: (context, entry) => _buildLeaderboardTile(entry),
          pageSize: 20,
          loadingIndicator: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          emptyWidget: Center(
            child: Text('No entries found'),
          ),
          errorBuilder: (context, error) => Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }

  Future<List<LeaderboardEntry>> _fetchLeaderboardPage(
    int page,
    int pageSize,
  ) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 500));

    // Generate page of entries
    final startIndex = page * pageSize;
    return List.generate(pageSize, (index) {
      final rank = startIndex + index + 1;
      return LeaderboardEntry(
        rank: rank,
        name: 'Player $rank',
        score: 10000 - rank * 10,
      );
    });
  }

  Widget _buildLeaderboardTile(LeaderboardEntry entry) {
    // Phase 1: RepaintBoundary for list items
    return RepaintBoundary(
      key: ValueKey(entry.rank),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('#${entry.rank}'),
        ),
        title: Text(entry.name),
        trailing: Text(
          '${entry.score} pts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String name;
  final int score;

  LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
  });
}
```

---

## Navigation with Prefetching

Example showing instant navigation using prefetching:

```dart
import 'package:flutter/material.dart';

// Phase 4: Prefetching
import 'data_prefetcher.dart';

// Phase 5: Analytics
import 'production_analytics.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _prefetcher = DataPrefetcher.instance;

  @override
  void initState() {
    super.initState();
    _prefetchCommonScreens();
  }

  void _prefetchCommonScreens() {
    // Prefetch data for likely next screens
    _prefetcher.prefetch('user_profile', () async {
      return await _loadUserProfile();
    }, priority: 100);

    _prefetcher.prefetch('notifications', () async {
      return await _loadNotifications();
    }, priority: 80);

    _prefetcher.prefetch('settings', () async {
      return await _loadSettings();
    }, priority: 50);
  }

  Future<UserProfile> _loadUserProfile() async {
    await Future.delayed(Duration(milliseconds: 500));
    return UserProfile(name: 'John Doe', email: 'john@example.com');
  }

  Future<List<Notification>> _loadNotifications() async {
    await Future.delayed(Duration(milliseconds: 300));
    return [];
  }

  Future<Settings> _loadSettings() async {
    await Future.delayed(Duration(milliseconds: 200));
    return Settings();
  }

  void _navigateToProfile() {
    // Track interaction
    InteractionTracker.instance.start('navigate_profile');

    // Data already loaded - instant navigation!
    _prefetcher.getOrFetch('user_profile', _loadUserProfile).then((profile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(profile: profile),
        ),
      );

      InteractionTracker.instance.end('navigate_profile');
    });
  }

  void _navigateToNotifications() {
    InteractionTracker.instance.start('navigate_notifications');

    _prefetcher.getOrFetch('notifications', _loadNotifications).then((notifications) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationsScreen(notifications: notifications),
        ),
      );

      InteractionTracker.instance.end('navigate_notifications');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsScreenWrapper(
      screenName: 'home',
      child: Scaffold(
        appBar: AppBar(title: Text('Home')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _navigateToProfile,
                child: Text('View Profile'), // Instant!
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToNotifications,
                child: Text('Notifications'), // Instant!
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserProfile {
  final String name;
  final String email;
  UserProfile({required this.name, required this.email});
}

class Notification {}
class Settings {}
class ProfileDetailScreen extends StatelessWidget {
  final UserProfile profile;
  const ProfileDetailScreen({Key? key, required this.profile}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold();
}

class NotificationsScreen extends StatelessWidget {
  final List<Notification> notifications;
  const NotificationsScreen({Key? key, required this.notifications}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold();
}
```

---

## Performance Testing Setup

Complete test file with performance regression tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

// Phase 5: Performance testing
import 'performance_test_suite.dart';

void main() {
  group('Performance Tests', () {
    setUp(() {
      // Clear previous test results
      PerformanceTestSuite.instance.clear();
    });

    test('All performance tests pass', () async {
      // Register all tests
      _registerTests();

      // Run all tests
      final result = await PerformanceTestSuite.instance.runAll(
        stopOnFailure: false,
      );

      // Verify all passed
      expect(result.allPassed, true,
          reason: '${result.failed} tests failed');
    });

    test('Widget build times are under threshold', () async {
      PerformanceTestSuite.instance.registerTest(
        WidgetBuildTest(
          name: 'Build HomeScreen',
          widget: HomeScreen(),
          iterations: 100,
          thresholds: PerformanceThresholds.widget,
        ),
      );

      final result = await PerformanceTestSuite.instance.runTest('Build HomeScreen');
      expect(result!.passed, true);
    });

    test('Data loading meets performance targets', () async {
      PerformanceTestSuite.instance.registerTest(
        OperationTimingTest(
          name: 'Load User Data',
          operation: () async {
            await Future.delayed(Duration(milliseconds: 50));
          },
          iterations: 10,
          thresholds: const PerformanceThresholds(
            maxDuration: Duration(milliseconds: 100),
          ),
        ),
      );

      final result = await PerformanceTestSuite.instance.runTest('Load User Data');
      expect(result!.passed, true);
    });
  });
}

void _registerTests() {
  final suite = PerformanceTestSuite.instance;

  // Widget build tests
  suite.registerTest(WidgetBuildTest(
    name: 'Build HomeScreen',
    widget: HomeScreen(),
    iterations: 100,
  ));

  // Operation timing tests
  suite.registerTest(OperationTimingTest(
    name: 'Load User Data',
    operation: () async {
      await Future.delayed(Duration(milliseconds: 50));
    },
    iterations: 10,
    thresholds: const PerformanceThresholds(
      maxDuration: Duration(milliseconds: 100),
    ),
  ));

  // Memory tests
  suite.registerTest(MemoryUsageTest(
    name: 'Cache 1000 Items',
    scenario: () async {
      final cache = <int, String>{};
      for (var i = 0; i < 1000; i++) {
        cache[i] = 'Item $i' * 10;
      }
    },
  ));
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Home')),
    );
  }
}
```

---

## Production Analytics Integration

Firebase Analytics integration example:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'production_analytics.dart';

/// Extend ProductionAnalytics to integrate with Firebase
class FirebaseProductionAnalytics extends ProductionAnalytics {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;

  @override
  Future<void> initialize() async {
    await super.initialize();
    await _analytics.setAnalyticsCollectionEnabled(true);
  }

  @override
  void _sendPerformanceMetric(
    String name,
    double value, {
    Map<String, dynamic>? attributes,
  }) {
    // Send to Firebase Performance
    final trace = _performance.newTrace(name);
    trace.start();

    attributes?.forEach((key, val) {
      if (val is int) {
        trace.setMetric(key, val);
      }
    });

    trace.putMetric('value', value.toInt());
    trace.stop();
  }

  @override
  void _sendEvent(String name, Map<String, dynamic> parameters) {
    // Send to Firebase Analytics
    _analytics.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}

// Usage in main.dart:
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use Firebase-integrated analytics
  final analytics = FirebaseProductionAnalytics();
  await analytics.initialize();

  runApp(MyApp());
}
```

---

## Summary

These examples show how to integrate all 5 phases of performance optimizations:

- **Phase 1**: ValueNotifier, RepaintBoundary, const constructors
- **Phase 2**: CacheManager for request deduplication
- **Phase 3**: PerformanceMonitor, ImageCacheHelper
- **Phase 4**: LazyLoading, DataPrefetcher
- **Phase 5**: Memory leak detection, startup optimization, analytics

Copy and adapt these examples to your specific needs. Start with the basics (Phases 1-2) and gradually add advanced features (Phases 3-5) as needed.
