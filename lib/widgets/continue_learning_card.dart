import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';

/// The "Continue Learning" course card matching the reference mockup:
/// rounded thumbnail, status pill (In Progress / Completed), action arrow,
/// title, progress bar with percentage, and lectures / time stats row.
class ContinueLearningCard extends StatelessWidget {
  const ContinueLearningCard({super.key, required this.course, this.onTap});

  final EnrolledCourse course;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const totalLectures = 20;
    final completedLectures = (course.progress * totalLectures / 100).round();
    final remainingLectures = totalLectures - completedLectures;
    final remainingMinutes = remainingLectures * 34;
    final hours = remainingMinutes ~/ 60;
    final mins = (remainingMinutes % 60) > 15 ? 30 : 0;
    final timeLeft = course.isCompleted
        ? 'Completed'
        : hours > 0
            ? '${hours}h ${mins > 0 ? '${mins}m ' : ''}left'
            : '${remainingMinutes}m left';

    final isCompleted = course.isCompleted;
    final statusColor = isCompleted ? const Color(0xFF16A34A) : const Color(0xFF6D28D9);
    final statusBg = isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFF3E8FF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF1EFF8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: course.thumbnailUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFF3F0FA),
                            child: const Icon(Icons.school_rounded, color: AppColors.primaryLight, size: 36),
                          )
                        : Image.network(
                            course.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF3F0FA),
                              child: const Icon(Icons.school_rounded, color: AppColors.primaryLight, size: 36),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCompleted ? Icons.check_circle_outline_rounded : Icons.play_arrow_rounded,
                                  size: 13,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCompleted ? 'Completed' : 'In Progress',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4C1D95),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: Color(0xFF14102B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: (course.progress / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF0EDF9),
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${course.progress}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_outlined,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$completedLectures / $totalLectures Lectures',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                  Container(
                    height: 12,
                    width: 1,
                    color: const Color(0xFFE5E7EB),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeLeft,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                    ),
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

