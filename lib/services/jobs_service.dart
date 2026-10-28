import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One job/internship vacancy, as returned by GET /api/career/vacancies.
class Vacancy {
  Vacancy({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.location,
    required this.jobType,
    required this.salaryRange,
    required this.deadline,
    required this.status,
  });

  factory Vacancy.fromJson(Map<String, dynamic> json) {
    return Vacancy(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled role').toString(),
      company: (json['company'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      jobType: (json['job_type'] ?? 'Job').toString(),
      salaryRange: (json['salary_range'] ?? '').toString(),
      deadline: DateTime.tryParse((json['deadline'] ?? '').toString()),
      status: (json['status'] ?? 'open').toString(),
    );
  }

  final String id;
  final String title;
  final String company;
  final String description;
  final String location;
  final String jobType;
  final String salaryRange;
  final DateTime? deadline;
  final String status;

  bool get isOpen => status == 'open';
  bool get isExpired => deadline != null && deadline!.isBefore(DateTime.now());
}

/// Fetches real job/internship vacancies and the signed-in student's real
/// applications (server/controllers/careerController.js).
class JobsService {
  JobsService({http.Client? client}) : _client = client ?? http.Client();

  static JobsService instance = JobsService();

  final http.Client _client;

  Future<List<Vacancy>> fetchVacancies() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/career/vacancies'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final json = jsonDecode(response.body);
      final vacancies = json is Map<String, dynamic> ? json['vacancies'] : null;
      return (vacancies is List ? vacancies : const [])
          .whereType<Map<String, dynamic>>()
          .map(Vacancy.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Vacancy IDs the student has already applied to.
  Future<Set<String>> fetchAppliedVacancyIds(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/career/my-applications'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const {};
      final json = jsonDecode(response.body);
      final applications = json is Map<String, dynamic> ? json['applications'] : null;
      return (applications is List ? applications : const [])
          .whereType<Map<String, dynamic>>()
          .map((a) => (a['vacancy_id'] ?? '').toString())
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  /// Applies to a vacancy without an attached resume (resume upload isn't
  /// wired up on mobile yet - the server accepts an application either way).
  Future<void> applyToVacancy(String vacancyId, String token) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/career/vacancies/$vacancyId/apply'),
    )..headers['Authorization'] = 'Bearer $token';
    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 400) {
      String message = 'Could not submit your application. Please try again.';
      try {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic> && json['message'] != null) {
          message = json['message'].toString();
        }
      } catch (_) {}
      throw JobsApplyException(message);
    }
  }
}

class JobsApplyException implements Exception {
  JobsApplyException(this.message);
  final String message;
}
