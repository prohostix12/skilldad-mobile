import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One answer option for an MCQ exam question. `isCorrect` is only ever
/// populated server-side while the exam is active or in the post-result
/// review - never shown to the student while they're still answering.
class ExamOption {
  ExamOption({required this.text, required this.isCorrect});

  factory ExamOption.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return ExamOption(
        text: (json['text'] ?? '').toString(),
        isCorrect: json['isCorrect'] == true || json['correct'] == true || json['is_correct'] == true,
      );
    }
    return ExamOption(text: json.toString(), isCorrect: false);
  }

  final String text;
  final bool isCorrect;
}

/// One real exam question (server/controllers/examController.js's
/// `questions` table row) - MCQ or descriptive.
class ExamQuestion {
  ExamQuestion({
    required this.id,
    required this.questionText,
    required this.questionType,
    required this.options,
    required this.marks,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return ExamQuestion(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      questionText: (json['questionText'] ?? json['question'] ?? '').toString(),
      questionType: (json['questionType'] ?? 'mcq').toString(),
      options: (rawOptions is List ? rawOptions : const []).map(ExamOption.fromJson).toList(),
      marks: _toInt(json['marks']) ?? 1,
    );
  }

  final String id;
  final String questionText;
  final String questionType;
  final List<ExamOption> options;
  final int marks;

  bool get isMcq => questionType == 'mcq' || questionType == 'online-mcq';
}

/// One real exam (server: `exams` table via GET /api/exams/student/my-exams).
class Exam {
  Exam({
    required this.id,
    required this.title,
    required this.courseTitle,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.durationMinutes,
    required this.totalMarks,
    required this.status,
    required this.questions,
    required this.hasSubmitted,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final rawQuestions = json['questions'];
    return Exam(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Exam').toString(),
      courseTitle: (course['title'] ?? '').toString(),
      scheduledStart: DateTime.tryParse((json['scheduledStartTime'] ?? '').toString()),
      scheduledEnd: DateTime.tryParse((json['scheduledEndTime'] ?? '').toString()),
      durationMinutes: _toInt(json['duration']) ?? 30,
      totalMarks: _toInt(json['totalMarks']) ?? 0,
      status: (json['status'] ?? 'scheduled').toString(),
      questions: (rawQuestions is List ? rawQuestions : const [])
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestion.fromJson)
          .toList(),
      hasSubmitted: json['hasSubmitted'] == true,
    );
  }

  final String id;
  final String title;
  final String courseTitle;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int durationMinutes;
  final int totalMarks;
  final String status;
  final List<ExamQuestion> questions;
  final bool hasSubmitted;

  bool get isOpen {
    final now = DateTime.now();
    final start = scheduledStart;
    final end = scheduledEnd;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }
}

/// A started exam attempt (POST /api/exams/:examId/start's response).
class ExamSession {
  ExamSession({required this.submissionId, required this.questions, required this.timeRemainingSeconds});

  factory ExamSession.fromJson(Map<String, dynamic> json) {
    final submission = json['submission'] as Map<String, dynamic>? ?? const {};
    final rawQuestions = json['questions'];
    return ExamSession(
      submissionId: (submission['_id'] ?? submission['id'] ?? '').toString(),
      questions: (rawQuestions is List ? rawQuestions : const [])
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestion.fromJson)
          .toList(),
      timeRemainingSeconds: _toInt(json['timeRemaining']),
    );
  }

  final String submissionId;
  final List<ExamQuestion> questions;

  /// Null when the server doesn't track a hard access-window remainder -
  /// the exam's own [Exam.durationMinutes] is then the real countdown length.
  final int? timeRemainingSeconds;
}

/// One answered-and-graded question, as shown on the real result/answer
/// review screen (GET /api/exams/exam/:examId/my-submission).
class ExamAnswerReview {
  ExamAnswerReview({
    required this.questionText,
    required this.options,
    required this.selectedOption,
    required this.isCorrect,
  });

