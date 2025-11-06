import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Production performance analytics
///
/// MONITORING: Track real-world performance metrics in production
/// - Screen load times
/// - User interaction latency
/// - Error rates
/// - Memory warnings
/// - Network performance
/// - Custom business metrics
///
/// NOTE: This is a framework - integrate with your analytics provider
/// (Firebase Analytics, Mixpanel, Amplitude, etc.)
class ProductionAnalytics {
  static final ProductionAnalytics _instance = ProductionAnalytics._internal();
  static ProductionAnalytics get instance => _instance;

  factory ProductionAnalytics() => _instance;
  ProductionAnalytics._internal();

  bool _isInitialized = false;
  final Map<String, _PerformanceTrace> _activeTraces = {};
  final Map<String, _MetricAggregator> _aggregators = {};

  /// Initialize analytics (call in main.dart)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      debugPrint('📊 ProductionAnalytics: Initializing...');
    }

    // TODO: Initialize your analytics provider here
    // await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('✅ ProductionAnalytics: Initialized');
    }
  }

  /// Start a performance trace
  void startTrace(String traceName) {
    if (!_isInitialized) return;

    if (_activeTraces.containsKey(traceName)) {
      if (kDebugMode) {
        debugPrint('⚠️  Trace "$traceName" already active');
      }
      return;
    }

    _activeTraces[traceName] = _PerformanceTrace(
      name: traceName,
      startTime: DateTime.now(),
    );

    if (kDebugMode) {
      debugPrint('▶️  Trace started: $traceName');
    }
  }

  /// Stop a performance trace and send to analytics
  void stopTrace(String traceName, {Map<String, dynamic>? attributes}) {
    if (!_isInitialized) return;

    final trace = _activeTraces.remove(traceName);
    if (trace == null) {
      if (kDebugMode) {
        debugPrint('⚠️  Trace "$traceName" not found');
      }
      return;
    }

    final duration = DateTime.now().difference(trace.startTime);

    if (kDebugMode) {
      debugPrint(
        '⏹️  Trace stopped: $traceName (${duration.inMilliseconds}ms)',
      );
    }

    // Send to analytics provider
    _sendPerformanceMetric(
      traceName,
      duration.inMilliseconds.toDouble(),
      attributes: attributes,
    );

    // Update aggregator
    _getAggregator(traceName).add(duration.inMilliseconds.toDouble());
  }

  /// Log a custom performance metric
  void logMetric(String name, double value, {Map<String, dynamic>? attributes}) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('📈 Metric: $name = ${value.toStringAsFixed(2)}');
    }

    _sendPerformanceMetric(name, value, attributes: attributes);
    _getAggregator(name).add(value);
  }

  /// Log screen view with load time
  void logScreenView(String screenName, Duration loadTime) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('📱 Screen: $screenName (${loadTime.inMilliseconds}ms)');
    }

    _sendEvent('screen_view', {
      'screen_name': screenName,
      'load_time_ms': loadTime.inMilliseconds,
    });

    _getAggregator('screen_$screenName').add(loadTime.inMilliseconds.toDouble());
  }

  /// Log user interaction with timing
  void logInteraction(String action, Duration duration) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('👆 Interaction: $action (${duration.inMilliseconds}ms)');
    }

    _sendEvent('user_interaction', {
      'action': action,
      'duration_ms': duration.inMilliseconds,
    });

    _getAggregator('interaction_$action').add(duration.inMilliseconds.toDouble());
  }

  /// Log network request performance
  void logNetworkRequest(
    String endpoint,
    Duration duration,
    int statusCode, {
    int? responseSize,
  }) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint(
        '🌐 Network: $endpoint ($statusCode) ${duration.inMilliseconds}ms',
      );
    }

    _sendEvent('network_request', {
      'endpoint': endpoint,
      'duration_ms': duration.inMilliseconds,
      'status_code': statusCode,
      if (responseSize != null) 'response_size_bytes': responseSize,
    });

    _getAggregator('network_$endpoint').add(duration.inMilliseconds.toDouble());
  }

  /// Log error with context
  void logError(
    String error,
    StackTrace? stackTrace, {
    Map<String, dynamic>? context,
    bool fatal = false,
  }) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('❌ Error: $error');
    }

    _sendEvent('error', {
      'error': error,
      'fatal': fatal,
      'stack_trace': stackTrace?.toString(),
      ...?context,
    });
  }

  /// Log memory warning
  void logMemoryWarning(int currentMemoryMB) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('⚠️  Memory warning: ${currentMemoryMB}MB');
    }

    _sendEvent('memory_warning', {
      'current_memory_mb': currentMemoryMB,
    });
  }

  /// Log frame drops (janky frames)
  void logFrameDrops(int droppedFrames, Duration period) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('🎞️  Frame drops: $droppedFrames in ${period.inSeconds}s');
    }

    _sendEvent('frame_drops', {
      'dropped_frames': droppedFrames,
      'period_seconds': period.inSeconds,
    });
  }

  /// Log app startup metrics
  void logAppStartup({
    required Duration timeToFirstFrame,
    required Duration criticalInitTime,
    required Duration totalStartupTime,
  }) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      debugPrint('🚀 App startup:');
      debugPrint('   First frame: ${timeToFirstFrame.inMilliseconds}ms');
      debugPrint('   Critical init: ${criticalInitTime.inMilliseconds}ms');
      debugPrint('   Total: ${totalStartupTime.inMilliseconds}ms');
    }

    _sendEvent('app_startup', {
      'time_to_first_frame_ms': timeToFirstFrame.inMilliseconds,
      'critical_init_ms': criticalInitTime.inMilliseconds,
      'total_startup_ms': totalStartupTime.inMilliseconds,
    });
  }

  /// Get statistics for a metric
  MetricStats? getStats(String name) {
    final aggregator = _aggregators[name];
    if (aggregator == null) return null;

    return aggregator.getStats();
  }

  /// Get all metric statistics
  Map<String, MetricStats> getAllStats() {
    return _aggregators.map((key, aggregator) {
      return MapEntry(key, aggregator.getStats());
    });
  }

  /// Reset all aggregators
  void resetStats() {
    _aggregators.clear();
    if (kDebugMode) {
      debugPrint('🔄 ProductionAnalytics: Stats reset');
    }
  }

  _MetricAggregator _getAggregator(String name) {
    if (!_aggregators.containsKey(name)) {
      _aggregators[name] = _MetricAggregator(name);
    }
    return _aggregators[name]!;
  }

  void _sendPerformanceMetric(
    String name,
    double value, {
    Map<String, dynamic>? attributes,
  }) {
    // TODO: Send to your analytics provider
    // Example for Firebase:
    // FirebasePerformance.instance
    //   .newTrace(name)
    //   ..setMetric('value', value.toInt())
    //   ..stop();

    // Example for custom backend:
    // http.post('https://api.example.com/metrics', body: {
    //   'name': name,
    //   'value': value,
    //   'attributes': attributes,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });
  }

  void _sendEvent(String name, Map<String, dynamic> parameters) {
    // TODO: Send to your analytics provider
    // Example for Firebase:
    // FirebaseAnalytics.instance.logEvent(
    //   name: name,
    //   parameters: parameters,
    // );
  }
}

