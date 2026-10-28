import 'dart:async';

import 'package:flutter/material.dart';

import '../services/exam_service.dart';
import '../theme/app_colors.dart';
import 'exam_result_screen.dart';

/// The real exam-taking window - one question at a time with a live
/// countdown and auto-submit on expiry, matching
/// client/src/pages/student/Exams.jsx's real exam flow
/// (POST /api/exams/:examId/start, /:submissionId/answer, /:submissionId/submit).
class ExamTakingScreen extends StatefulWidget {
  const ExamTakingScreen({super.key, required this.exam, required this.token});

  final Exam exam;
  final String token;

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  ExamSession? _session;
  bool _startFailed = false;
  int _currentIndex = 0;
  final Map<String, int> _answers = {};
  Timer? _timer;
  int _secondsLeft = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final session = await ExamService.instance.startExam(widget.exam.id, widget.token);
    if (!mounted) return;
    if (session == null) {
      setState(() => _startFailed = true);
      return;
    }
    setState(() {
      _session = session;
      _secondsLeft = session.timeRemainingSeconds ?? widget.exam.durationMinutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        _submit(isAutoSubmit: true);
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _selectAnswer(ExamQuestion question, int optionIndex) {
    setState(() => _answers[question.id] = optionIndex);
    ExamService.instance.saveAnswer(
      submissionId: _session!.submissionId,
      questionId: question.id,
      selectedOption: optionIndex,
      token: widget.token,
    );
  }

  Future<void> _submit({bool isAutoSubmit = false}) async {
    final session = _session;
    if (session == null || _submitting) return;
    setState(() => _submitting = true);

    final answers = _answers.entries
        .map((entry) => {'questionId': entry.key, 'selectedOption': entry.value})
        .toList();

    await ExamService.instance.submitExam(
      submissionId: session.submissionId,
      answers: answers,
      isAutoSubmit: isAutoSubmit,
      token: widget.token,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ExamResultScreen(examId: widget.exam.id, examTitle: widget.exam.title, token: widget.token),
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final unanswered = (_session?.questions.length ?? 0) - _answers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(
          unanswered > 0
              ? 'You have $unanswered unanswered question${unanswered == 1 ? '' : 's'}. Submit anyway?'
              : 'Your answers will be submitted and graded.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) _submit();
  }

  String get _timerText {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave exam?'),
            content: const Text('Your progress is saved, but the timer keeps running.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: session == null
              ? Center(
                  child: _startFailed
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "Couldn't start this exam. Check your connection and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        )
                      : const CircularProgressIndicator(),
                )
              : session.questions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'This exam has no questions yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                )
              : _buildExam(session),
        ),
      ),
    );
  }

  Widget _buildExam(ExamSession session) {
    final question = session.questions[_currentIndex];
    final total = session.questions.length;
    final selected = _answers[question.id];
    final answeredCount = _answers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              _RoundIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.exam.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _secondsLeft < 60 ? AppColors.error.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, size: 15, color: _secondsLeft < 60 ? AppColors.error : AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      _timerText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _secondsLeft < 60 ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.fieldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Quiz Practice',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        '${_currentIndex + 1} / $total  •  $answeredCount/$total answered',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / total,
                      minHeight: 5,
                      backgroundColor: AppColors.fieldBorder,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${_currentIndex + 1}. ${question.questionText}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < question.options.length; i++) ...[
                    _ExamOptionTile(
                      letter: String.fromCharCode(97 + i),
                      label: question.options[i].text,
                      isSelected: selected == i,
                      onTap: () => _selectAnswer(question, i),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentIndex -= 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.fieldBorder),
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : _currentIndex < total - 1
                      ? () => setState(() => _currentIndex += 1)
                      : _confirmSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_currentIndex < total - 1 ? 'Next' : 'Submit Exam'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.fieldBorder),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

/// A full-width rounded answer pill - "a. / b. / c." prefix plus the real
/// option text - matching a standard mobile quiz-practice card layout.
class _ExamOptionTile extends StatelessWidget {
  const _ExamOptionTile({required this.letter, required this.label, required this.isSelected, required this.onTap});

  final String letter;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.fieldBorder, width: isSelected ? 1.6 : 1),
        ),
        child: Text(
          '$letter. $label',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
