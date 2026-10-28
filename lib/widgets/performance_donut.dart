import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One real, named ring of the performance chart - e.g. "Completed" courses
/// or "Certificates" earned - never a fabricated/demo category.
class PerformanceSegment {
  const PerformanceSegment({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;
}

/// A concentric multi-ring radial chart ("This Month" rainbow-arc style) -
/// one real stat per ring, each arc's length scaled against the largest
/// real value among the segments. The leading (highest-value) segment is
/// called out beside the rings rather than floating over them, so nothing
/// ever obscures the chart. All values are real counts from the student's
/// dashboard data - nothing here is demo/fabricated.
class PerformanceDonut extends StatelessWidget {
  const PerformanceDonut({super.key, required this.segments});

  final List<PerformanceSegment> segments;

  int get _maxValue => segments.fold(0, (max, s) => s.value > max ? s.value : max);

  PerformanceSegment? get _leading {
    final withValues = segments.where((s) => s.value > 0).toList();
    if (withValues.isEmpty) return null;
    withValues.sort((a, b) => b.value.compareTo(a.value));
    return withValues.first;
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = _maxValue;
    final leading = _leading;
    final total = segments.fold(0, (sum, s) => sum + s.value);
    final leadingPercent = leading == null || total == 0 ? 0 : ((leading.value / total) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'THIS MONTH',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 0.8),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow behind the rings, tinted by the leading
                  // segment's real color, for a premium "glass" feel.
                  if (leading != null)
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [leading.color.withValues(alpha: 0.16), Colors.transparent],
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 128,
                    height: 128,
                    child: maxValue == 0
                        ? const _EmptyRings()
                        : CustomPaint(painter: _RingsPainter(segments: segments, maxValue: maxValue)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: leading == null
                  ? const Text(
                      'No activity yet this month.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [leading.color, leading.color.withValues(alpha: 0.65)],
                          ).createShader(bounds),
                          child: Text(
                            '$leadingPercent%',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: leading.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${leading.label} leads this month',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [for (final segment in segments) _LegendDot(segment: segment)],
        ),
      ],
    );
  }
}

class _EmptyRings extends StatelessWidget {
  const _EmptyRings();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EmptyRingsPainter());
  }
}

class _EmptyRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final paint = Paint()
      ..color = const Color(0xFFE4E1F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final radius = (size.width / 2) - (i * 15) - 4;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi * 0.3, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyRingsPainter oldDelegate) => false;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.segment});

  final PerformanceSegment segment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: segment.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '${segment.label} (${segment.value})',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

/// Draws one concentric arc per segment - widest/outermost first - each
/// swept proportionally to `value / maxValue`, like the reference's nested
/// rainbow rings rather than a single split donut. Each ring is given a
/// subtle lightening gradient along its sweep for a premium, glossy look
/// instead of a flat stroke color.
class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.segments, required this.maxValue});

  final List<PerformanceSegment> segments;
  final int maxValue;

  static const _strokeWidth = 9.0;
  static const _ringGap = 15.0;
  static const _startAngle = -math.pi * 0.85;
  static const _fullSweep = math.pi * 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final outerRadius = size.width / 2 - _strokeWidth / 2;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final radius = outerRadius - (i * _ringGap);
      if (radius <= 0) break;
      final arcRect = Rect.fromCircle(center: center, radius: radius);

      final backgroundPaint = Paint()
        ..color = segment.color.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(arcRect, _startAngle, _fullSweep, false, backgroundPaint);

      if (segment.value <= 0) continue;
      final sweep = (segment.value / maxValue) * _fullSweep;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: GradientRotation(_startAngle),
          colors: [segment.color.withValues(alpha: 0.75), segment.color],
          stops: const [0, 1],
        ).createShader(arcRect);
      canvas.drawArc(arcRect, _startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.maxValue != maxValue;
}
