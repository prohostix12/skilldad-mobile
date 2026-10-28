import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// The live API sometimes encodes numeric fields (e.g. `progress`) as
/// strings, so every numeric field read from JSON goes through this instead
/// of a plain `as num` cast.
num? _toNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// One enrolled course, as returned by GET /api/enrollment/my-courses.
class EnrolledCourse {
  EnrolledCourse({
    required this.courseId,
    required this.title,
    required this.thumbnailUrl,
    required this.progress,
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final totalModules = _toNum(json['totalModules'])?.toInt() ?? 12;
    final completedModules = _toNum(json['completedModules'])?.toInt() ?? 0;
    final rawProgress = _toNum(json['progress']);
    final progress = rawProgress != null
        ? rawProgress.round()
        : (totalModules > 0 ? ((completedModules / totalModules) * 100).round() : 0);

    return EnrolledCourse(
      courseId: (course['_id'] ?? '').toString(),
      title: (course['title'] ?? 'Untitled course').toString(),
      thumbnailUrl: ApiConfig.mediaUrl((course['thumbnail'] ?? '').toString()),
      progress: progress.clamp(0, 100),
    );
  }

  final String courseId;
  final String title;
  final String thumbnailUrl;
  final int progress;

  bool get isCompleted => progress >= 100;
}

/// One item in the compact "Upcoming" list - a live session or an exam,
/// as GET /api/sessions and GET /api/exams/student/my-exams return them.
class UpcomingItem {
  UpcomingItem({required this.isSession, required this.title, required this.dateTime, this.examId});

  final bool isSession;
  final String title;
  final DateTime dateTime;

  /// Set only for exam entries - lets the dashboard open the real exam
  /// directly (GET /api/exams/student/my-exams's `id`/`_id`).
  final String? examId;
}

/// One point of the last-7-days performance line, as
/// GET /api/students/performance/weekly returns it.
class PerformancePoint {
  PerformancePoint({required this.label, required this.value});

  factory PerformancePoint.fromJson(Map<String, dynamic> json) {
    return PerformancePoint(
      label: (json['name'] ?? '').toString(),
      value: _toNum(json['value'])?.toDouble() ?? 0,
    );
  }

  final String label;
  final double value;
}

/// One live session, as returned in full by GET /api/sessions (the
/// dashboard's `upcoming` list only keeps a filtered top-3 slice of this
/// same data - the Live Sessions screen shows the complete real list).
class LiveSession {
  LiveSession({
    required this.id,
    required this.topic,
    required this.description,
    required this.category,
    required this.courseTitle,
    required this.instructorName,
    required this.instructorAvatar,
    required this.instructorTitle,
    required this.startTime,
    required this.durationMinutes,
    required this.status,
    required this.meetingLink,
    required this.recordingPlayUrl,
  });

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    final instructor = json['instructor'] as Map<String, dynamic>? ?? const {};
    final rec = json['recording'] as Map<String, dynamic>? ?? const {};
    final rawRecUrl = (rec['playUrl'] ?? rec['play_url'] ?? json['recordingUrl'] ?? '').toString();
    final recUrl = rawRecUrl.isNotEmpty ? ApiConfig.mediaUrl(rawRecUrl) : '';

    final rawInstAvatar = (instructor['avatar'] ?? instructor['profileImage'] ?? instructor['image'] ?? '').toString();
    final instAvatar = rawInstAvatar.isNotEmpty ? ApiConfig.mediaUrl(rawInstAvatar) : '';
    final instTitle = (instructor['title'] ?? instructor['role'] ?? instructor['designation'] ?? '').toString();

    return LiveSession(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      topic: (json['topic'] ?? 'Live Session').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      courseTitle: (course['title'] ?? '').toString(),
      instructorName: (instructor['name'] ?? '').toString(),
      instructorAvatar: instAvatar,
      instructorTitle: instTitle,
      startTime: DateTime.tryParse((json['startTime'] ?? '').toString()),
      durationMinutes: _toNum(json['duration'])?.toInt(),
      status: (json['status'] ?? 'scheduled').toString(),
      meetingLink: (json['meetingLink'] ?? json['meeting_link'] ?? '').toString(),
      recordingPlayUrl: recUrl,
    );
  }

