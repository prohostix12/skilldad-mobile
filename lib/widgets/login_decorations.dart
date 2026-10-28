import 'package:flutter/material.dart';

/// Purely decorative elements for the premium login look:
/// 1. [BottomWaveDecoration]: Three layered, asymmetric organic waves anchored
///    to the bottom of the screen - each layer has its own distinct cubic-curve
///    shape, height, and gradient color, creating a premium EdTech look.
/// 2. [HeroDecorations]: Floating badges (graduation cap, briefcase, certificate),
///    flight path, paper airplane, and sparkles around the hero illustration.

/// Three premium SkillDad-branded waves anchored to the bottom.
/// Asymmetric layered curves matching the reference design:
/// - Starts high on the left and sweeps down through a center dip
/// - Sweeps up into the upper-right corner
/// - Overlapping foreground and midground lavender layers
class BottomWaveDecoration extends StatelessWidget {
  const BottomWaveDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final waveH = (screenH * 0.16).clamp(120.0, 142.0);

    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: waveH,
        child: const CustomPaint(painter: SkillDadWavePainter()),
      ),
    );
  }
}

/// Exact reference wave painter in SkillDad's purple/lavender palette:
/// 1. Back Layer: Sweeps high into the top-right corner (#EDE9FD -> #E2DCFC).
/// 2. Mid-Right Layer: Flowing intermediate wave on the right (#E3DBFC -> #D6CBFA).
/// 3. Main Swooping Layer: Starts high on left, swoops down across center (#D7CDFE -> #C5B2FA).
/// 4. Front-Left Layer: Stronger SkillDad lavender/purple mound on bottom-left (#B69EFB -> #9F7EFA).
class SkillDadWavePainter extends CustomPainter {
  const SkillDadWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ------------------------------------------------------------------
    // 1. BACK WAVE — Sweeps high into the top-right corner
    // ------------------------------------------------------------------
    final backPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFEDE9FD),
          Color(0xFFE2DCFC),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final backWave = Path()
      ..moveTo(w * 0.38, h * 0.65)
      ..cubicTo(
        w * 0.58, h * 0.52,
        w * 0.78, h * 0.32,
        w * 0.92, h * 0.22,
      )
      ..cubicTo(
        w * 0.96, h * 0.21,
        w * 0.98, h * 0.22,
        w, h * 0.24,
      )
      ..lineTo(w, h)
      ..lineTo(w * 0.38, h)
      ..close();

    canvas.drawPath(backWave, backPaint);

    // ------------------------------------------------------------------
    // 2. MID-RIGHT WAVE — Intermediate flowing layer on the right
    // ------------------------------------------------------------------
    final midRightPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE3DBFC),
          Color(0xFFD6CBFA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final midRightWave = Path()
      ..moveTo(w * 0.54, h * 0.80)
      ..cubicTo(
        w * 0.72, h * 0.62,
        w * 0.88, h * 0.46,
        w, h * 0.41,
      )
      ..lineTo(w, h)
      ..lineTo(w * 0.54, h)
      ..close();

    canvas.drawPath(midRightWave, midRightPaint);

    // ------------------------------------------------------------------
    // 3. MAIN SWOOPING WAVE — Starts high on the left, dips across center
    // ------------------------------------------------------------------
    final mainPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD7CDFE),
          Color(0xFFC5B2FA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final mainWave = Path()
      ..moveTo(0, h * 0.16)
      ..cubicTo(
        w * 0.14, h * 0.18,
        w * 0.28, h * 0.36,
        w * 0.45, h * 0.65,
      )
      ..cubicTo(
        w * 0.60, h * 0.83,
        w * 0.78, h * 0.84,
        w, h * 0.72,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(mainWave, mainPaint);

    // ------------------------------------------------------------------
    // 4. FRONT-LEFT WAVE — Stronger SkillDad purple mound in bottom-left
    // ------------------------------------------------------------------
    final frontLeftPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFB69EFB),
          Color(0xFF9F7EFA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final frontLeftWave = Path()
      ..moveTo(0, h * 0.48)
      ..cubicTo(
        w * 0.12, h * 0.50,
        w * 0.28, h * 0.68,
        w * 0.55, h,
      )
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(frontLeftWave, frontLeftPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Badges (graduation cap, briefcase, certificate), paper airplane, and
/// dashed flight arc around the hero illustration.
class HeroDecorations extends StatelessWidget {
  const HeroDecorations({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dotted flight trail behind the student's head to the airplane
          const Positioned.fill(
            child: CustomPaint(
              painter: _DottedFlightTrailPainter(),
            ),
          ),

          // 1. Paper Airplane (top right)
          Positioned(
            top: -12,
            right: 14,
            child: Transform.rotate(
              angle: -0.35,
              child: const Icon(
                Icons.send_rounded,
                size: 20,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),

          // 2. Graduation Cap Badge (top-left, over right shoulder)
          Positioned(
            top: 10,
            left: 6,
            child: _badge(
              icon: Icons.school_rounded,
              isPrimaryBg: true,
              size: 32,
              iconSize: 16,
            ),
          ),

          // 3. Briefcase Badge (upper-right, beside left ear/shoulder)
          Positioned(
            top: 46,
            right: -6,
            child: _badge(
              icon: Icons.work_rounded,
              isPrimaryBg: true,
              size: 32,
              iconSize: 15,
            ),
          ),

          // 4. Certificate Badge (mid-right, beside elbow/notebook)
          Positioned(
            top: 108,
            right: -4,
            child: _badge(
              icon: Icons.card_membership_rounded,
              isPrimaryBg: false,
              size: 32,
              iconSize: 16,
            ),
          ),

          // 5. Floating decorative sparkles/dots
          Positioned(
            top: -2,
            right: 70,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF8B5CF6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 72,
            right: 28,
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 146,
            right: 2,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required bool isPrimaryBg,
    required double size,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isPrimaryBg ? const Color(0xFF6D28D9) : Colors.white,
        shape: BoxShape.circle,
        border: isPrimaryBg
            ? null
            : Border.all(color: const Color(0xFFE4E1F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: isPrimaryBg ? Colors.white : const Color(0xFF6D28D9),
        ),
      ),
    );
  }
}

/// Subtle curved dashed arc leading to the paper airplane.
class _DottedFlightTrailPainter extends CustomPainter {
  const _DottedFlightTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.42, size.height * 0.28)
      ..cubicTo(
        size.width * 0.60, size.height * 0.20,
        size.width * 0.75, size.height * 0.10,
        size.width * 0.86, size.height * 0.02,
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashLength = 3.5;
      const dashSpace = 4.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + dashLength);
        canvas.drawPath(extractPath, paint);
        distance += dashLength + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
