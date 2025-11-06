import 'dart:async';
import 'package:flutter/foundation.dart';

/// Connection state manager for adaptive performance
///
/// PERFORMANCE: Adjust caching and prefetching based on network quality
/// - Longer cache TTLs on slow connections
/// - Disable prefetching on poor connections
/// - Batch operations more aggressively
class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  static ConnectionManager get instance => _instance;

  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  ConnectionQuality _currentQuality = ConnectionQuality.good;
  final _qualityController = StreamController<ConnectionQuality>.broadcast();

  /// Stream of connection quality changes
  Stream<ConnectionQuality> get qualityStream => _qualityController.stream;

  /// Current connection quality
  ConnectionQuality get quality => _currentQuality;

  /// Update connection quality
  void updateQuality(ConnectionQuality quality) {
    if (_currentQuality != quality) {
      _currentQuality = quality;
      _qualityController.add(quality);

      if (kDebugMode) {
        debugPrint('📡 ConnectionManager: Quality changed to ${quality.name}');
      }
    }
  }

  /// Check if connection is good enough for prefetching
  bool get shouldPrefetch => _currentQuality.index >= ConnectionQuality.good.index;

  /// Check if connection is good enough for high-quality images
  bool get shouldLoadHighQualityImages =>
      _currentQuality.index >= ConnectionQuality.good.index;

  /// Get recommended cache TTL based on connection quality
  Duration get recommendedCacheTTL {
    switch (_currentQuality) {
      case ConnectionQuality.excellent:
        return const Duration(seconds: 30); // Shorter TTL, fast refresh
      case ConnectionQuality.good:
        return const Duration(seconds: 60); // Standard TTL
      case ConnectionQuality.fair:
        return const Duration(minutes: 2); // Longer TTL, reduce requests
      case ConnectionQuality.poor:
        return const Duration(minutes: 5); // Very long TTL
      case ConnectionQuality.offline:
        return const Duration(hours: 1); // Keep cached data as long as possible
    }
  }

  /// Get recommended batch size for operations
  int get recommendedBatchSize {
    switch (_currentQuality) {
      case ConnectionQuality.excellent:
      case ConnectionQuality.good:
        return 50; // Large batches are fine
      case ConnectionQuality.fair:
        return 25; // Medium batches
      case ConnectionQuality.poor:
        return 10; // Small batches
      case ConnectionQuality.offline:
        return 1; // No batching (will likely fail anyway)
    }
  }

  /// Get recommended prefetch count
  int get recommendedPrefetchCount {
    switch (_currentQuality) {
      case ConnectionQuality.excellent:
        return 10; // Aggressive prefetching
      case ConnectionQuality.good:
        return 5; // Moderate prefetching
      case ConnectionQuality.fair:
        return 2; // Minimal prefetching
      case ConnectionQuality.poor:
      case ConnectionQuality.offline:
        return 0; // No prefetching
    }
  }

  /// Get image quality multiplier (for cache dimensions)
  double get imageQualityMultiplier {
    switch (_currentQuality) {
      case ConnectionQuality.excellent:
      case ConnectionQuality.good:
        return 1.0; // Full quality
      case ConnectionQuality.fair:
        return 0.75; // Reduced quality
      case ConnectionQuality.poor:
        return 0.5; // Low quality
      case ConnectionQuality.offline:
        return 0.5; // Low quality (cached)
    }
  }

  /// Measure connection quality based on operation latency
  ///
  /// Call this after network operations to update quality estimate
  void measureLatency(Duration latency) {
    final ms = latency.inMilliseconds;

    ConnectionQuality newQuality;
    if (ms < 100) {
      newQuality = ConnectionQuality.excellent;
    } else if (ms < 300) {
      newQuality = ConnectionQuality.good;
    } else if (ms < 1000) {
      newQuality = ConnectionQuality.fair;
    } else if (ms < 3000) {
      newQuality = ConnectionQuality.poor;
    } else {
      newQuality = ConnectionQuality.poor;
    }

    // Smooth the quality changes (don't jump immediately)
    if (newQuality.index < _currentQuality.index - 1) {
      // Connection degraded significantly
      updateQuality(newQuality);
    } else if (newQuality.index > _currentQuality.index) {
      // Connection improved (be more conservative)
      final improved = ConnectionQuality.values[_currentQuality.index + 1];
      updateQuality(improved);
    }
  }

  /// Mark connection as offline
  void setOffline() {
    updateQuality(ConnectionQuality.offline);
  }

  /// Mark connection as online
  void setOnline() {
    if (_currentQuality == ConnectionQuality.offline) {
      updateQuality(ConnectionQuality.good); // Default to good when coming back online
    }
  }

  void dispose() {
    _qualityController.close();
  }
}

