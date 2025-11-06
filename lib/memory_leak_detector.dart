import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Memory leak detector for identifying retained objects
///
/// PERFORMANCE: Detect and prevent memory leaks in production
/// - Track widget lifecycle
/// - Monitor disposable objects
/// - Detect retained listeners
/// - Alert on potential leaks
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  static MemoryLeakDetector get instance => _instance;

  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  final Map<String, _TrackedObject> _trackedObjects = {};
  final Map<String, int> _leakCounts = {};
  Timer? _cleanupTimer;
  bool _isEnabled = kDebugMode; // Only run in debug by default

  /// Enable/disable leak detection
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (enabled && _cleanupTimer == null) {
      _startCleanupTimer();
    } else if (!enabled && _cleanupTimer != null) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  /// Track a disposable object
  ///
  /// Call this in initState/constructor
  void track(Object object, String name) {
    if (!_isEnabled) return;

    final key = '${object.runtimeType}_${object.hashCode}';
    _trackedObjects[key] = _TrackedObject(
      object: object,
      name: name,
      createdAt: DateTime.now(),
      stackTrace: StackTrace.current,
    );

    if (kDebugMode) {
      debugPrint('🔍 MemoryLeakDetector: Tracking $name');
    }
  }

  /// Untrack an object (call in dispose)
  void untrack(Object object) {
    if (!_isEnabled) return;

    final key = '${object.runtimeType}_${object.hashCode}';
    final tracked = _trackedObjects.remove(key);

    if (tracked != null && kDebugMode) {
      final lifetime = DateTime.now().difference(tracked.createdAt);
      debugPrint(
        '✅ MemoryLeakDetector: Untracked ${tracked.name} (lived ${lifetime.inSeconds}s)',
      );
    }
  }

  /// Check for potential leaks (objects alive too long)
  void checkForLeaks({Duration threshold = const Duration(minutes: 5)}) {
    if (!_isEnabled) return;

    final now = DateTime.now();
    final potentialLeaks = <String>[];

    for (final entry in _trackedObjects.entries) {
      final lifetime = now.difference(entry.value.createdAt);
      if (lifetime > threshold) {
        potentialLeaks.add(entry.value.name);
        _leakCounts[entry.value.name] = (_leakCounts[entry.value.name] ?? 0) + 1;
      }
    }

    if (potentialLeaks.isNotEmpty) {
      debugPrint('⚠️ MEMORY LEAK WARNING: ${potentialLeaks.length} objects alive > ${threshold.inMinutes}min');
      for (final leak in potentialLeaks) {
        debugPrint('   - $leak (detected ${_leakCounts[leak]} times)');
      }
    }
  }

  /// Get leak statistics
  Map<String, dynamic> getStats() {
    return {
      'tracked_objects': _trackedObjects.length,
      'leak_counts': Map.from(_leakCounts),
      'is_enabled': _isEnabled,
    };
  }

  /// Print detailed leak report
  void printLeakReport() {
    if (_trackedObjects.isEmpty) {
      debugPrint('✅ MemoryLeakDetector: No tracked objects (all cleaned up)');
      return;
    }

    debugPrint('\n🔍 ===== MEMORY LEAK REPORT =====');
    debugPrint('Tracked objects: ${_trackedObjects.length}');

    final sortedObjects = _trackedObjects.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final obj in sortedObjects) {
      final lifetime = DateTime.now().difference(obj.createdAt);
      debugPrint(
        '${obj.name}: ${lifetime.inSeconds}s (${obj.object.runtimeType})',
      );
    }

    if (_leakCounts.isNotEmpty) {
      debugPrint('\n⚠️  Repeated leaks:');
      for (final entry in _leakCounts.entries) {
        debugPrint('   ${entry.key}: ${entry.value} times');
      }
    }

    debugPrint('================================\n');
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      checkForLeaks();
    });
  }

  /// Clear all tracking (for testing)
  void clear() {
    _trackedObjects.clear();
    _leakCounts.clear();
  }

  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _trackedObjects.clear();
    _leakCounts.clear();
  }
}

class _TrackedObject {
  final Object object;
  final String name;
  final DateTime createdAt;
  final StackTrace stackTrace;

  _TrackedObject({
    required this.object,
    required this.name,
    required this.createdAt,
    required this.stackTrace,
  });
}

/// Mixin for automatic leak tracking in StatefulWidgets
///
/// Usage:
/// ```dart
/// class MyWidget extends StatefulWidget {
///   const MyWidget({super.key});
///
///   @override
///   State<MyWidget> createState() => _MyWidgetState();
/// }
///
/// class _MyWidgetState extends State<MyWidget> with LeakTrackerMixin {
///   @override
///   void initState() {
///     super.initState();
///     trackForLeaks(); // Automatically track this widget
///   }
/// }
/// ```
mixin LeakTrackerMixin<T extends StatefulWidget> on State<T> {
  bool _isTracked = false;

  /// Track this widget for memory leaks
  void trackForLeaks() {
    if (!_isTracked) {
      MemoryLeakDetector.instance.track(this, widget.runtimeType.toString());
      _isTracked = true;
    }
  }

  @override
  void dispose() {
    if (_isTracked) {
      MemoryLeakDetector.instance.untrack(this);
    }
    super.dispose();
  }
}