  final String id;
  final String topic;
  final String description;
  final String category;
  final String courseTitle;
  final String instructorName;
  final String instructorAvatar;
  final String instructorTitle;
  final DateTime? startTime;
  final int? durationMinutes;
  final String status;
  final String meetingLink;
  final String recordingPlayUrl;

  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended' || status == 'archived';
  bool get isScheduled => status == 'scheduled';
  bool get hasRecording => recordingPlayUrl.isNotEmpty;
  bool get canJoin => meetingLink.isNotEmpty;
}

/// A real signal in the student's career journey. Mirrors the 6 steps
/// client/src/pages/student/StudentDashboard.jsx computes from real data -
/// no fabricated steps.
class CareerStep {
  const CareerStep({required this.label, required this.done});

  final String label;
  final bool done;
}

/// Everything the dashboard screen needs, aggregated from several real
/// endpoints the same way the web dashboard does (tolerant of individual
/// endpoint failures - a missing piece just renders empty/zero rather than
/// taking down the whole screen).
class DashboardData {
  const DashboardData({
    required this.enrolledCourses,
    required this.upcoming,
    required this.performance,
    required this.careerSteps,
    required this.careerGoal,
    required this.completionRate,
    required this.certificatesEarned,
    required this.pendingProjects,
    required this.pendingDocsAndCerts,
  });

  final List<EnrolledCourse> enrolledCourses;
  final List<UpcomingItem> upcoming;
  final List<PerformancePoint> performance;
  final List<CareerStep> careerSteps;
  final String? careerGoal;
  final int completionRate;
  final int certificatesEarned;
  final int pendingProjects;
  final int pendingDocsAndCerts;

  int get careerReadiness => careerSteps.isEmpty
      ? 0
      : ((careerSteps.where((s) => s.done).length / careerSteps.length) * 100).round();

  static const empty = DashboardData(
    enrolledCourses: [],
    upcoming: [],
    performance: [],
    careerSteps: [],
    careerGoal: null,
    completionRate: 0,
    certificatesEarned: 0,
    pendingProjects: 0,
    pendingDocsAndCerts: 0,
  );
}

/// Fetches the signed-in student's real dashboard data
/// (server/routes: enrollmentRoutes, sessionRoutes, certificateRoutes,
/// userRoutes' career-progress, studentPerformanceRoutes,
/// projectRoutes/documentRoutes, careerRoutes).
class DashboardService {
  DashboardService({http.Client? client}) : _client = client ?? http.Client();

  static DashboardService instance = DashboardService();

  final http.Client _client;

