import 'package:flutter/material.dart';

/// Full-width primary action button with an optional loading state and
/// trailing arrow icon, matching the web login CTA.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.iconSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(label, overflow: TextOverflow.ellipsis),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: iconSize ?? 19),
                ],
              ],
            ),
    );
  }
}
