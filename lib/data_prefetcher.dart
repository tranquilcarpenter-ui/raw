import 'dart:async';
import 'package:flutter/foundation.dart';

/// Intelligent data prefetching system
///
/// PERFORMANCE: Preload data before user needs it for better perceived performance
/// - Predict user navigation patterns
/// - Preload data in background
/// - Cancel unnecessary prefetch operations
/// - Priority-based prefetching
class DataPrefetcher {
  static final DataPrefetcher _instance = DataPrefetcher._internal();
  static DataPrefetcher get instance => _instance;

  factory DataPrefetcher() => _instance;
  DataPrefetcher._internal();

  final Map<String, _PrefetchTask> _tasks = {};
  final Map<String, dynamic> _prefetchedData = {};
  int _nextPriority = 0;

  /// Prefetch data with a key
  ///
  /// If data is already prefetched or being fetched, returns existing future
  /// [priority] determines fetch order (higher = more important)
  Future<T?> prefetch<T>(
    String key,
    Future<T> Function() fetcher, {
    int priority = 0,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Check if already prefetched
    if (_prefetchedData.containsKey(key)) {
      if (kDebugMode) {
        debugPrint('✅ DataPrefetcher: Using cached prefetch for $key');
      }
      return _prefetchedData[key] as T?;
    }

    // Check if already being fetched
    if (_tasks.containsKey(key)) {
      if (kDebugMode) {
        debugPrint('⏳ DataPrefetcher: Waiting for existing prefetch $key');
      }
      return (_tasks[key]!.future as Future<T?>);
    }

    if (kDebugMode) {
      debugPrint('🔮 DataPrefetcher: Starting prefetch for $key (priority: $priority)');
    }

    // Start new prefetch
    final completer = Completer<T?>();
    _tasks[key] = _PrefetchTask(
      key: key,
      priority: priority,
      future: completer.future,
      startTime: DateTime.now(),
    );

    try {
      final data = await fetcher().timeout(timeout);
      _prefetchedData[key] = data;
      completer.complete(data);

      if (kDebugMode) {
        final duration = DateTime.now().difference(_tasks[key]!.startTime);
        debugPrint(
          '✅ DataPrefetcher: Completed $key in ${duration.inMilliseconds}ms',
        );
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DataPrefetcher: Failed to prefetch $key: $e');
      }
      completer.complete(null);
      return null;
    } finally {
      _tasks.remove(key);
    }
  }

  /// Get prefetched data if available, otherwise fetch it
  ///
  /// PERFORMANCE: Returns immediately if data was prefetched
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Check prefetched data
    if (_prefetchedData.containsKey(key)) {
      final data = _prefetchedData.remove(key) as T; // Remove after use
      if (kDebugMode) {
        debugPrint('⚡ DataPrefetcher: Instant return for $key (prefetched)');
      }
      return data;
    }

    // Check if currently prefetching
    if (_tasks.containsKey(key)) {
      if (kDebugMode) {
        debugPrint('⏳ DataPrefetcher: Waiting for prefetch of $key');
      }
      final result = await (_tasks[key]!.future as Future<T?>);
      if (result != null) {
        _prefetchedData.remove(key);
        return result;
      }
    }

    // Not prefetched, fetch now
    if (kDebugMode) {
      debugPrint('🔍 DataPrefetcher: Fetching $key (not prefetched)');
    }
    return await fetcher().timeout(timeout);
  }

  /// Prefetch multiple items with priorities
  ///
  /// PERFORMANCE: Higher priority items are fetched first
  Future<void> prefetchBatch(
    Map<String, Future<dynamic> Function()> fetchers, {
    Map<String, int>? priorities,
  }) async {
    if (kDebugMode) {
      debugPrint('🔮 DataPrefetcher: Batch prefetch ${fetchers.length} items');
    }

    // Sort by priority
    final sortedKeys = fetchers.keys.toList();
    if (priorities != null) {
      sortedKeys.sort((a, b) {
        final priorityA = priorities[a] ?? 0;
        final priorityB = priorities[b] ?? 0;
        return priorityB.compareTo(priorityA); // Higher priority first
      });
    }

    // Prefetch in order
    for (final key in sortedKeys) {
      unawaited(
        prefetch(
          key,
          fetchers[key]!,
          priority: priorities?[key] ?? 0,
        ),
      );
    }
  }

