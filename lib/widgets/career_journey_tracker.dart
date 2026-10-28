import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';

/// Horizontal step tracker for the student's real career-readiness signals
/// (see DashboardService.fetchDashboard - 6 real, computed steps, never
/// invented ones).
class CareerJourneyTracker extends StatelessWidget {
  const CareerJourneyTracker({super.key, required this.steps});

  final List<CareerStep> steps;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepDot(step: steps[i]),
            if (i < steps.length - 1)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: steps[i].done && steps[i + 1].done
                    ? Colors.green.shade400
                    : AppColors.fieldBorder,
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.step});

  final CareerStep step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: step.done ? Colors.green.shade500 : AppColors.fieldBackground,
              shape: BoxShape.circle,
              border: step.done ? null : Border.all(color: AppColors.fieldBorder),
            ),
            child: Icon(
              step.done ? Icons.check_rounded : Icons.circle_outlined,
              color: step.done ? Colors.white : AppColors.textMuted,
              size: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: step.done ? AppColors.textPrimary : AppColors.textMuted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