/// Helper for tracking StreamSubscriptions
class StreamSubscriptionTracker {
  final List<StreamSubscription> _subscriptions = [];
  final String _owner;

  StreamSubscriptionTracker(this._owner);

  /// Add a subscription to track
  void add(StreamSubscription subscription) {
    _subscriptions.add(subscription);
    if (kDebugMode) {
      debugPrint('📡 StreamTracker[$_owner]: Added subscription (total: ${_subscriptions.length})');
    }
  }

  /// Cancel all subscriptions
  Future<void> cancelAll() async {
    if (kDebugMode) {
      debugPrint('🚫 StreamTracker[$_owner]: Cancelling ${_subscriptions.length} subscriptions');
    }

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Check if all subscriptions are cancelled
  bool get hasActiveSubscriptions => _subscriptions.isNotEmpty;

  int get activeCount => _subscriptions.length;
}

/// Helper for tracking listeners
class ListenerTracker {
  final Map<String, int> _listenerCounts = {};
  final String _owner;

  ListenerTracker(this._owner);

  /// Record adding a listener
  void addListener(String listenerType) {
    _listenerCounts[listenerType] = (_listenerCounts[listenerType] ?? 0) + 1;
    if (kDebugMode) {
      debugPrint('👂 ListenerTracker[$_owner]: Added $listenerType (count: ${_listenerCounts[listenerType]})');
    }
  }

  /// Record removing a listener
  void removeListener(String listenerType) {
    final count = _listenerCounts[listenerType] ?? 0;
    if (count > 0) {
      _listenerCounts[listenerType] = count - 1;
      if (kDebugMode) {
        debugPrint('🚫 ListenerTracker[$_owner]: Removed $listenerType (count: ${_listenerCounts[listenerType]})');
      }
    } else {
      debugPrint('⚠️  ListenerTracker[$_owner]: Tried to remove $listenerType but count is 0');
    }
  }

  /// Check for unreleased listeners
  bool get hasUnreleasedListeners {
    return _listenerCounts.values.any((count) => count > 0);
  }

  /// Get report of unreleased listeners
  Map<String, int> getUnreleasedListeners() {
    return Map.fromEntries(
      _listenerCounts.entries.where((e) => e.value > 0),
    );
  }

  /// Print listener report
  void printReport() {
    if (_listenerCounts.isEmpty) {
      debugPrint('✅ ListenerTracker[$_owner]: No listeners tracked');
      return;
    }

    final unreleased = getUnreleasedListeners();
    if (unreleased.isEmpty) {
      debugPrint('✅ ListenerTracker[$_owner]: All listeners released');
    } else {
      debugPrint('⚠️  ListenerTracker[$_owner]: Unreleased listeners:');
      for (final entry in unreleased.entries) {
        debugPrint('   - ${entry.key}: ${entry.value}');
      }
    }
  }
}

/// Memory usage monitor
class MemoryMonitor {
  static final MemoryMonitor _instance = MemoryMonitor._internal();
  static MemoryMonitor get instance => _instance;

  factory MemoryMonitor() => _instance;
  MemoryMonitor._internal();

  Timer? _monitorTimer;
  final List<int> _memorySamples = [];
  int _peakMemory = 0;

  /// Start monitoring memory usage
  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    if (!kDebugMode) return;

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(interval, (_) {
      _sampleMemory();
    });

    debugPrint('📊 MemoryMonitor: Started monitoring (interval: ${interval.inSeconds}s)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    debugPrint('📊 MemoryMonitor: Stopped monitoring');
  }

  void _sampleMemory() {
    // Note: Real memory measurement requires platform channels
    // This is a placeholder for the monitoring infrastructure
    if (kDebugMode) {
      debugPrint('📊 MemoryMonitor: Sample taken (implement platform-specific measurement)');
    }
  }

  /// Get memory statistics
  Map<String, dynamic> getStats() {
    return {
      'peak_memory': _peakMemory,
      'samples_count': _memorySamples.length,
      'is_monitoring': _monitorTimer != null,
    };
  }

  /// Print memory report
  void printReport() {
    debugPrint('\n📊 ===== MEMORY REPORT =====');
    debugPrint('Peak memory: ${_peakMemory ~/ 1024 ~/ 1024}MB');
    debugPrint('Samples: ${_memorySamples.length}');
    debugPrint('========================\n');
  }

  void dispose() {
    _monitorTimer?.cancel();
    _memorySamples.clear();
  }
}