/// Connection quality levels
enum ConnectionQuality {
  offline,
  poor,
  fair,
  good,
  excellent;

  /// Get user-friendly description
  String get description {
    switch (this) {
      case ConnectionQuality.offline:
        return 'Offline';
      case ConnectionQuality.poor:
        return 'Poor connection';
      case ConnectionQuality.fair:
        return 'Fair connection';
      case ConnectionQuality.good:
        return 'Good connection';
      case ConnectionQuality.excellent:
        return 'Excellent connection';
    }
  }

  /// Get color indicator
  Color get color {
    switch (this) {
      case ConnectionQuality.offline:
        return const Color(0xFF8E8E93); // Gray
      case ConnectionQuality.poor:
        return const Color(0xFFFF3B30); // Red
      case ConnectionQuality.fair:
        return const Color(0xFFFF9500); // Orange
      case ConnectionQuality.good:
        return const Color(0xFF30D158); // Green
      case ConnectionQuality.excellent:
        return const Color(0xFF30D158); // Green
    }
  }
}

/// Helper to time network operations and update connection quality
extension FutureLatencyExtension<T> on Future<T> {
  /// Time this future and update connection quality
  Future<T> measureLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await this;
      ConnectionManager.instance.measureLatency(stopwatch.elapsed);
      return result;
    } catch (e) {
      // On error, assume poor connection
      ConnectionManager.instance.updateQuality(ConnectionQuality.poor);
      rethrow;
    }
  }
}

/// Adaptive performance settings based on connection
class AdaptivePerformanceSettings {
  /// Get cache TTL adapted to connection quality
  static Duration getCacheTTL({Duration? defaultTTL}) {
    final connectionTTL = ConnectionManager.instance.recommendedCacheTTL;
    if (defaultTTL == null) return connectionTTL;

    // Use the longer of the two (be more conservative on poor connections)
    return connectionTTL > defaultTTL ? connectionTTL : defaultTTL;
  }

  /// Check if we should prefetch data
  static bool shouldPrefetch() {
    return ConnectionManager.instance.shouldPrefetch;
  }

  /// Get image cache dimensions adapted to connection
  static int? getAdaptiveImageDimension(double? dimension) {
    if (dimension == null) return null;

    final multiplier = ConnectionManager.instance.imageQualityMultiplier;
    final result = dimension * multiplier;

    if (!result.isFinite || result <= 0 || result > 10000) return null;
    return result.round();
  }

  /// Get recommended list page size
  static int getListPageSize({int defaultSize = 20}) {
    switch (ConnectionManager.instance.quality) {
      case ConnectionQuality.excellent:
      case ConnectionQuality.good:
        return defaultSize;
      case ConnectionQuality.fair:
        return (defaultSize * 0.75).round();
      case ConnectionQuality.poor:
        return (defaultSize * 0.5).round();
      case ConnectionQuality.offline:
        return 0; // Don't try to load more
    }
  }

  /// Check if we should show warning about connection quality
  static bool shouldShowConnectionWarning() {
    return ConnectionManager.instance.quality.index <= ConnectionQuality.fair.index;
  }
}

/// Example integration with Firebase operations
class AdaptiveFirebaseHelper {
  /// Load data with adaptive timeout based on connection
  static Future<T> loadWithAdaptiveTimeout<T>(
    Future<T> Function() operation,
  ) async {
    final timeout = _getAdaptiveTimeout();
    return await operation().timeout(timeout);
  }

  static Duration _getAdaptiveTimeout() {
    switch (ConnectionManager.instance.quality) {
      case ConnectionQuality.excellent:
      case ConnectionQuality.good:
        return const Duration(seconds: 10);
      case ConnectionQuality.fair:
        return const Duration(seconds: 15);
      case ConnectionQuality.poor:
        return const Duration(seconds: 30);
      case ConnectionQuality.offline:
        return const Duration(seconds: 5); // Fail fast
    }
  }
}
