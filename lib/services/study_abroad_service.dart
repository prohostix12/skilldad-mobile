import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// A country offering Study Abroad placements
/// (GET /api/study-abroad/countries).
class StudyAbroadCountry {
  StudyAbroadCountry({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
  });

  factory StudyAbroadCountry.fromJson(Map<String, dynamic> json) {
    return StudyAbroadCountry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim(),
    );
  }

  final String id;
  final String name;
  final String imageUrl;
  final String description;

  /// High-reliability curated CDN image if the remote database URL is missing, broken, or CORS blocked
  String get fallbackImageUrl {
    final lower = name.toLowerCase();
    if (lower.contains('albania')) {
      return 'https://images.unsplash.com/photo-1596484552834-6a58f850e0a1?auto=format&fit=crop&w=1200&q=80';
    }
    if (lower.contains('bosnia')) {
      return 'https://images.unsplash.com/photo-1565008576549-57569a49371d?auto=format&fit=crop&w=1200&q=80';
    }
    if (lower.contains('greece')) {
      return 'https://a.cdn-hotels.com/gdcs/production28/d274/8d872105-9e0e-4e93-b1a3-1419c112bd85.jpg';
    }
    if (lower.contains('malta')) {
      return 'https://wallpapers.com/images/hd/malta-1600-x-900-picture-x4xjsigcn7ofi2zd.jpg';
    }
    if (lower.contains('mauritius')) {
      return 'https://images.unsplash.com/photo-1589553416260-f586c8f1514f?auto=format&fit=crop&w=1200&q=80';
    }
    if (lower.contains('montenegro')) {
      return 'https://images.unsplash.com/photo-1561571994-3c61c554181a?auto=format&fit=crop&w=1200&q=80';
    }
    return 'https://images.unsplash.com/photo-1526772662000-3f88f10405ff?q=80&w=1200&auto=format&fit=crop';
  }

  String get effectiveImageUrl {
    if (imageUrl.isNotEmpty &&
        !imageUrl.contains('worldatlas.com') &&
        !imageUrl.contains('travelholicq.com') &&
        !imageUrl.contains('img.welt.de')) {
      return imageUrl;
    }
    return fallbackImageUrl;
  }
}

/// A partner university within a Study Abroad country
/// (GET /api/study-abroad/countries/:id/universities).
class StudyAbroadUniversity {
  StudyAbroadUniversity({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.location,
    required this.description,
    required this.websiteUrl,
  });

  factory StudyAbroadUniversity.fromJson(Map<String, dynamic> json) {
    return StudyAbroadUniversity(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      logoUrl: (json['logo_url'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim(),
      websiteUrl: (json['website_url'] ?? '').toString(),
    );
  }

  final String id;
  final String name;
  final String logoUrl;
  final String location;
  final String description;
  final String websiteUrl;
}

/// A course offered at a Study Abroad university
/// (GET /api/study-abroad/universities/:id/courses).
class StudyAbroadCourse {
  StudyAbroadCourse({
    required this.id,
    required this.name,
    required this.level,
    required this.duration,
    required this.fees,
    required this.requirements,
    required this.description,
    required this.intakes,
  });

  factory StudyAbroadCourse.fromJson(Map<String, dynamic> json) {
    return StudyAbroadCourse(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      level: (json['level'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
      fees: (json['fees'] ?? '').toString(),
      requirements: (json['requirements'] ?? '').toString(),
      description: (json['description'] ?? '').toString().trim(),
      intakes: (json['intakes'] ?? '').toString(),
    );
  }

  final String id;
  final String name;
  final String level;
  final String duration;
  final String fees;
  final String requirements;
  final String description;
  final String intakes;
}

/// Fetches the real Study Abroad drill-down (country -> university ->
/// course), the same data client/src/pages/StudyAbroad.jsx uses - not the
/// regular course catalog, which has nothing under this program type.
class StudyAbroadService {
  StudyAbroadService({http.Client? client}) : _client = client ?? http.Client();

  static StudyAbroadService instance = StudyAbroadService();

  final http.Client _client;

  Future<List<StudyAbroadCountry>> fetchCountries() async {
    final json = await _getList('/api/study-abroad/countries');
    return json.whereType<Map<String, dynamic>>().map(StudyAbroadCountry.fromJson).toList();
  }

  Future<List<StudyAbroadUniversity>> fetchUniversities(String countryId) async {
    final json = await _getList('/api/study-abroad/countries/$countryId/universities');
    return json.whereType<Map<String, dynamic>>().map(StudyAbroadUniversity.fromJson).toList();
  }

  Future<List<StudyAbroadCourse>> fetchCourses(String universityId) async {
    final json = await _getList('/api/study-abroad/universities/$universityId/courses');
    return json.whereType<Map<String, dynamic>>().map(StudyAbroadCourse.fromJson).toList();
  }

  Future<List<dynamic>> _getList(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}$path'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }
}
