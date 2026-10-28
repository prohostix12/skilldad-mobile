import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable outlined text field with a leading icon and optional
/// trailing widget (used for the password show/hide toggle).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.suffixIcon,
    this.autofillHints,
    this.focusNode,
    this.onChanged,
    this.fontSize = 15,
    this.iconSize = 21,
    this.contentPadding,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      autofillHints: autofillHints,
      style: TextStyle(fontSize: fontSize, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        contentPadding: contentPadding,
        prefixIcon: Icon(icon, color: AppColors.primary, size: iconSize),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