class _PerformanceTrace {
  final String name;
  final DateTime startTime;

  _PerformanceTrace({
    required this.name,
    required this.startTime,
  });
}

class _MetricAggregator {
  final String name;
  final List<double> _values = [];
  final int _maxValues = 1000;

  _MetricAggregator(this.name);

  void add(double value) {
    _values.add(value);

    // Keep only last N values
    if (_values.length > _maxValues) {
      _values.removeAt(0);
    }
  }

  MetricStats getStats() {
    if (_values.isEmpty) {
      return MetricStats(
        name: name,
        count: 0,
        min: 0,
        max: 0,
        avg: 0,
        p50: 0,
        p95: 0,
        p99: 0,
      );
    }

    final sorted = List<double>.from(_values)..sort();

    return MetricStats(
      name: name,
      count: _values.length,
      min: sorted.first,
      max: sorted.last,
      avg: _values.reduce((a, b) => a + b) / _values.length,
      p50: _percentile(sorted, 0.5),
      p95: _percentile(sorted, 0.95),
      p99: _percentile(sorted, 0.99),
    );
  }

  double _percentile(List<double> sorted, double percentile) {
    final index = (sorted.length * percentile).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }
}

class MetricStats {
  final String name;
  final int count;
  final double min;
  final double max;
  final double avg;
  final double p50;
  final double p95;
  final double p99;

  MetricStats({
    required this.name,
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
    required this.p50,
    required this.p95,
    required this.p99,
  });

  @override
  String toString() {
    return 'MetricStats($name): count=$count, avg=${avg.toStringAsFixed(2)}, '
        'p50=${p50.toStringAsFixed(2)}, p95=${p95.toStringAsFixed(2)}, '
        'p99=${p99.toStringAsFixed(2)}';
  }
}

/// Widget wrapper that automatically tracks screen load time
class AnalyticsScreenWrapper extends StatefulWidget {
  final String screenName;
  final Widget child;

  const AnalyticsScreenWrapper({
    super.key,
    required this.screenName,
    required this.child,
  });

  @override
  State<AnalyticsScreenWrapper> createState() => _AnalyticsScreenWrapperState();
}

class _AnalyticsScreenWrapperState extends State<AnalyticsScreenWrapper> {
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    ProductionAnalytics.instance.startTrace('screen_${widget.screenName}');
  }

  @override
  void dispose() {
    final loadTime = DateTime.now().difference(_startTime);
    ProductionAnalytics.instance.stopTrace('screen_${widget.screenName}');
    ProductionAnalytics.instance.logScreenView(widget.screenName, loadTime);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Extension for easy performance tracking
extension PerformanceTrackingExtension on Future<T> Function() {
  /// Track execution time of a function
  Future<T> trackPerformance<T>(String name) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await this();
      ProductionAnalytics.instance.logMetric(
        name,
        stopwatch.elapsedMilliseconds.toDouble(),
      );
      return result;
    } catch (e, st) {
      ProductionAnalytics.instance.logError(e.toString(), st);
      rethrow;
    }
  }
}

