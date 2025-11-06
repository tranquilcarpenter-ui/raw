import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

/// Optimized circular progress painter with caching
///
/// PERFORMANCE: Cache static elements to avoid redundant painting
/// - Background circle is cached (doesn't change)
/// - Only progress arc is repainted
/// - Uses shouldRepaint efficiently
class OptimizedCircularProgressPainter extends CustomPainter {
  final double progress;
  final bool isRunning;
  final Color backgroundColor;
  final List<Color> progressColors;
  final double strokeWidth;

  // Cache for background layer
  static ui.Picture? _cachedBackground;
  static Size? _cachedSize;
  static Color? _cachedBgColor;
  static double? _cachedStrokeWidth;

  OptimizedCircularProgressPainter({
    required this.progress,
    required this.isRunning,
    this.backgroundColor = const Color(0xFF2A2A2A),
    this.progressColors = const [
      Color(0xFFFFFFFF),
      Color(0xFFE0E0E0),
      Color(0xFFFFFFFF),
    ],
    this.strokeWidth = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeRadius = radius - 17.5;

    // Draw cached background or create new one
    _drawBackground(canvas, size, center, strokeRadius);

    // Only draw progress arc when timer is running
    if (isRunning && progress > 0) {
      _drawProgress(canvas, center, strokeRadius);
    }
  }

  void _drawBackground(Canvas canvas, Size size, Offset center, double strokeRadius) {
    // Check if we can use cached background
    final canUseCache = _cachedBackground != null &&
        _cachedSize == size &&
        _cachedBgColor == backgroundColor &&
        _cachedStrokeWidth == strokeWidth;

    if (canUseCache) {
      // Use cached background (PERFORMANCE: avoid redrawing)
      canvas.drawPicture(_cachedBackground!);
    } else {
      // Create new cached background
      final recorder = ui.PictureRecorder();
      final recordCanvas = Canvas(recorder);

      final backgroundPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = backgroundColor;

      recordCanvas.drawCircle(center, strokeRadius, backgroundPaint);

      _cachedBackground = recorder.endRecording();
      _cachedSize = size;
      _cachedBgColor = backgroundColor;
      _cachedStrokeWidth = strokeWidth;

      // Draw the newly created background
      canvas.drawPicture(_cachedBackground!);
    }
  }

  void _drawProgress(Canvas canvas, Offset center, double strokeRadius) {
    // Outer glow effect for progress arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: strokeRadius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      glowPaint,
    );

    // Main progress arc with gradient
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    progressPaint.shader = SweepGradient(
      startAngle: -math.pi / 2,
      colors: progressColors,
    ).createShader(Rect.fromCircle(center: center, radius: strokeRadius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: strokeRadius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(OptimizedCircularProgressPainter oldDelegate) {
    // Only repaint if progress or running state changed
    return oldDelegate.progress != progress ||
        oldDelegate.isRunning != isRunning;
  }

  /// Clear the cached background (call when theme changes)
  static void clearCache() {
    _cachedBackground = null;
    _cachedSize = null;
    _cachedBgColor = null;
    _cachedStrokeWidth = null;
  }
}

/// Optimized line chart painter with caching
///
/// PERFORMANCE: Cache grid lines and axes (static elements)
class OptimizedLineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final Color lineColor;
  final Color gridColor;
  final bool showGrid;

  // Cache for grid/axes
  static ui.Picture? _cachedGrid;
  static Size? _cachedGridSize;

  OptimizedLineChartPainter({
    required this.data,
    required this.maxValue,
    this.lineColor = const Color(0xFF8B5CF6),
    this.gridColor = const Color(0xFF2C2C2E),
    this.showGrid = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw cached grid
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // Draw data line (always needs repainting)
    _drawDataLine(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final canUseCache = _cachedGrid != null && _cachedGridSize == size;

    if (canUseCache) {
      canvas.drawPicture(_cachedGrid!);
    } else {
      // Create new cached grid
      final recorder = ui.PictureRecorder();
      final recordCanvas = Canvas(recorder);

      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      // Draw horizontal grid lines
      for (var i = 0; i <= 5; i++) {
        final y = size.height * i / 5;
        recordCanvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          gridPaint,
        );
      }

      _cachedGrid = recorder.endRecording();
      _cachedGridSize = size;

      canvas.drawPicture(_cachedGrid!);
    }
  }

  void _drawDataLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(OptimizedLineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }

  static void clearCache() {
    _cachedGrid = null;
    _cachedGridSize = null;
  }
}

/// Optimized pie chart painter
///
/// PERFORMANCE: Cache the entire pie when data doesn't change
class OptimizedPieChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;
  final bool showLabels;

  // Cache for the entire pie chart
  static ui.Picture? _cachedPie;
  static Map<String, double>? _cachedData;
  static Size? _cachedPieSize;

  OptimizedPieChartPainter({
    required this.data,
    required this.colors,
    this.showLabels = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final canUseCache = _cachedPie != null &&
        _cachedData == data &&
        _cachedPieSize == size;

    if (canUseCache) {
      // Use cached pie chart (PERFORMANCE: entire chart is cached)
      canvas.drawPicture(_cachedPie!);
    } else {
      // Create new cached pie chart
      final recorder = ui.PictureRecorder();
      final recordCanvas = Canvas(recorder);

      _drawPieChart(recordCanvas, size);

      _cachedPie = recorder.endRecording();
      _cachedData = Map.from(data);
      _cachedPieSize = size;

      canvas.drawPicture(_cachedPie!);
    }
  }

  void _drawPieChart(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    final total = data.values.reduce((a, b) => a + b);
    var startAngle = -math.pi / 2;

    var colorIndex = 0;
    for (final entry in data.entries) {
      final sweepAngle = (entry.value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[colorIndex % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
      colorIndex++;
    }
  }

  @override
  bool shouldRepaint(OptimizedPieChartPainter oldDelegate) {
    return oldDelegate.data != data;
  }

  static void clearCache() {
    _cachedPie = null;
    _cachedData = null;
    _cachedPieSize = null;
  }
}

/// Helper to clear all painter caches (e.g., on theme change)
class PainterCacheManager {
  static void clearAllCaches() {
    OptimizedCircularProgressPainter.clearCache();
    OptimizedLineChartPainter.clearCache();
    OptimizedPieChartPainter.clearCache();
    debugPrint('🗑️ PainterCache: Cleared all painter caches');
  }

  static void clearCircularProgressCache() {
    OptimizedCircularProgressPainter.clearCache();
  }

  static void clearLineChartCache() {
    OptimizedLineChartPainter.clearCache();
  }

  static void clearPieChartCache() {
    OptimizedPieChartPainter.clearCache();
  }
}