  /// Cancel a prefetch operation
  void cancel(String key) {
    _tasks.remove(key);
    _prefetchedData.remove(key);
    if (kDebugMode) {
      debugPrint('🚫 DataPrefetcher: Cancelled $key');
    }
  }

  /// Cancel all prefetch operations
  void cancelAll() {
    final count = _tasks.length;
    _tasks.clear();
    _prefetchedData.clear();
    if (kDebugMode) {
      debugPrint('🚫 DataPrefetcher: Cancelled all ($count tasks)');
    }
  }

  /// Clear cached prefetched data
  void clearCache() {
    final count = _prefetchedData.length;
    _prefetchedData.clear();
    if (kDebugMode) {
      debugPrint('🗑️ DataPrefetcher: Cleared cache ($count items)');
    }
  }

  /// Check if data is prefetched
  bool isPrefetched(String key) => _prefetchedData.containsKey(key);

  /// Check if currently prefetching
  bool isPrefetching(String key) => _tasks.containsKey(key);

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'cached_items': _prefetchedData.length,
      'active_tasks': _tasks.length,
      'cached_keys': _prefetchedData.keys.toList(),
      'active_keys': _tasks.keys.toList(),
    };
  }
}

class _PrefetchTask {
  final String key;
  final int priority;
  final Future<dynamic> future;
  final DateTime startTime;

  _PrefetchTask({
    required this.key,
    required this.priority,
    required this.future,
    required this.startTime,
  });
}

/// Common prefetch patterns for the app
class AppPrefetchPatterns {
  /// Prefetch user profile data when navigating to profile
  static Future<void> prefetchUserProfile(String userId) async {
    await DataPrefetcher.instance.prefetch(
      'user_profile_$userId',
      () async {
        // This would call your actual service
        // return await UserDataService.instance.loadUserData(userId);
        throw UnimplementedError('Implement with actual service call');
      },
      priority: 10,
    );
  }

  /// Prefetch friends list when user opens community tab
  static Future<void> prefetchFriendsList(String userId) async {
    await DataPrefetcher.instance.prefetch(
      'friends_list_$userId',
      () async {
        // return await FriendsService.instance.getFriends(userId);
        throw UnimplementedError('Implement with actual service call');
      },
      priority: 8,
    );
  }

  /// Prefetch achievements when user profile loads
  static Future<void> prefetchAchievements(String userId) async {
    await DataPrefetcher.instance.prefetch(
      'achievements_$userId',
      () async {
        // return await AchievementsService.instance.getUserAchievements(userId);
        throw UnimplementedError('Implement with actual service call');
      },
      priority: 5,
    );
  }

  /// Prefetch friend profile images
  static Future<void> prefetchFriendImages(List<String> imageUrls) async {
    // Images are handled by CachedNetworkImage and ImageCacheHelper
    // This is a placeholder for additional image prefetching logic
    if (kDebugMode) {
      debugPrint('🖼️ Prefetching ${imageUrls.length} friend images');
    }
  }
}

/// Extension for convenient prefetching
extension FuturePrefetchExtension<T> on Future<T> Function() {
  /// Prefetch this data with a key
  Future<T?> prefetch(String key, {int priority = 0}) {
    return DataPrefetcher.instance.prefetch(key, this, priority: priority);
  }

  /// Get prefetched data or fetch
  Future<T> getOrFetch(String key) {
    return DataPrefetcher.instance.getOrFetch(key, this);
  }
}