/// Performance monitoring widget
class PerformanceMonitoringWidget extends StatefulWidget {
  final Widget child;
  final Duration sampleInterval;

  const PerformanceMonitoringWidget({
    super.key,
    required this.child,
    this.sampleInterval = const Duration(seconds: 10),
  });

  @override
  State<PerformanceMonitoringWidget> createState() =>
      _PerformanceMonitoringWidgetState();
}

class _PerformanceMonitoringWidgetState
    extends State<PerformanceMonitoringWidget> {
  Timer? _timer;
  int _frameCount = 0;
  int _droppedFrames = 0;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    _timer = Timer.periodic(widget.sampleInterval, (_) {
      _checkPerformance();
    });

    // Monitor frame callbacks
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _frameCount++;

    // Check if frame took too long (>16ms for 60fps)
    if (timestamp.inMilliseconds > 16) {
      _droppedFrames++;
    }

    // Schedule next frame callback
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _checkPerformance() {
    if (_droppedFrames > 0) {
      ProductionAnalytics.instance.logFrameDrops(
        _droppedFrames,
        widget.sampleInterval,
      );
    }

    // Reset counters
    _frameCount = 0;
    _droppedFrames = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Helper for tracking user interactions
class InteractionTracker {
  static final InteractionTracker _instance = InteractionTracker._internal();
  static InteractionTracker get instance => _instance;

  factory InteractionTracker() => _instance;
  InteractionTracker._internal();

  final Map<String, DateTime> _activeInteractions = {};

  /// Start tracking an interaction
  void start(String action) {
    _activeInteractions[action] = DateTime.now();

    if (kDebugMode) {
      debugPrint('👆 Interaction started: $action');
    }
  }

  /// End tracking an interaction
  void end(String action) {
    final startTime = _activeInteractions.remove(action);
    if (startTime == null) {
      if (kDebugMode) {
        debugPrint('⚠️  Interaction "$action" not started');
      }
      return;
    }

    final duration = DateTime.now().difference(startTime);
    ProductionAnalytics.instance.logInteraction(action, duration);
  }
}

/// Helper for tracking network requests
class NetworkTracker {
  /// Track a network request
  static Future<T> track<T>(
    String endpoint,
    Future<T> Function() request,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await request();

      ProductionAnalytics.instance.logNetworkRequest(
        endpoint,
        stopwatch.elapsed,
        200, // Success
      );

      return result;
    } catch (e, st) {
      ProductionAnalytics.instance.logNetworkRequest(
        endpoint,
        stopwatch.elapsed,
        500, // Error
      );

      ProductionAnalytics.instance.logError(
        'Network request failed: $endpoint',
        st,
        context: {'error': e.toString()},
      );

      rethrow;
    }
  }
}

/// Example usage patterns
class AnalyticsExamples {
  /// Example: Track screen load time
  static void exampleScreenTracking() {
    // In your screen widget:
    // return AnalyticsScreenWrapper(
    //   screenName: 'home',
    //   child: HomeScreen(),
    // );
  }

  /// Example: Track custom operation
  static Future<void> exampleCustomOperation() async {
    ProductionAnalytics.instance.startTrace('load_user_data');

    try {
      // ... load user data ...
      await Future.delayed(const Duration(milliseconds: 100));

      ProductionAnalytics.instance.stopTrace(
        'load_user_data',
        attributes: {'user_id': '123'},
      );
    } catch (e) {
      ProductionAnalytics.instance.stopTrace('load_user_data');
      rethrow;
    }
  }

  /// Example: Track user interaction
  static void exampleInteractionTracking() {
    // On button press:
    InteractionTracker.instance.start('submit_form');

    // ... handle form submission ...

    InteractionTracker.instance.end('submit_form');
  }

  /// Example: Track network request
  static Future<void> exampleNetworkTracking() async {
    final data = await NetworkTracker.track(
      '/api/users',
      () async {
        // ... make network request ...
        return {};
      },
    );
  }

  /// Example: Get performance statistics
  static void exampleGetStats() {
    final stats = ProductionAnalytics.instance.getStats('screen_home');
    if (stats != null) {
      debugPrint('Home screen load time: ${stats.avg.toStringAsFixed(2)}ms');
      debugPrint('p95: ${stats.p95.toStringAsFixed(2)}ms');
    }
  }
}

/// Production analytics dashboard (debug overlay)
class AnalyticsDashboard extends StatelessWidget {
  const AnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = ProductionAnalytics.instance.getAllStats();

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black.withValues(alpha: 0.9),
      child: ListView(
        children: [
          const Text(
            '📊 Performance Metrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...stats.entries.map((entry) {
            return _MetricCard(
              name: entry.key,
              stats: entry.value,
            );
          }),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String name;
  final MetricStats stats;

  const _MetricCard({
    required this.name,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Avg: ${stats.avg.toStringAsFixed(2)}ms',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'p95: ${stats.p95.toStringAsFixed(2)}ms',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            'Count: ${stats.count}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