  Future<DashboardData> fetchDashboard(String token) async {
    final headers = {'Authorization': 'Bearer $token'};

    final results = await Future.wait([
      _getJson('/api/enrollment/my-courses', headers),
      _getJson('/api/sessions', headers),
      _getJson('/api/exams/student/my-exams', headers),
      _getJson('/api/certificates/my', headers),
      _getJson('/api/users/me/career-progress', headers),
      _getJson('/api/career/my-applications', headers),
      _getJson('/api/projects/my-projects', headers),
      _getJson('/api/documents/my-documents', headers),
      _postThenGetWeeklyPerformance(headers),
    ]);

    final coursesJson = results[0];
    final sessionsJson = results[1];
    final examsJson = results[2];
    final certsJson = results[3];
    final careerProgressJson = results[4];
    final applicationsJson = results[5];
    final projectsJson = results[6];
    final documentsJson = results[7];
    final performanceJson = results[8];

    final courses = (coursesJson is List ? coursesJson : const [])
        .whereType<Map<String, dynamic>>()
        .map(EnrolledCourse.fromJson)
        .toList();

    final now = DateTime.now();

    final sessions = (sessionsJson is List ? sessionsJson : const [])
        .whereType<Map<String, dynamic>>()
        .where((s) => s['status'] == 'scheduled' || s['status'] == 'live')
        .map((s) {
          final start = DateTime.tryParse((s['startTime'] ?? '').toString());
          return start == null
              ? null
              : UpcomingItem(isSession: true, title: (s['topic'] ?? 'Live Session').toString(), dateTime: start);
        })
        .whereType<UpcomingItem>();

    final rawExams = (examsJson is Map<String, dynamic> ? examsJson['data'] : examsJson);
    final exams = (rawExams is List ? rawExams : const [])
        .whereType<Map<String, dynamic>>()
        .where((e) => e['status'] == 'scheduled')
        .map((e) {
          final start = DateTime.tryParse((e['scheduledStartTime'] ?? '').toString());
          return start == null || !start.isAfter(now)
              ? null
              : UpcomingItem(
                  isSession: false,
                  title: (e['title'] ?? 'Exam').toString(),
                  dateTime: start,
                  examId: (e['id'] ?? e['_id'] ?? '').toString(),
                );
        })
        .whereType<UpcomingItem>();

    final upcoming = [...sessions, ...exams]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final certs = (certsJson is Map<String, dynamic> ? certsJson['data'] : certsJson);
    final certList = (certs is List ? certs : const []).whereType<Map<String, dynamic>>().toList();
    final certificatesEarned = certList.where((c) => c['status'] == 'ISSUED').length;
    final activeCerts = certList.where((c) => c['status'] == 'PENDING' || c['status'] == 'REQUESTED').length;

    final documents = (documentsJson is List ? documentsJson : const []).whereType<Map<String, dynamic>>();
    final pendingDocs = documents
        .where((d) => d['status'] == 'pending' || d['status'] == 'rejected' || d['verified'] != true)
        .length;

    final projects = (projectsJson is List ? projectsJson : const []).whereType<Map<String, dynamic>>();
    final pendingProjects = projects.where((p) => p['completed'] != true && p['status'] != 'approved').length;
    final hasSubmittedProject = projects.any(
      (p) => p['status'] == 'submitted' || p['status'] == 'graded',
    );

    final careerProgress = careerProgressJson is Map<String, dynamic> ? careerProgressJson : null;
    final applications = applicationsJson is Map<String, dynamic> ? applicationsJson['applications'] : null;
    final hasApplications = (applications is List ? applications : const []).isNotEmpty;

    final careerSteps = careerProgress == null
        ? <CareerStep>[]
        : [
            CareerStep(label: 'Career Assessment', done: (careerProgress['careerGoal'] ?? '').toString().isNotEmpty),
            CareerStep(label: 'Learning Path', done: courses.isNotEmpty),
            CareerStep(label: 'Skills & Projects', done: hasSubmittedProject),
            CareerStep(label: 'Resume Ready', done: careerProgress['hasResumeUploaded'] == true),
            CareerStep(label: 'Interview Preparation', done: careerProgress['interviewPrepCompleted'] == true),
            CareerStep(label: 'Apply to Jobs', done: hasApplications),
          ];

    final totalProgress = courses.fold<int>(0, (sum, c) => sum + c.progress);
    final completionRate = courses.isEmpty ? 0 : (totalProgress / courses.length).round();

    final performance = (performanceJson is List ? performanceJson : const [])
        .whereType<Map<String, dynamic>>()
        .map(PerformancePoint.fromJson)
        .toList();

    return DashboardData(
      enrolledCourses: courses,
      upcoming: upcoming.take(3).toList(),
      performance: performance,
      careerSteps: careerSteps,
      careerGoal: careerProgress?['careerGoal']?.toString(),
      completionRate: completionRate,
      certificatesEarned: certificatesEarned,
      pendingProjects: pendingProjects,
      pendingDocsAndCerts: activeCerts + pendingDocs,
    );
  }

  /// The complete real session list for the "Live Sessions" screen -
  /// unlike [fetchDashboard]'s `upcoming`, this isn't filtered to
  /// scheduled-only or truncated to 3.
  Future<List<LiveSession>> fetchSessions(String token) async {
    final headers = {'Authorization': 'Bearer $token'};
    final json = await _getJson('/api/sessions', headers);
    final sessions = (json is List ? json : const [])
        .whereType<Map<String, dynamic>>()
        .map(LiveSession.fromJson)
        .toList();
    sessions.sort((a, b) {
      if (a.startTime == null) return 1;
      if (b.startTime == null) return -1;
      return b.startTime!.compareTo(a.startTime!);
    });
    return sessions;
  }

  Future<dynamic> _postThenGetWeeklyPerformance(Map<String, String> headers) async {
    try {
      await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/students/performance/snapshot'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Non-blocking, same as the web dashboard - a failed snapshot write
      // shouldn't stop the weekly series from being read.
    }
    return _getJson('/api/students/performance/weekly', headers);
  }

  Future<dynamic> _getJson(String path, Map<String, String> headers) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }
}
