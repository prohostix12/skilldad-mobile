import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';

/// A 7-day performance chart for the real weekly series
/// (GET /api/students/performance/weekly): a smooth gradient-filled curve
/// with grid lines, a highlighted latest point and a value badge, plus day
/// labels underneath with today picked out in the brand color.
class PerformanceSparkline extends StatelessWidget {
  const PerformanceSparkline({super.key, required this.points, this.height = 120});

  final List<PerformancePoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final latest = points.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, right: 4),
          child: SizedBox(
            height: height,
            child: CustomPaint(
              painter: _SparklinePainter(points: points, color: AppColors.primary, maxValue: maxValue),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: points
              .map(
                (p) => Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: p == latest ? FontWeight.w800 : FontWeight.w500,
                    color: p == latest ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color, required this.maxValue});

  final List<PerformancePoint> points;
  final Color color;
  final double maxValue;

  static const _topPad = 26.0;
  static const _bottomPad = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _topPad - _bottomPad;
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    // Horizontal grid lines - 25/50/75/100% of the max value.
    final gridPaint = Paint()
      ..color = AppColors.fieldBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = _topPad + chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) return;

    final stepX = size.width / (points.length - 1);

    Offset pointAt(int i) {
      final x = stepX * i;
      final y = _topPad + chartHeight - (points[i].value / safeMax) * chartHeight;
      return Offset(x, y.clamp(_topPad, _topPad + chartHeight));
    }

    final rawPoints = [for (var i = 0; i < points.length; i++) pointAt(i)];

    // Smooth the line with a Catmull-Rom-style cubic spline instead of
    // straight segments, so the real daily values read as a trend curve.
    final linePath = Path()..moveTo(rawPoints.first.dx, rawPoints.first.dy);
    for (var i = 0; i < rawPoints.length - 1; i++) {
      final p0 = i == 0 ? rawPoints[i] : rawPoints[i - 1];
      final p1 = rawPoints[i];
      final p2 = rawPoints[i + 1];
      final p3 = i + 2 < rawPoints.length ? rawPoints[i + 2] : p2;

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(rawPoints.last.dx, size.height - _bottomPad)
      ..lineTo(rawPoints.first.dx, size.height - _bottomPad)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, _topPad, size.width, chartHeight)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < rawPoints.length; i++) {
      final isLast = i == rawPoints.length - 1;
      if (!isLast) {
        canvas.drawCircle(rawPoints[i], 2.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          rawPoints[i],
          2.5,
          Paint()
            ..color = color.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    // Highlight the latest point with a glow ring, solid dot and a value
    // badge above it, so the most recent real data point stands out.
    final last = rawPoints.last;
    canvas.drawCircle(last, 8, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(last, 4.5, Paint()..color = color);
    canvas.drawCircle(last, 4.5, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    final badgeText = points.last.value.round().toString();
    final textPainter = TextPainter(
      text: TextSpan(
        text: badgeText,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = textPainter.width + 12;
    const badgeHeight = 20.0;
    var badgeLeft = last.dx - badgeWidth / 2;
    badgeLeft = badgeLeft.clamp(0.0, size.width - badgeWidth);
    final badgeTop = (last.dy - 8 - badgeHeight).clamp(0.0, size.height);
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeLeft, badgeTop, badgeWidth, badgeHeight),
      const Radius.circular(10),
    );
    canvas.drawRRect(badgeRect, Paint()..color = color);
    textPainter.paint(canvas, Offset(badgeLeft + 6, badgeTop + (badgeHeight - textPainter.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color || oldDelegate.maxValue != maxValue;
}
