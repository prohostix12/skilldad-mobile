import 'package:flutter/material.dart';

import '../services/exam_service.dart';
import '../theme/app_colors.dart';

/// The real result / answer-sheet screen for one exam
/// (GET /api/exams/exam/:examId/my-submission) - score, pass/fail, and a
/// per-question review that reveals the correct answer only where the
/// student got it wrong, matching client/src/pages/student/ExamResult.jsx.
class ExamResultScreen extends StatefulWidget {
  const ExamResultScreen({super.key, required this.examId, required this.examTitle, required this.token});

  final String examId;
  final String examTitle;
  final String token;

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  ExamResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ExamService.instance.fetchMyResult(widget.examId, widget.token);
    if (!mounted) return;
    setState(() => _result = result);
  }

  String _grade(int percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    if (percentage >= 40) return 'E';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

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
                  Expanded(
                    child: Text(
                      widget.examTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: result == null
                  ? const Center(child: CircularProgressIndicator())
                  : result.resultsPending
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 40, color: AppColors.textMuted),
                            SizedBox(height: 14),
                            Text(
                              'Your exam has been submitted.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Results have not been published yet. Your institution will notify you once they are available.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _ScoreCard(result: result, grade: _grade(result.percentage)),
                        const SizedBox(height: 22),
                        if (result.answers.isNotEmpty) ...[
                          const Text(
                            'Answer Review',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < result.answers.length; i++) ...[
                            _AnswerReviewCard(index: i + 1, review: result.answers[i]),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result, required this.grade});

  final ExamResult result;
  final String grade;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: result.passed
              ? [Colors.green.shade600, Colors.green.shade400]
              : [AppColors.error, const Color(0xFFEF6666)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(result.passed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 10),
          Text(
            result.passed ? 'You Passed!' : 'Not Passed',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ScoreStat(label: 'Score', value: '${result.obtainedMarks}/${result.totalMarks}'),
              _ScoreStat(label: 'Percentage', value: '${result.percentage}%'),
              _ScoreStat(label: 'Grade', value: grade),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(
              result.passed ? 'Above passing score' : 'Below passing score',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStat extends StatelessWidget {
  const _ScoreStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  const _AnswerReviewCard({required this.index, required this.review});

  final int index;
  final ExamAnswerReview review;

  @override
  Widget build(BuildContext context) {
    final color = review.isCorrect ? Colors.green : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(review.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q$index. ${review.questionText}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your answer: ${review.selectedOptionText ?? 'Not answered'}',
            style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600),
          ),
          if (!review.isCorrect && review.correctOptionText != null) ...[
            const SizedBox(height: 4),
            Text(
              'Correct answer: ${review.correctOptionText}',
              style: const TextStyle(fontSize: 12.5, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
