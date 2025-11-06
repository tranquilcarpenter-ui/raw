import 'package:flutter/foundation.dart';
import 'dart:async';

/// Performance monitoring utility for tracking and analyzing app performance
///
/// Use this during development to identify bottlenecks and measure optimization impact.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  static PerformanceMonitor get instance => _instance;

  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<Duration>> _measurements = {};
  final Map<String, DateTime> _pendingTimers = {};
  final Map<String, int> _counters = {};

  /// Start timing an operation
  void startTimer(String operation) {
    if (!kDebugMode) return; // Only track in debug mode

    _pendingTimers[operation] = DateTime.now();
  }

  /// Stop timing an operation and record the duration
  void stopTimer(String operation) {
    if (!kDebugMode) return;

    final startTime = _pendingTimers.remove(operation);
    if (startTime == null) {
      debugPrint('⚠️ PerformanceMonitor: No start time found for $operation');
      return;
    }

    final duration = DateTime.now().difference(startTime);
    _measurements.putIfAbsent(operation, () => []).add(duration);

    debugPrint('⏱️  $operation: ${duration.inMilliseconds}ms');
  }

  /// Time an async operation
  Future<T> timeAsync<T>(
    String operation,
    Future<T> Function() function,
  ) async {
    if (!kDebugMode) {
      return function();
    }

    startTimer(operation);
    try {
      return await function();
    } finally {
      stopTimer(operation);
    }
  }

  /// Time a synchronous operation
  T timeSync<T>(
    String operation,
    T Function() function,
  ) {
    if (!kDebugMode) {
      return function();
    }

    startTimer(operation);
    try {
      return function();
    } finally {
      stopTimer(operation);
    }
  }

  /// Increment a counter
  void incrementCounter(String counterName) {
    if (!kDebugMode) return;

    _counters[counterName] = (_counters[counterName] ?? 0) + 1;
  }

  /// Get statistics for an operation
  Map<String, dynamic>? getStats(String operation) {
    final measurements = _measurements[operation];
    if (measurements == null || measurements.isEmpty) return null;

    final durations = measurements.map((d) => d.inMilliseconds).toList()..sort();
    final count = durations.length;
    final sum = durations.reduce((a, b) => a + b);
    final avg = sum / count;
    final min = durations.first;
    final max = durations.last;
    final p50 = durations[count ~/ 2];
    final p95 = durations[(count * 0.95).floor().clamp(0, count - 1)];
    final p99 = durations[(count * 0.99).floor().clamp(0, count - 1)];

    return {
      'operation': operation,
      'count': count,
      'avg_ms': avg.toStringAsFixed(2),
      'min_ms': min,
      'max_ms': max,
      'p50_ms': p50,
      'p95_ms': p95,
      'p99_ms': p99,
    };
  }

  /// Get all statistics
  Map<String, Map<String, dynamic>> getAllStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final operation in _measurements.keys) {
      final operationStats = getStats(operation);
      if (operationStats != null) {
        stats[operation] = operationStats;
      }
    }
    return stats;
  }

  /// Get counter value
  int getCounter(String counterName) => _counters[counterName] ?? 0;

  /// Get all counters
  Map<String, int> getAllCounters() => Map.from(_counters);

  /// Print summary of all measurements
  void printSummary() {
    if (!kDebugMode) return;

    debugPrint('\n📊 ===== PERFORMANCE SUMMARY =====');

    final stats = getAllStats();
    if (stats.isEmpty) {
      debugPrint('No measurements recorded');
    } else {
      for (final entry in stats.entries) {
        final s = entry.value;
        debugPrint(
          '${entry.key}: ${s['count']} calls, avg=${s['avg_ms']}ms, p95=${s['p95_ms']}ms',
        );
      }
    }

    final counters = getAllCounters();
    if (counters.isNotEmpty) {
      debugPrint('\n📈 Counters:');
      for (final entry in counters.entries) {
        debugPrint('  ${entry.key}: ${entry.value}');
      }
    }

    debugPrint('================================\n');
  }

  /// Clear all measurements and counters
  void clear() {
    _measurements.clear();
    _pendingTimers.clear();
    _counters.clear();
  }

  /// Clear measurements for a specific operation
  void clearOperation(String operation) {
    _measurements.remove(operation);
    _pendingTimers.remove(operation);
  }
}

/// Extension for easy performance monitoring
extension PerformanceMonitorExtension<T> on Future<T> {
  /// Time this future execution
  Future<T> timed(String operation) {
    return PerformanceMonitor.instance.timeAsync(operation, () => this);
  }
}
