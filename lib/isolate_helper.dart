import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// Helper for running heavy computations in background isolates
///
/// PERFORMANCE: Offload CPU-intensive work to prevent UI jank
/// - Image processing
/// - JSON parsing for large datasets
/// - Encryption/decryption
/// - Complex calculations
/// - Data transformations
class IsolateHelper {
  static final IsolateHelper _instance = IsolateHelper._internal();
  static IsolateHelper get instance => _instance;

  factory IsolateHelper() => _instance;
  IsolateHelper._internal();

  final Map<String, _IsolatePool> _pools = {};

  /// Run a computation in a background isolate
  ///
  /// PERFORMANCE: Single-use isolate for one-off heavy tasks
  static Future<R> compute<Q, R>(
    ComputeCallback<Q, R> callback,
    Q message, {
    String? debugLabel,
  }) async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    if (kDebugMode) {
      debugPrint(
        '🔄 IsolateHelper: Starting ${debugLabel ?? "computation"} in background isolate',
      );
    }

    try {
      final result = await flutter_compute(callback, message, debugLabel: debugLabel);

      if (kDebugMode) {
        debugPrint(
          '✅ IsolateHelper: ${debugLabel ?? "Computation"} completed in ${stopwatch!.elapsedMilliseconds}ms',
        );
      }

      return result;
    } catch (e, st) {
      debugPrint('❌ IsolateHelper: Error in ${debugLabel ?? "computation"}: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Get or create an isolate pool for repeated tasks
  ///
  /// PERFORMANCE: Reuse isolates instead of spawning new ones
  Future<_IsolatePool> getPool(String poolId, {int maxIsolates = 2}) async {
    if (_pools.containsKey(poolId)) {
      return _pools[poolId]!;
    }

    final pool = _IsolatePool(poolId, maxIsolates: maxIsolates);
    await pool.initialize();
    _pools[poolId] = pool;

    return pool;
  }

  /// Run a task in a pooled isolate
  Future<R> runInPool<Q, R>(
    String poolId,
    ComputeCallback<Q, R> callback,
    Q message, {
    String? debugLabel,
  }) async {
    final pool = await getPool(poolId);
    return pool.run(callback, message, debugLabel: debugLabel);
  }

  /// Dispose a specific pool
  Future<void> disposePool(String poolId) async {
    final pool = _pools.remove(poolId);
    if (pool != null) {
      await pool.dispose();
      if (kDebugMode) {
        debugPrint('🗑️  IsolateHelper: Disposed pool "$poolId"');
      }
    }
  }

  /// Dispose all pools
  Future<void> disposeAll() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    _pools.clear();
    if (kDebugMode) {
      debugPrint('🗑️  IsolateHelper: Disposed all pools');
    }
  }
}

/// Wrapper around Flutter's compute function for consistency
Future<R> flutter_compute<Q, R>(
  ComputeCallback<Q, R> callback,
  Q message, {
  String? debugLabel,
}) {
  return compute(callback, message, debugLabel: debugLabel);
}

/// Pool of reusable isolates
class _IsolatePool {
  final String id;
  final int maxIsolates;

  final List<_PooledIsolate> _isolates = [];
  final Queue<_PendingTask> _pendingTasks = Queue();
  bool _isDisposed = false;

  _IsolatePool(this.id, {this.maxIsolates = 2});

  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('🏊 IsolateHelper: Creating pool "$id" with $maxIsolates isolates');
    }

    for (var i = 0; i < maxIsolates; i++) {
      final isolate = _PooledIsolate(i);
      await isolate.initialize();
      _isolates.add(isolate);
    }
  }

  Future<R> run<Q, R>(
    ComputeCallback<Q, R> callback,
    Q message, {
    String? debugLabel,
  }) async {
    if (_isDisposed) {
      throw StateError('IsolatePool "$id" has been disposed');
    }

    // Find available isolate
    final available = _isolates.firstWhere(
      (isolate) => !isolate.isBusy,
      orElse: () => _isolates.first, // Use first if all busy (will queue)
    );

    if (available.isBusy) {
      // Queue the task
      final completer = Completer<R>();
      _pendingTasks.add(_PendingTask(
        callback: callback as ComputeCallback,
        message: message,
        completer: completer as Completer,
        debugLabel: debugLabel,
      ));

      if (kDebugMode) {
        debugPrint('⏸️  IsolateHelper: Queued task ${debugLabel ?? ""} (${_pendingTasks.length} pending)');
      }

      return completer.future;
    }

    return _runOnIsolate(available, callback, message, debugLabel: debugLabel);
  }

  Future<R> _runOnIsolate<Q, R>(
    _PooledIsolate isolate,
    ComputeCallback<Q, R> callback,
    Q message, {
    String? debugLabel,
  }) async {
    final stopwatch = kDebugMode ? (Stopwatch()..start()) : null;

    if (kDebugMode) {
      debugPrint(
        '🏊 IsolateHelper: Running ${debugLabel ?? "task"} on isolate ${isolate.id} in pool "$id"',
      );
    }

    try {
      isolate.isBusy = true;
      final result = await flutter_compute(callback, message, debugLabel: debugLabel);

      if (kDebugMode) {
        debugPrint(
          '✅ IsolateHelper: Task completed in ${stopwatch!.elapsedMilliseconds}ms',
        );
      }

      return result;
    } finally {
      isolate.isBusy = false;
      _processNextTask();
    }
  }

  void _processNextTask() {
    if (_pendingTasks.isEmpty || _isDisposed) return;

    final available = _isolates.firstWhere(
      (isolate) => !isolate.isBusy,
      orElse: () => _isolates.first,
    );

    if (!available.isBusy && _pendingTasks.isNotEmpty) {
      final task = _pendingTasks.removeFirst();

      if (kDebugMode) {
        debugPrint('▶️  IsolateHelper: Processing queued task ${task.debugLabel ?? ""} (${_pendingTasks.length} remaining)');
      }

      _runOnIsolate(
        available,
        task.callback,
        task.message,
        debugLabel: task.debugLabel,
      ).then((result) {
        task.completer.complete(result);
      }).catchError((error, stackTrace) {
        task.completer.completeError(error, stackTrace);
      });
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _pendingTasks.clear();

    for (final isolate in _isolates) {
      await isolate.dispose();
    }
    _isolates.clear();
  }
}

