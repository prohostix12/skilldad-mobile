import 'package:flutter/material.dart';

/// SkillDad wordmark: brand mark image + "SKILLDAD" text, matching the
/// web app's header lockup.
class SkillDadLogo extends StatelessWidget {
  const SkillDadLogo({
    super.key,
    this.markSize = 30,
    this.fontSize = 20,
    this.textColor,
    this.markColor,
  });

  final double markSize;
  final double fontSize;
  final Color? textColor;
  final Color? markColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: markSize,
          height: markSize,
          color: markColor,
          colorBlendMode: markColor != null ? BlendMode.srcIn : null,
        ),
        const SizedBox(width: 10),
        Text(
          'SKILLDAD',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: textColor ?? const Color(0xFF14102B),
          ),
        ),
      ],
    );
  }
}

