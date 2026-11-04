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

/// Queries and blocks over one window: an area under the query line, a dashed
/// line for the blocked ones, hairline gridlines and hour/day labels.
///
/// The two series share one scale, the way the design layer draws them, so a
/// day with fewer blocks reads lower even when its block rate is the same.
/// `labels` carries one entry per bucket; only a handful are drawn, each above
/// its own bucket. Touching the chart reports the bucket through [onSelect]
/// and marks both series with a dot.
class AppleTrendChart extends StatelessWidget {
  final List<double> queries;
  final List<double> blocked;

  /// One label per bucket, or null for none.
  final List<String>? labels;

  /// Bucket to mark, or -1 to draw no marker.
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final double height;

  const AppleTrendChart({
    super.key,
    required this.queries,
    required this.blocked,
    this.labels,
    this.selectedIndex = -1,
    this.onSelect,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final p = ApplePalette.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: onSelect == null
        ? null
        : (details) => _select(details.localPosition.dx, context.size?.width ?? 0),
      onHorizontalDragUpdate: onSelect == null
        ? null
        : (details) => _select(details.localPosition.dx, context.size?.width ?? 0),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _AppleTrendPainter(
            queries: queries,
            blocked: blocked,
            labels: labels,
            selectedIndex: selectedIndex,
            line: p.tint,
            blockColor: p.red,
            gridColor: p.separatorSoft,
            labelColor: p.label3,
            cardColor: p.card,
          ),
        ),
      ),
    );
  }

  void _select(double dx, double width) {
    final onSelect = this.onSelect;
    if (onSelect == null || width <= 0 || queries.length < 2) return;

    const padding = _AppleTrendMetrics.sidePadding;
    final step = (width - padding * 2) / (queries.length - 1);
    final index = ((dx - padding) / step).round().clamp(0, queries.length - 1);
    onSelect(index);
  }
}

/// The box the trend chart draws in, shared by the widget and its painter.
class _AppleTrendMetrics {
  static const double sidePadding = 6;
  static const double topPadding = 14;
  static const double bottomPadding = 24;
}

class _AppleTrendPainter extends CustomPainter {
  final List<double> queries;
  final List<double> blocked;
  final List<String>? labels;
  final int selectedIndex;
  final Color line;
  final Color blockColor;
  final Color gridColor;
  final Color labelColor;
  final Color cardColor;

  _AppleTrendPainter({
    required this.queries,
    required this.blocked,
    required this.labels,
    required this.selectedIndex,
    required this.line,
    required this.blockColor,
    required this.gridColor,
    required this.labelColor,
    required this.cardColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pl = _AppleTrendMetrics.sidePadding;
    const pr = _AppleTrendMetrics.sidePadding;
    const pt = _AppleTrendMetrics.topPadding;
    const pb = _AppleTrendMetrics.bottomPadding;

    final base = size.height - pb;
    final plot = base - pt;

    if (queries.length < 2) return;

    // The design layer leaves 12% of headroom over the busiest bucket.
    final maxV = queries.fold<double>(0, math.max) * 1.12;
    if (maxV <= 0) return;

    final step = (size.width - pl - pr) / (queries.length - 1);
    double xOf(int i) => pl + i * step;
    double yOf(double v) => pt + (1 - v / maxV) * plot;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in <double>[0, 0.5, 1]) {
      final y = pt + f * plot;
      canvas.drawLine(Offset(pl, y), Offset(size.width - pr, y), grid);
    }

    final qPath = _smooth(_points(queries, xOf, yOf));
    final area = Path.from(qPath)
      ..lineTo(xOf(queries.length - 1), base)
      ..lineTo(xOf(0), base)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, pt),
          Offset(0, base),
          [line.withValues(alpha: 0.28), line.withValues(alpha: 0)],
        ),
    );

    canvas.drawPath(
      qPath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (blocked.length == queries.length) {
      final bPath = _smooth(_points(blocked, xOf, yOf));
      canvas.drawPath(
        _dashed(bPath, const [1, 5]),
        Paint()
          ..color = blockColor.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }

    final texts = labels;
    if (texts != null && texts.length == queries.length) {
      final style = TextStyle(fontSize: 10, color: labelColor, height: 1);
      // Show a handful of buckets, always including the newest one.
      final every = (texts.length / 8).ceil();
      for (var i = 0; i < texts.length; i++) {
        if (i % every != 0 && i != texts.length - 1) continue;
        final tp = TextPainter(
          text: TextSpan(text: texts[i], style: style),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final dx = (xOf(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(dx, size.height - 15));
        tp.dispose();
      }
    }

    if (selectedIndex >= 0 && selectedIndex < queries.length) {
      final x = xOf(selectedIndex);
      canvas.drawLine(
        Offset(x, pt),
        Offset(x, base),
        Paint()
          ..color = labelColor.withValues(alpha: 0.55)
          ..strokeWidth = 1,
      );
      _dot(canvas, Offset(x, yOf(queries[selectedIndex])), line);
      if (blocked.length == queries.length) {
        _dot(canvas, Offset(x, yOf(blocked[selectedIndex])), blockColor);
      }
    }
  }

  void _dot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = cardColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  /// Catmull-Rom through the points, the same curve the design layer uses.
  Path _smooth(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[i] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  /// Turns a path into a dashed one, for `stroke-dasharray="1 5"`.
  Path _dashed(Path source, List<double> pattern) {
    final dashed = Path();
    var index = 0;
    var dash = pattern[index];

    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        // Even entries of the pattern are drawn, odd ones are left empty.
        if (index.isEven) {
          dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        }
        distance = next;
        index = (index + 1) % pattern.length;
        dash = pattern[index];
      }
    }
    return dashed;
  }

  List<Offset> _points(
    List<double> values,
    double Function(int index) xOf,
    double Function(double value) yOf,
  ) {
    return <Offset>[
      for (var i = 0; i < values.length; i++) Offset(xOf(i), yOf(values[i])),
    ];
  }

  @override
  bool shouldRepaint(_AppleTrendPainter old) =>
      old.queries != queries ||
      old.blocked != blocked ||
      old.labels != labels ||
      old.selectedIndex != selectedIndex ||
      old.line != line ||
      old.blockColor != blockColor;
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