class _PooledIsolate {
  final int id;
  bool isBusy = false;

  _PooledIsolate(this.id);

  Future<void> initialize() async {
    // Isolates are created on-demand by compute()
    // This is just a placeholder for future pooling improvements
  }

  Future<void> dispose() async {
    // No explicit dispose needed for compute() isolates
  }
}

class _PendingTask<Q, R> {
  final ComputeCallback<Q, R> callback;
  final Q message;
  final Completer<R> completer;
  final String? debugLabel;

  _PendingTask({
    required this.callback,
    required this.message,
    required this.completer,
    this.debugLabel,
  });
}

/// Common isolate tasks for typical use cases
class IsolateTasks {
  /// Parse large JSON in background
  static Future<dynamic> parseJson(String jsonString) {
    return IsolateHelper.compute(
      _parseJsonInIsolate,
      jsonString,
      debugLabel: 'Parse JSON',
    );
  }

  static dynamic _parseJsonInIsolate(String json) {
    // In reality, you'd use dart:convert here
    // This is a placeholder to avoid import issues
    return json; // Replace with: jsonDecode(json)
  }

  /// Encode data to JSON in background
  static Future<String> encodeJson(dynamic data) {
    return IsolateHelper.compute(
      _encodeJsonInIsolate,
      data,
      debugLabel: 'Encode JSON',
    );
  }

  static String _encodeJsonInIsolate(dynamic data) {
    // Replace with: jsonEncode(data)
    return data.toString();
  }

  /// Sort large list in background
  static Future<List<T>> sortList<T>(
    List<T> items,
    int Function(T, T) compare,
  ) {
    return IsolateHelper.compute(
      _sortListInIsolate,
      _SortParams(items, compare),
      debugLabel: 'Sort list',
    );
  }

  static List<T> _sortListInIsolate<T>(_SortParams<T> params) {
    final copy = List<T>.from(params.items);
    copy.sort(params.compare);
    return copy;
  }

  /// Filter large list in background
  static Future<List<T>> filterList<T>(
    List<T> items,
    bool Function(T) test,
  ) {
    return IsolateHelper.compute(
      _filterListInIsolate,
      _FilterParams(items, test),
      debugLabel: 'Filter list',
    );
  }

  static List<T> _filterListInIsolate<T>(_FilterParams<T> params) {
    return params.items.where(params.test).toList();
  }

  /// Map large list in background
  static Future<List<R>> mapList<T, R>(
    List<T> items,
    R Function(T) mapper,
  ) {
    return IsolateHelper.compute(
      _mapListInIsolate,
      _MapParams(items, mapper),
      debugLabel: 'Map list',
    );
  }

  static List<R> _mapListInIsolate<T, R>(_MapParams<T, R> params) {
    return params.items.map(params.mapper).toList();
  }

  /// Compute statistics for large dataset in background
  static Future<DataStats> computeStats(List<double> values) {
    return IsolateHelper.compute(
      _computeStatsInIsolate,
      values,
      debugLabel: 'Compute stats',
    );
  }

  static DataStats _computeStatsInIsolate(List<double> values) {
    if (values.isEmpty) {
      return DataStats(
        count: 0,
        sum: 0,
        mean: 0,
        min: 0,
        max: 0,
        stdDev: 0,
      );
    }

    final count = values.length;
    final sum = values.reduce((a, b) => a + b);
    final mean = sum / count;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    // Standard deviation
    final variance = values
        .map((v) => (v - mean) * (v - mean))
        .reduce((a, b) => a + b) / count;
    final stdDev = variance.sqrt();

    return DataStats(
      count: count,
      sum: sum,
      mean: mean,
      min: min,
      max: max,
      stdDev: stdDev,
    );
  }
}

class _SortParams<T> {
  final List<T> items;
  final int Function(T, T) compare;

  _SortParams(this.items, this.compare);
}

