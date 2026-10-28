import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A single password rule, paired with the regex that checks it.
class PasswordRequirement {
  const PasswordRequirement(this.label, this.pattern);

  final String label;
  final RegExp pattern;

  bool isMetBy(String value) => pattern.hasMatch(value);
}

/// Same rules enforced server-side (see Register.jsx's `requirements` list),
/// kept here so the mobile form can validate before ever hitting the API.
final List<PasswordRequirement> kPasswordRequirements = [
  PasswordRequirement('At least 8 characters', RegExp(r'.{8,}')),
  PasswordRequirement('Include an uppercase letter', RegExp(r'[A-Z]')),
  PasswordRequirement('Include a number', RegExp(r'[0-9]')),
  PasswordRequirement('Include a special character', RegExp(r'[^A-Za-z0-9]')),
];

/// Returns the first unmet requirement's message, or null if the password
/// satisfies every rule.
String? firstUnmetPasswordRequirement(String value) {
  for (final requirement in kPasswordRequirements) {
    if (!requirement.isMetBy(value)) return requirement.label;
  }
  return null;
}

/// Checklist shown while the password field is focused, ticking off rules
/// live as the user types.
class PasswordRequirementsCard extends StatelessWidget {
  const PasswordRequirementsCard({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 14, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'SECURITY PROTOCOL',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...kPasswordRequirements.map((requirement) {
            final met = requirement.isMetBy(password);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    met ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 14,
                    color: met ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      requirement.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: met ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
