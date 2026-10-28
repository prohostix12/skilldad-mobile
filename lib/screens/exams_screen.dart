import 'package:flutter/material.dart';

import '../services/exam_service.dart';
import '../theme/app_colors.dart';
import 'exam_result_screen.dart';
import 'exam_taking_screen.dart';

/// Every real exam for the student's enrolled courses
/// (GET /api/exams/student/my-exams) - taps into the same real exam-taking
/// and result flow as the website.
class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, required this.token});

  final String token;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  List<Exam>? _exams;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exams = await ExamService.instance.fetchMyExams(widget.token);
    if (!mounted) return;
    setState(() => _exams = exams);
  }

  void _openExam(Exam exam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => exam.hasSubmitted
            ? ExamResultScreen(examId: exam.id, examTitle: exam.title, token: widget.token)
            : ExamTakingScreen(exam: exam, token: widget.token),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exams = _exams;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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
                  const SizedBox(width: 12),
                  const Text(
                    'Exams',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: exams == null
                  ? const Center(child: CircularProgressIndicator())
                  : exams.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No exams have been scheduled for your courses yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        itemCount: exams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _ExamCard(exam: exams[index], onTap: () => _openExam(exams[index])),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});

  final Exam exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = exam.hasSubmitted
        ? ('Submitted', Colors.green)
        : exam.isOpen
        ? ('Open Now', AppColors.primary)
        : ('Scheduled', AppColors.textMuted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
                ),
              ],
            ),
            if (exam.courseTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                exam.courseTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaItem(icon: Icons.schedule_rounded, label: _formatWhen(exam.scheduledStart)),
                _MetaItem(icon: Icons.timer_outlined, label: '${exam.durationMinutes} min'),
                if (exam.totalMarks > 0) _MetaItem(icon: Icons.star_border_rounded, label: '${exam.totalMarks} marks'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatWhen(DateTime? dt) {
    if (dt == null) return 'Time unavailable';
    return '${dt.day}/${dt.month}/${dt.year} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ],
    );
  }
}
