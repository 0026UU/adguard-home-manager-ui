import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:adguard_home_manager/widgets/apple/apple_widgets.dart';

/// Smooth area chart in the style of the iOS Health / Stocks cards.
///
/// Replaces the gridded fl_chart used before: no axes, one hairline baseline,
/// a Catmull-Rom curve and a vertical gradient under it.
class AppleAreaChart extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double height;

  /// Horizontal gridlines drawn behind the curve (0 disables them).
  final int gridLines;

  /// Labels drawn under the curve, evenly spaced (first … last).
  final List<String>? xLabels;

  /// Called with the max value to render the "peak" caption at the top-left.
  final String Function(double max)? maxValueLabel;

  const AppleAreaChart({
    super.key,
    required this.values,
    this.color,
    this.height = 140,
    this.gridLines = 3,
    this.xLabels,
    this.maxValueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final tint = color ?? p.tint;

    return SizedBox(
      height: height + (xLabels != null ? 18 : 0),
      width: double.infinity,
      child: CustomPaint(
        painter: _AppleAreaPainter(
          values: values,
          color: tint,
          gridLines: gridLines,
          gridColor: p.separatorSoft,
          xLabels: xLabels,
          maxValueLabel: maxValueLabel != null ? maxValueLabel!(values.fold<double>(0, math.max)) : null,
          labelStyle: TextStyle(fontSize: 11, color: p.label3, height: 1),
        ),
      ),
    );
  }
}

class _AppleAreaPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int gridLines;
  final Color gridColor;
  final List<String>? xLabels;
  final String? maxValueLabel;
  final TextStyle labelStyle;

  _AppleAreaPainter({
    required this.values,
    required this.color,
    required this.gridLines,
    required this.gridColor,
    required this.xLabels,
    required this.maxValueLabel,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = xLabels != null ? size.height - 18 : size.height;

    if (gridLines > 0) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 0.5;
      for (var i = 0; i <= gridLines; i++) {
        final y = chartHeight * (i / gridLines);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    if (values.isEmpty) return;

    final maxV = values.fold<double>(0, math.max);
    final minV = values.reduce(math.min);
    final range = maxV - minV;
    // A flat series is drawn just above the baseline instead of on it.
    final top = range == 0 ? 0.15 * chartHeight : 0.0;
    final bottom = chartHeight - 1.0;

    double yOf(double v) {
      if (range == 0) return bottom - (bottom - top) * 0.5;
      final t = (v - minV) / range;
      return bottom - t * (bottom - top);
    }

    final n = values.length;
    final step = n > 1 ? size.width / (n - 1) : size.width;
    final pts = <Offset>[
      for (var i = 0; i < n; i++) Offset(i * step, yOf(values[i])),
    ];

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      // Catmull-Rom -> cubic bezier control points.
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, chartHeight)
      ..lineTo(pts.first.dx, chartHeight)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, chartHeight),
          [color.withValues(alpha: 0.26), color.withValues(alpha: 0.02)],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Last point marker, like the iOS charts.
    final last = pts.last;
    canvas.drawCircle(last, 3.5, Paint()..color = color);
    canvas.drawCircle(last, 2.0, Paint()..color = Colors.white);

    if (maxValueLabel != null) {
      _drawText(canvas, maxValueLabel!, labelStyle, Offset(0, 0));
    }

    if (xLabels != null && xLabels!.isNotEmpty) {
      final labels = xLabels!;
      final count = labels.length;
      for (var i = 0; i < count; i++) {
        final tp = _textPainter(labels[i], labelStyle);
        final dx = count == 1 ? 0.0 : (size.width - tp.width) * (i / (count - 1));
        tp.paint(canvas, Offset(dx, chartHeight + 6));
        tp.dispose();
      }
    }
  }

  void _drawText(Canvas canvas, String text, TextStyle style, Offset offset) {
    final tp = _textPainter(text, style);
    tp.paint(canvas, offset);
    tp.dispose();
  }

  TextPainter _textPainter(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(_AppleAreaPainter old) =>
      old.values != values ||
      old.color != color ||
      old.gridColor != gridColor ||
      old.xLabels != xLabels ||
      old.maxValueLabel != maxValueLabel;
}

/// Thin inline chart for stat rows.
class AppleSparkline extends StatelessWidget {
  final List<double> values;
  final Color? color;
  final double height;
  final double width;

  const AppleSparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 22,
    this.width = 68,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color ?? p.tint),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.fold<double>(0, math.max);
    final minV = values.reduce(math.min);
    final range = maxV - minV == 0 ? 1.0 : maxV - minV;
    final step = size.width / (values.length - 1);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final y = size.height - 2 - ((values[i] - minV) / range) * (size.height - 4);
      final o = Offset(i * step, y);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

/// Ring progress (block percentage) with the value centred inside.
class AppleDonut extends StatelessWidget {
  final double percent;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  const AppleDonut({
    super.key,
    required this.percent,
    this.size = 66,
    this.stroke = 8,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);
    final tint = color ?? p.red;
    final clamped = percent.clamp(0.0, 100.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          percent: clamped / 100,
          color: tint,
          track: p.fill2,
          stroke: stroke,
        ),
        child: Center(
          child: child ??
              Text(
                '${clamped.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: tint,
                ),
              ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color track;
  final double stroke;

  const _DonutPainter({
    required this.percent,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (percent > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * percent,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.percent != percent || old.color != color || old.track != track;
}

