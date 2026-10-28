import 'package:flutter/material.dart';

/// SkillDad brand palette. `primary` is the actual deep purple the logo
/// mark and wordmark use (client/src/components/ui/SkillDadLogo.jsx and
/// Login.jsx both use #4C1D95 directly), not client/tailwind.config.js's
/// more blue-leaning general UI accent (#6D28FF) - the mobile app follows
/// the logo's color, per direct request.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF4C1D95); // Deep purple (violet-900) - the logo/wordmark color.
  static const Color primaryLight = Color(0xFF7C3AED); // violet-600, for lighter accents.
  static const Color primaryDark = Color(0xFF3B1675); // Matches Register.jsx's hover shade.
  static const Color accent = Color(0xFF6D28D9); // violet-700.

  static const Color textPrimary = Color(0xFF14102B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color background = Color(0xFFF7F5FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color fieldBorder = Color(0xFFE4E1F5);
  static const Color fieldBackground = Color(0xFFFBFAFF);

  static const Color error = Color(0xFFDC2626);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryDark],
  );
}