  factory ExamAnswerReview.fromJson(Map<String, dynamic> json) {
    final question = json['question'] as Map<String, dynamic>? ?? const {};
    final rawOptions = question['options'];
    final selected = json['selectedOption'];
    return ExamAnswerReview(
      questionText: (question['questionText'] ?? question['question'] ?? '').toString(),
      options: (rawOptions is List ? rawOptions : const []).map(ExamOption.fromJson).toList(),
      selectedOption: selected is num ? selected.toInt() : null,
      isCorrect: json['isCorrect'] == true,
    );
  }

  final String questionText;
  final List<ExamOption> options;
  final int? selectedOption;
  final bool isCorrect;

  String? get selectedOptionText =>
      (selectedOption != null && selectedOption! >= 0 && selectedOption! < options.length)
      ? options[selectedOption!].text
      : null;

  String? get correctOptionText {
    for (final option in options) {
      if (option.isCorrect) return option.text;
    }
    return null;
  }
}

/// The real result for one exam (GET /api/exams/exam/:examId/my-submission).
class ExamResult {
  ExamResult({
    required this.obtainedMarks,
    required this.totalMarks,
    required this.passed,
    required this.answers,
    required this.resultsPending,
  });

  factory ExamResult.pending() =>
      ExamResult(obtainedMarks: 0, totalMarks: 0, passed: false, answers: const [], resultsPending: true);

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    final submission = json['submission'] as Map<String, dynamic>? ?? const {};
    final rawAnswers = submission['answers'];
    final obtained = _toNum(submission['obtainedMarks']) ?? 0;
    final total = _toNum(submission['totalMarks']) ?? 0;
    return ExamResult(
      obtainedMarks: obtained,
      totalMarks: total,
      passed: total > 0 ? (obtained / total * 100) >= 40 : false,
      answers: (rawAnswers is List ? rawAnswers : const [])
          .whereType<Map<String, dynamic>>()
          .map(ExamAnswerReview.fromJson)
          .toList(),
      resultsPending: false,
    );
  }

  final num obtainedMarks;
  final num totalMarks;
  final bool passed;
  final List<ExamAnswerReview> answers;
  final bool resultsPending;

  int get percentage => totalMarks > 0 ? ((obtainedMarks / totalMarks) * 100).round().clamp(0, 100) : 0;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// Real exams - server/controllers/examController.js and
/// server/controllers/examSubmissionController.js, mounted at /api/exams.
class ExamService {
  ExamService({http.Client? client}) : _client = client ?? http.Client();

  static ExamService instance = ExamService();

  final http.Client _client;

  Future<List<Exam>> fetchMyExams(String token) async {
    final json = await _get('/api/exams/student/my-exams', token);
    if (json == null) return const [];
    final data = json is Map<String, dynamic> ? json['data'] : json;
    return (data is List ? data : const []).whereType<Map<String, dynamic>>().map(Exam.fromJson).toList();
  }

  Future<ExamSession?> startExam(String examId, String token) async {
    final json = await _post('/api/exams/$examId/start', const {}, token);
    if (json == null) return null;
    return ExamSession.fromJson(json);
  }

  /// Auto-save for one answer - fire-and-forget from the UI's perspective,
  /// mirroring the web app's per-question save while an exam is in progress.
  Future<void> saveAnswer({
    required String submissionId,
    required String questionId,
    required int selectedOption,
    required String token,
  }) async {
    await _post(
      '/api/exams/$submissionId/answer',
      {'questionId': questionId, 'selectedOption': selectedOption},
      token,
    );
  }

  Future<bool> submitExam({
    required String submissionId,
    required List<Map<String, dynamic>> answers,
    required bool isAutoSubmit,
    required String token,
  }) async {
    final json = await _post(
      '/api/exams/$submissionId/submit',
      {'isAutoSubmit': isAutoSubmit, 'answers': answers},
      token,
    );
    return json != null && json['success'] == true;
  }

  Future<ExamResult> fetchMyResult(String examId, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/exams/exam/$examId/my-submission'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 403) return ExamResult.pending();
      if (response.statusCode != 200) return ExamResult.pending();
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return ExamResult.pending();
      return ExamResult.fromJson(decoded);
    } catch (_) {
      return ExamResult.pending();
    }
  }

  Future<dynamic> _get(String path, String token) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body, String token) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
