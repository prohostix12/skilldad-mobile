import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import 'jobs_screen.dart';
import 'my_courses_screen.dart';

/// Full career journey and path details screen for enrolled students.
/// Displays detailed breakdown of the 6 real career readiness signals,
/// milestone tracker, target goals, and direct action triggers.
class CareerPathScreen extends StatelessWidget {
  const CareerPathScreen({
    super.key,
    required this.data,
    required this.token,
  });

  final DashboardData data;
  final String token;

  static const List<Map<String, dynamic>> _stepMetadata = [
    {
      'key': 'assessment',
      'label': 'Career Assessment',
      'icon': Icons.psychology_outlined,
      'desc': 'Define your career aspiration, benchmark your competencies, and choose your specialization track.',
      'actionLabel': null,
    },
    {
      'key': 'learning',
      'label': 'Learning Path',
      'icon': Icons.school_outlined,
      'desc': 'Complete industry-aligned curriculum modules, live sessions, and academic masterclasses.',
      'actionLabel': 'View Enrolled Courses',
    },
    {
      'key': 'skills',
      'label': 'Skills & Projects',
      'icon': Icons.assignment_turned_in_outlined,
      'desc': 'Submit hands-on capstone projects, lab assignments, and industry case studies for review.',
      'actionLabel': null,
    },
    {
      'key': 'resume',
      'label': 'Resume Ready',
      'icon': Icons.description_outlined,
      'desc': 'Upload an ATS-compliant resume tailored for hiring recruiters in top technology firms.',
      'actionLabel': null,
    },
    {
      'key': 'interview',
      'label': 'Interview Preparation',
      'icon': Icons.record_voice_over_outlined,
      'desc': 'Complete mock technical screenings, HR evaluation sessions, and behavioral practice.',
      'actionLabel': null,
    },
    {
      'key': 'apply',
      'label': 'Apply to Jobs',
      'icon': Icons.work_outline_rounded,
      'desc': 'Submit applications to verified partner vacancies and corporate recruitment drives.',
      'actionLabel': 'Browse Vacancies',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final completedCount = data.careerSteps.where((s) => s.done).length;
    final totalSteps = data.careerSteps.length;
    final readinessPercent = data.careerReadiness;
    final careerGoal = data.careerGoal?.isNotEmpty == true ? data.careerGoal! : 'Industry Specialist Track';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.fieldBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Career Journey',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Milestones & Placement Readiness',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                children: [
                  // Hero Readiness Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stars_rounded, size: 13, color: Colors.white),
                                  SizedBox(width: 5),
                                  Text(
                                    'Career Readiness',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$readinessPercent%',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          careerGoal,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$completedCount of $totalSteps career milestones completed. Follow each stage to accelerate enterprise interviews and job placements.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: readinessPercent / 100.0,
                            minHeight: 7,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Roadmap Section Title
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'STEP-BY-STEP ROADMAP',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Milestone Steps Timeline
                  for (int i = 0; i < data.careerSteps.length; i++) ...[
                    _MilestoneCard(
                      index: i + 1,
                      isLast: i == data.careerSteps.length - 1,
                      step: data.careerSteps[i],
                      meta: i < _stepMetadata.length ? _stepMetadata[i] : null,
                      onActionTap: () {
                        final meta = i < _stepMetadata.length ? _stepMetadata[i] : null;
                        if (meta?['key'] == 'learning') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MyCoursesScreen(
                                courses: data.enrolledCourses,
                                token: token,
                              ),
                            ),
                          );
                        } else if (meta?['key'] == 'apply') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JobsScreen(
                                token: token,
                                courses: data.enrolledCourses,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Bottom Action Strip
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MyCoursesScreen(
                                  courses: data.enrolledCourses,
                                  token: token,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: const Text('My Courses'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.fieldBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => JobsScreen(
                                  token: token,
                                  courses: data.enrolledCourses,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.work_outline_rounded, size: 16),
                          label: const Text('Explore Jobs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
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
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.index,
    required this.isLast,
    required this.step,
    required this.meta,
    required this.onActionTap,
  });

  final int index;
  final bool isLast;
  final CareerStep step;
  final Map<String, dynamic>? meta;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final icon = (meta?['icon'] as IconData?) ?? Icons.flag_rounded;
    final desc = (meta?['desc'] as String?) ?? 'Progress milestone in your career journey.';
    final actionLabel = meta?['actionLabel'] as String?;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: step.done ? const Color(0xFF10B981) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: step.done ? const Color(0xFF10B981) : const Color(0xFFDDD6FE),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (step.done ? const Color(0xFF10B981) : AppColors.primary).withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  step.done ? Icons.check_rounded : icon,
                  size: 15,
                  color: step.done ? Colors.white : AppColors.primary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.done ? const Color(0xFF10B981).withValues(alpha: 0.5) : AppColors.fieldBorder,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 14),

          // Milestone Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: step.done ? const Color(0xFFD1FAE5) : const Color(0xFFEDE9FE),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.label,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: step.done ? const Color(0xFFECFDF5) : const Color(0xFFF3EDFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              step.done ? Icons.check_circle_rounded : Icons.pending_outlined,
                              size: 11,
                              color: step.done ? const Color(0xFF059669) : AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              step.done ? 'COMPLETED' : 'IN PROGRESS',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: step.done ? const Color(0xFF059669) : AppColors.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: onActionTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
