import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// A single-question legacy exercise attached to a lesson
/// (server/controllers/courseController.js's `video.exercises[0]`).
class LessonExercise {
  LessonExercise({required this.question, required this.options, required this.correctAnswer});

  factory LessonExercise.fromJson(Map<String, dynamic> json) {
    return LessonExercise(
      question: (json['question'] ?? '').toString(),
      options: (json['options'] is List)
          ? (json['options'] as List).map((e) => e.toString()).toList()
          : const [],
      correctAnswer: (json['correctAnswer'] ?? '').toString(),
    );
  }

  final String question;
  final List<String> options;
  final String correctAnswer;
}

/// One lesson video within a module. `url` and `exercises` are only present
/// when the server recognises the student as enrolled
/// (GET /api/courses/:id via `optionalProtect`, which strips them for
/// anyone else) - this is the real content, not a demo stub.
///
/// When an instructor builds a multi-question lesson quiz
/// (server/controllers/courseController.js's `saveLessonQuiz`), the server
/// auto-populates this same `exercises` array with one entry per quiz
/// question - so the full real quiz is already here, not just one question.
class CourseLesson {
  CourseLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.duration,
    this.thumbnailUrl = '',
    this.contentType = 'video',
    this.fileName = '',
    this.fileType = '',
    required this.exercises,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    final rawExercises = json['exercises'];
    final rawThumb = (json['thumbnail'] ?? json['thumbnailUrl'] ?? json['coverImage'] ?? '').toString();
    final urlStr = (json['url'] ?? '').toString();
    final cType = (json['contentType'] ?? json['type'] ?? json['videoType'] ?? '').toString().toLowerCase();
    final fName = (json['fileName'] ?? '').toString();
    final fType = (json['fileType'] ?? '').toString();
    return CourseLesson(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Lesson').toString(),
      description: (json['description'] ?? '').toString().trim(),
      url: urlStr,
      duration: (json['duration'] ?? '').toString(),
      thumbnailUrl: _extractVideoThumbnail(urlStr, rawThumb),
      contentType: cType,
      fileName: fName,
      fileType: fType,
      exercises: (rawExercises is List ? rawExercises : const [])
          .whereType<Map<String, dynamic>>()
          .map(LessonExercise.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String url;
  final String duration;
  final String thumbnailUrl;
  final String contentType;
  final String fileName;
  final String fileType;
  final List<LessonExercise> exercises;

  bool get isDocument =>
      contentType == 'document' ||
      contentType == 'pdf' ||
      url.toLowerCase().endsWith('.pdf') ||
      url.toLowerCase().contains('/document-') ||
      fileType.toLowerCase().contains('pdf') ||
      RegExp(r'study\s*material|document|reading|notes?|assignment', caseSensitive: false).hasMatch(title);

  bool get hasContent => url.trim().isNotEmpty;
  bool get hasVideo => !isDocument && url.trim().isNotEmpty;
  bool get hasExercises => exercises.isNotEmpty;

  String get fullDocumentUrl => ApiConfig.mediaUrl(url);
}

String _extractVideoThumbnail(String url, [String? explicitThumb]) {
  if (explicitThumb != null) {
    final clean = explicitThumb.trim();
    if (clean.isNotEmpty && clean != 'null' && clean != 'undefined') {
      return ApiConfig.mediaUrl(clean);
    }
  }
  if (url.trim().isEmpty) return '';
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return '';
  String? videoId;
  if (uri.host.contains('youtube.com')) {
    if (uri.pathSegments.contains('watch')) {
      videoId = uri.queryParameters['v'];
    } else if (uri.pathSegments.contains('embed')) {
      final idx = uri.pathSegments.indexOf('embed');
      if (idx + 1 < uri.pathSegments.length) videoId = uri.pathSegments[idx + 1];
    }
  } else if (uri.host.contains('youtu.be')) {
    if (uri.pathSegments.isNotEmpty) videoId = uri.pathSegments.first;
  }
  if (videoId != null && videoId.isNotEmpty) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }
  return '';
}

String cleanCourseDescription(String text) {
  if (text.isEmpty) return '';
  return text
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n{2,}'))
      .map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
      .where((p) => p.isNotEmpty)
      .join('\n\n');
}

/// A module (section) of a course, holding its lessons.
class CourseModule {
  CourseModule({
    required this.id,
    required this.title,
    this.coverUrl = '',
    required this.lessons,
  });

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    final rawVideos = json['videos'];
    final coverRaw = (json['coverImage'] ?? json['cover_image'] ?? json['thumbnail'] ?? json['image'] ?? '').toString();
    return CourseModule(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Module').toString(),
      coverUrl: coverRaw.isNotEmpty ? ApiConfig.mediaUrl(coverRaw) : '',
      lessons: (rawVideos is List ? rawVideos : const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseLesson.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String coverUrl;
  final List<CourseLesson> lessons;

  String effectiveCoverUrl({String courseThumbnail = ''}) {
    if (coverUrl.isNotEmpty) return coverUrl;
    for (final l in lessons) {
      if (l.thumbnailUrl.isNotEmpty) return l.thumbnailUrl;
    }
    return courseThumbnail;
  }
}

/// The full real course content (GET /api/courses/:id) for the enrolled
/// student currently signed in.
class CoursePlayerDetail {
  CoursePlayerDetail({
    this.id = '',
    required this.title,
    this.description = '',
    this.thumbnailUrl = '',
    this.category = '',
    this.instructorName = '',
    this.universityName = '',
    this.durationWeeks = '',
    this.price = '',
    required this.modules,
  });

  factory CoursePlayerDetail.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'];
    return CoursePlayerDetail(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? 'Course').toString().trim(),
      description: cleanCourseDescription((json['description'] ?? '').toString()),
      thumbnailUrl: ApiConfig.mediaUrl((json['thumbnail'] ?? '').toString()),
      category: (json['category'] ?? '').toString().trim(),
      instructorName: (json['instructor_name'] ?? json['instructorName'] ?? (json['instructor'] is Map ? json['instructor']['name'] : '') ?? '').toString().trim(),
      universityName: (json['university_name'] ?? json['universityName'] ?? '').toString().trim(),
      durationWeeks: (json['duration_weeks'] ?? json['durationWeeks'] ?? '').toString().trim(),
      price: (json['price'] ?? '').toString().trim(),
      modules: (rawModules is List ? rawModules : const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseModule.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String category;
  final String instructorName;
  final String universityName;
  final String durationWeeks;
  final String price;
  final List<CourseModule> modules;

  int get totalLessons => modules.fold(0, (sum, m) => sum + m.lessons.length);
}

/// The student's real saved progress for one course
/// (from GET /api/enrollment/my-courses).
class CourseProgressState {
  const CourseProgressState({
    required this.completedVideoIds,
    required this.completedExerciseVideoIds,
    this.isEnrolled = false,
  });

  static const empty = CourseProgressState(completedVideoIds: <String>{}, completedExerciseVideoIds: <String>{});

  final Set<String> completedVideoIds;
  final Set<String> completedExerciseVideoIds;

  /// Whether the student has a real enrollment row for this course at all -
  /// distinct from having zero progress within one.
  final bool isEnrolled;
}

/// Watches lessons and completes exercises against the real SkillDad API -
/// server/controllers/courseController.js's getCourse and
/// server/controllers/enrollmentController.js's updateProgress.
class CoursePlayerService {
  CoursePlayerService({http.Client? client}) : _client = client ?? http.Client();

  static CoursePlayerService instance = CoursePlayerService();

  final http.Client _client;

  Future<CoursePlayerDetail?> fetchCourseDetail(String courseId, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return CoursePlayerDetail.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<CourseProgressState> fetchProgress(String courseId, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/enrollment/my-courses'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return CourseProgressState.empty;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return CourseProgressState.empty;

      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final course = entry['course'];
        final id = course is Map<String, dynamic> ? (course['_id'] ?? course['id'] ?? '').toString() : '';
        if (id != courseId) continue;

        final completedVideos = (entry['completedVideos'] is List ? entry['completedVideos'] as List : const [])
            .map((e) => e.toString())
            .toSet();
        final completedExercises =
            (entry['completedExercises'] is List ? entry['completedExercises'] as List : const [])
                .whereType<Map<String, dynamic>>()
                .map((e) => (e['video'] ?? '').toString())
                .where((id) => id.isNotEmpty)
                .toSet();
        return CourseProgressState(
          completedVideoIds: completedVideos,
          completedExerciseVideoIds: completedExercises,
          isEnrolled: true,
        );
      }
      return CourseProgressState.empty;
    } catch (_) {
      return CourseProgressState.empty;
    }
  }

  /// Marks a lesson's video watched. Returns the course's updated overall
  /// progress percentage, or null if the request failed.
  Future<int?> markVideoComplete(String courseId, String videoId, String token) async {
    return _putProgress({'courseId': courseId, 'videoId': videoId}, token);
  }

  /// Records the real exercise/quiz score (0-100) against the same
  /// endpoint, matching the web app's `Math.round(score/total*100)`.
  Future<int?> submitExerciseScore(String courseId, String videoId, int scorePercent, String token) async {
    return _putProgress({'courseId': courseId, 'videoId': videoId, 'exerciseScore': scorePercent}, token);
  }

  Future<int?> _putProgress(Map<String, dynamic> body, String token) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/enrollment/progress'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['progress'] != null) {
        final progress = decoded['progress'];
        if (progress is num) return progress.round();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