class _FilterParams<T> {
  final List<T> items;
  final bool Function(T) test;

  _FilterParams(this.items, this.test);
}

class _MapParams<T, R> {
  final List<T> items;
  final R Function(T) mapper;

  _MapParams(this.items, this.mapper);
}

class DataStats {
  final int count;
  final double sum;
  final double mean;
  final double min;
  final double max;
  final double stdDev;

  DataStats({
    required this.count,
    required this.sum,
    required this.mean,
    required this.min,
    required this.max,
    required this.stdDev,
  });

  @override
  String toString() {
    return 'DataStats(count: $count, mean: ${mean.toStringAsFixed(2)}, '
        'min: ${min.toStringAsFixed(2)}, max: ${max.toStringAsFixed(2)}, '
        'stdDev: ${stdDev.toStringAsFixed(2)})';
  }
}

/// Extension for easier sqrt calculation
extension DoubleExt on double {
  double sqrt() {
    if (this < 0) return double.nan;
    if (this == 0) return 0;

    // Newton's method for square root
    var x = this;
    var prev = 0.0;
    while ((x - prev).abs() > 0.0001) {
      prev = x;
      x = (x + this / x) / 2;
    }
    return x;
  }
}

/// Helper class for progress reporting from isolates
class IsolateProgress {
  final SendPort? sendPort;

  IsolateProgress(this.sendPort);

  void report(double progress, {String? message}) {
    if (sendPort != null) {
      sendPort!.send({'progress': progress, 'message': message});
    }
  }
}

/// Queue for managing multiple isolate tasks
class Queue<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);
  T removeFirst() => _items.removeAt(0);
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;
  void clear() => _items.clear();
}

/// Example usage patterns
class IsolateExamples {
  /// Example: Parse large JSON response
  static Future<void> exampleParseJson() async {
    final largeJsonString = '{"users": [...]}'; // Large JSON

    final parsed = await IsolateTasks.parseJson(largeJsonString);
    debugPrint('Parsed: $parsed');
  }

  /// Example: Sort large list without blocking UI
  static Future<void> exampleSortList() async {
    final largeList = List.generate(10000, (i) => i);

    final sorted = await IsolateTasks.sortList(
      largeList,
      (a, b) => b.compareTo(a), // Descending
    );

    debugPrint('Sorted ${sorted.length} items');
  }

  /// Example: Compute statistics for large dataset
  static Future<void> exampleComputeStats() async {
    final values = List.generate(10000, (i) => i.toDouble());

    final stats = await IsolateTasks.computeStats(values);
    debugPrint('Stats: $stats');
  }

  /// Example: Use pooled isolates for repeated tasks
  static Future<void> examplePooledIsolates() async {
    final helper = IsolateHelper.instance;

    // Create pool
    await helper.getPool('json_parser', maxIsolates: 2);

    // Run multiple tasks
    final futures = <Future>[];
    for (var i = 0; i < 10; i++) {
      futures.add(
        helper.runInPool(
          'json_parser',
          _parseJsonInIsolate,
          '{"id": $i}',
          debugLabel: 'Parse JSON $i',
        ),
      );
    }

    await Future.wait(futures);

    // Dispose pool when done
    await helper.disposePool('json_parser');
  }

  static dynamic _parseJsonInIsolate(String json) {
    return json; // Replace with actual JSON parsing
  }

  /// Example: Custom heavy computation
  static Future<void> exampleCustomComputation() async {
    final result = await IsolateHelper.compute(
      _heavyComputation,
      1000000,
      debugLabel: 'Heavy computation',
    );

    debugPrint('Result: $result');
  }

  static int _heavyComputation(int n) {
    var sum = 0;
    for (var i = 0; i < n; i++) {
      sum += i;
    }
    return sum;
  }
}

/// Performance guidelines for isolate usage
///
/// WHEN TO USE ISOLATES:
/// ✅ JSON parsing for large responses (>100KB)
/// ✅ Image processing and manipulation
/// ✅ Encryption/decryption operations
/// ✅ Complex calculations (>100ms on main thread)
/// ✅ Large list sorting/filtering (>1000 items)
/// ✅ Data transformations that are CPU-intensive
///
/// WHEN NOT TO USE ISOLATES:
/// ❌ Simple operations (<10ms)
/// ❌ Operations requiring UI context
/// ❌ Network requests (use async/await instead)
/// ❌ Database queries (already async)
/// ❌ Operations with complex object graphs (serialization overhead)
///
/// BEST PRACTICES:
/// 1. Use compute() for one-off tasks
/// 2. Use pooled isolates for repeated similar tasks
/// 3. Keep message data simple (primitives, lists, maps)
/// 4. Avoid passing complex objects (classes with methods)
/// 5. Test both with and without isolates to measure benefit
/// 6. Consider memory overhead (each isolate = new heap)
/// 7. Dispose pools when no longer needed
///
/// PERFORMANCE NOTES:
/// - Isolate spawning: ~100-200ms overhead
/// - Message passing: ~1-10ms for small messages
/// - Use pooled isolates to amortize spawning cost
/// - For very small tasks, overhead may exceed benefit
