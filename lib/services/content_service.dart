import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/home_content.dart';
import 'api_config.dart';

/// A course fetched live from GET /api/courses, filtered to the ones
/// currently marked featured on the real platform.
class RemoteCourse {
  RemoteCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.programType,
    this.category = '',
    this.duration = '',
    this.universityName = '',
    this.instructorName = '',
    this.isFeatured = false,
    this.level = '',
    this.price = '',
  });

  factory RemoteCourse.fromJson(Map<String, dynamic> json) {
    final thumbnail = (json['thumbnail'] ?? '').toString();
    final univ = (json['universityName'] ?? json['university_name'] ?? (json['instructor'] is Map ? (json['instructor'] as Map)['name'] : '') ?? '').toString().trim();
    final instr = (json['instructorName'] ?? json['instructor_name'] ?? '').toString().trim();
    final feat = json['isFeatured'] == true || json['is_featured'] == true || json['isFeatured'] == 1 || json['is_featured'] == 1;

    return RemoteCourse(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString().trim(),
      description: cleanDescription((json['description'] ?? '').toString()),
      thumbnailUrl: ApiConfig.mediaUrl(thumbnail),
      programType: (json['programType'] ?? json['program_type'] ?? '').toString(),
      category: (json['category'] ?? '').toString().trim(),
      duration: (json['duration'] ?? '').toString().trim(),
      universityName: univ,
      instructorName: instr,
      isFeatured: feat,
      level: (json['level'] ?? '').toString().trim(),
      price: (json['price'] ?? '').toString().trim(),
    );
  }

  static String cleanDescription(String text) {
    if (text.isEmpty) return '';
    return text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .join('\n\n');
  }

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String programType;
  final String category;
  final String duration;
  final String universityName;
  final String instructorName;
  final bool isFeatured;
  final String level;
  final String price;

  bool get isWbl => programType == 'wbl_domestic' || programType == 'wbl_abroad';
  bool get isWblDomestic => programType == 'wbl_domestic';
  bool get isWblAbroad => programType == 'wbl_abroad';
  bool get isSkillCourse => programType == 'course' || programType.isEmpty;
  bool get isDiploma => programType == 'degree_programme';
  bool get isStudyAbroad => programType == 'study_abroad';

  String get programTypeBadge {
    if (isDiploma) return 'Degree Programme';
    if (isWblAbroad) return 'WBL • Abroad';
    if (isWblDomestic) return 'WBL • Domestic';
    if (isWbl) return 'Work-Based Learning';
    if (isStudyAbroad) return 'Study Abroad';
    return displayCategory;
  }

  String get displayCategory {
    if (category.isNotEmpty) return category;
    final lower = title.toLowerCase();
    if (lower.contains('hospital') || lower.contains('health')) return 'Healthcare';
    if (lower.contains('marketing') || lower.contains('market')) return 'Marketing';
    if (lower.contains('data') || lower.contains('analytics') || lower.contains('ai')) return 'Data & Analytics';
    if (lower.contains('bba') || lower.contains('mba') || lower.contains('business') || lower.contains('management')) return 'Management';
    if (isWbl) return 'Work-Based Learning';
    return 'Professional';
  }

  String get displayDuration {
    if (duration.isNotEmpty) return duration;
    final upper = title.toUpperCase();
    if (upper.contains('BBA')) return '3 Years';
    if (upper.contains('MBA')) return '2 Years';
    return '6 Months';
  }

  String get displayCredential {
    final upper = title.toUpperCase();
    if (upper.contains('BBA') || upper.contains('MBA') || isDiploma) {
      return 'Degree';
    }
    return 'Certificate';
  }

  /// Chosen from the title so a sensible icon still shows if the real
  /// thumbnail fails to load - mirrors what category the title implies.
  IconData get fallbackIcon {
    final lower = title.toLowerCase();
    if (lower.contains('hospital') || lower.contains('health')) {
      return Icons.local_hospital_rounded;
    }
    if (lower.contains('market')) return Icons.campaign_rounded;
    if (lower.contains('data')) return Icons.bar_chart_rounded;
    return Icons.menu_book_rounded;
  }
}

/// A lightweight lesson entry in a public module.
class CourseLessonSummary {
  CourseLessonSummary({
    required this.id,
    required this.title,
    required this.duration,
    this.thumbnailUrl = '',
    this.url = '',
  });

  factory CourseLessonSummary.fromJson(Map<String, dynamic> json) {
    final rawThumb = (json['thumbnail'] ?? json['thumbnailUrl'] ?? json['coverImage'] ?? '').toString();
    final urlStr = (json['url'] ?? '').toString();
    return CourseLessonSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Lesson').toString(),
      duration: (json['duration'] ?? '').toString(),
      thumbnailUrl: _extractVideoThumbnail(urlStr, rawThumb),
      url: urlStr,
    );
  }

  final String id;
  final String title;
  final String duration;
  final String thumbnailUrl;
  final String url;

  bool get isDocument =>
      url.toLowerCase().endsWith('.pdf') ||
      url.toLowerCase().contains('/document-') ||
      RegExp(r'study\s*material|document|reading|notes?|assignment', caseSensitive: false).hasMatch(title);
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

/// A module's title and lesson list, as shown on the public course detail
/// page (video streams/exercises themselves are restricted to enrolled students).
class CourseModuleSummary {
  CourseModuleSummary({
    required this.title,
    required this.lessonCount,
    this.coverUrl = '',
    this.lessons = const [],
  });

  factory CourseModuleSummary.fromJson(Map<String, dynamic> json) {
    final videos = json['videos'];
    final parsedLessons = (videos is List ? videos : const [])
        .whereType<Map<String, dynamic>>()
        .map(CourseLessonSummary.fromJson)
        .toList();
    final coverRaw = (json['coverImage'] ?? json['cover_image'] ?? json['thumbnail'] ?? json['image'] ?? '').toString();
    return CourseModuleSummary(
      title: (json['title'] ?? 'Module').toString(),
      lessonCount: parsedLessons.isNotEmpty ? parsedLessons.length : (videos is List ? videos.length : 0),
      coverUrl: coverRaw.isNotEmpty ? ApiConfig.mediaUrl(coverRaw) : '',
      lessons: parsedLessons,
    );
  }

  final String title;
  final int lessonCount;
  final String coverUrl;
  final List<CourseLessonSummary> lessons;

  String effectiveCoverUrl({String courseThumbnail = ''}) {
    if (coverUrl.isNotEmpty) return coverUrl;
    for (final l in lessons) {
      if (l.thumbnailUrl.isNotEmpty) return l.thumbnailUrl;
    }
    return courseThumbnail;
  }
}

/// The full public course detail page content
/// (GET /api/courses/:id without a student token - instructor, university,
/// price, description and the module/lesson outline, but no video URLs or
/// exercises, matching what the real website shows a signed-out visitor).
class PublicCourseDetail {
  PublicCourseDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.category,
    required this.price,
    required this.instructorName,
    required this.universityName,
    required this.modules,
    this.durationWeeks = '',
  });

  factory PublicCourseDetail.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'];
    return PublicCourseDetail(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString().trim(),
      description: RemoteCourse.cleanDescription((json['description'] ?? '').toString()),
      thumbnailUrl: ApiConfig.mediaUrl((json['thumbnail'] ?? '').toString()),
      category: (json['category'] ?? '').toString(),
      price: (json['price'] ?? '').toString(),
      instructorName: (json['instructor_name'] ?? json['instructorName'] ?? (json['instructor'] is Map ? json['instructor']['name'] : '') ?? '').toString(),
      universityName: (json['university_name'] ?? json['universityName'] ?? '').toString(),
      durationWeeks: (json['duration_weeks'] ?? json['durationWeeks'] ?? '').toString(),
      modules: (rawModules is List ? rawModules : const [])
          .whereType<Map<String, dynamic>>()
          .map(CourseModuleSummary.fromJson)
          .toList(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String category;
  final String price;
  final String instructorName;
  final String universityName;
  final String durationWeeks;
  final List<CourseModuleSummary> modules;

  int get totalLessons => modules.fold(0, (sum, m) => sum + m.lessonCount);

  bool get isFree => price.isEmpty || price == '0';
}

/// Result of a live featured-courses fetch, already split the same way the
/// web landing page splits them (client/src/pages/LandingPage.jsx).
class FeaturedCourses {
  const FeaturedCourses({required this.wbl, required this.skill});

  final List<RemoteCourse> wbl;
  final List<RemoteCourse> skill;

  bool get isEmpty => wbl.isEmpty && skill.isEmpty;
}

/// A leadership entry fetched live from GET /api/public/directors.
class RemoteDirector {
  RemoteDirector({required this.name, required this.title, required this.imageUrl});

  factory RemoteDirector.fromJson(Map<String, dynamic> json) {
    return RemoteDirector(
      name: (json['name'] ?? '').toString(),
      title: (json['role'] ?? '').toString(),
      imageUrl: ApiConfig.mediaUrl((json['imageUrl'] ?? '').toString()),
    );
  }

  final String name;
  final String title;
  final String imageUrl;
}

/// Fetches the platform's real, currently-live content. Every method falls
/// back to the same static data used elsewhere in this app (or an empty
/// result) if the network call fails, so a lost connection degrades
/// gracefully instead of crashing the screen.
class ContentService {
  ContentService({http.Client? client}) : _client = client ?? http.Client();

  /// The instance the app uses everywhere. Tests may replace this with a
  /// `ContentService(client: MockClient(...))` before pumping a widget tree,
  /// so screens under test never make a real network call.
  static ContentService instance = ContentService();

  final http.Client _client;

  Future<FeaturedCourses> fetchFeaturedCourses() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/courses'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const FeaturedCourses(wbl: [], skill: []);

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const FeaturedCourses(wbl: [], skill: []);

      final courses = decoded
          .whereType<Map<String, dynamic>>()
          .where((json) => json['isFeatured'] == true || json['is_featured'] == true)
          .map(RemoteCourse.fromJson)
          .toList();

      return FeaturedCourses(
        wbl: courses.where((c) => c.isWbl).toList(),
        skill: courses.where((c) => c.isSkillCourse).toList(),
      );
    } catch (_) {
      return const FeaturedCourses(wbl: [], skill: []);
    }
  }

  /// The complete public course catalog - unlike [fetchFeaturedCourses],
  /// not filtered to the ones currently marked featured on the landing page.
  Future<List<RemoteCourse>> fetchAllCourses() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/courses'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      return decoded.whereType<Map<String, dynamic>>().map(RemoteCourse.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  /// The public course detail page (GET /api/courses/:id). Passing the
  /// signed-in student's [token] lets an enrolled student see the same
  /// request an unenrolled visitor would, which is enough for the public
  /// detail page - full lesson content is fetched separately, only once
  /// enrollment is confirmed (see CoursePlayerService).
  Future<PublicCourseDetail?> fetchCourseDetail(String courseId) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/courses/$courseId'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return PublicCourseDetail.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Landing-page leadership. Falls back to [kDirectors] (the same real
  /// names/photos the production site falls back to) if the request fails
  /// or the platform hasn't configured any LANDING-targeted directors yet.
  Future<List<RemoteDirector>> fetchLandingDirectors() async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/public/directors'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return _fallbackDirectors();

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return _fallbackDirectors();

      final landing = decoded
          .whereType<Map<String, dynamic>>()
          .where((json) => json['display_target'] == 'LANDING')
          .map(RemoteDirector.fromJson)
          .toList();

      return landing.isNotEmpty ? landing : _fallbackDirectors();
    } catch (_) {
      return _fallbackDirectors();
    }
  }

  List<RemoteDirector> _fallbackDirectors() {
    return kDirectors
        .map(
          (d) => RemoteDirector(
            name: d.name,
            title: d.title,
            imageUrl: d.imageAsset, // Local asset path; DirectorAvatar handles both.
          ),
        )
        .toList();
  }

  /// Fetches partner and SkillDad-affiliated universities from both
  /// GET /api/public/universities and GET /api/public/skilldad-universities,
  /// merging and deduplicating them into a complete directory.
  Future<List<RemoteUniversity>> fetchUniversities() async {
    try {
      final responses = await Future.wait([
        _client
            .get(Uri.parse('${ApiConfig.baseUrl}/api/public/universities'))
            .timeout(const Duration(seconds: 15)),
        _client
            .get(Uri.parse('${ApiConfig.baseUrl}/api/public/skilldad-universities'))
            .timeout(const Duration(seconds: 15)),
      ]);

      final List<RemoteUniversity> universities = [];
      final Set<String> seenNames = {};

      void addEntries(dynamic decoded) {
        if (decoded is! List) return;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final uni = RemoteUniversity.fromJson(item);
            final key = uni.name.toLowerCase().trim();
            if (key.isNotEmpty && !seenNames.contains(key)) {
              seenNames.add(key);
              universities.add(uni);
            }
          }
        }
      }

      if (responses[0].statusCode == 200) {
        try {
          addEntries(jsonDecode(responses[0].body));
        } catch (_) {}
      }

      if (responses[1].statusCode == 200) {
        try {
          addEntries(jsonDecode(responses[1].body));
        } catch (_) {}
      }

      if (universities.isNotEmpty) {
        return universities;
      }
      return _fallbackUniversities();
    } catch (_) {
      return _fallbackUniversities();
    }
  }

  List<RemoteUniversity> _fallbackUniversities() {
    return const [
      RemoteUniversity(
        id: 'fallback-cit',
        name: 'Canadian Institute of Technology',
        location: 'Tirana, Albania',
        logoUrl: 'https://skilldad.com/uploads/logo-1790586007998.png',
        coverUrl: 'https://skilldad.com/uploads/coverImage-1785406798263.jpg',
        description:
            'CIT offers internationally aligned degrees with a strong focus on technology, digital marketing, AI, and engineering in English.',
        website: 'https://cit.edu.al',
        phone: '+355 4 222 9778',
        email: 'info@cit.edu.al',
        studentCount: '1,200+',
        courseCount: '6+',
        programTypes: ['course', 'degree'],
        courseCategories: ['AI', 'Data Analytics', 'IT & Business', 'Logistics'],
        courseTitles: [
          'Digital Marketing with AI',
          'Applied Data Science & Machine Learning',
          'Business Intelligence',
        ],
        achievements: [
          RemoteAchievement(
            title: 'Institutional Accreditation by ASCAL',
            desc:
                'Re-accredited by Albania Quality Assurance Agency in Higher Education (ASCAL) for 5 years.',
            image: '',
          ),
          RemoteAchievement(
            title: '194 Cisco Academy Certificates',
            desc:
                'Engineering students earned 194 industry-recognized Cisco certifications.',
            image: '',
          ),
        ],
        established: '2011',
        rating: '4.9',
      ),
      RemoteUniversity(
        id: 'fallback-mu',
        name: 'Mediterranean University',
        location: 'Tirana, Albania',
        logoUrl: 'https://skilldad.com/uploads/logo-1788942072427.png',
        coverUrl: 'https://skilldad.com/uploads/coverImage-1777288274408.jpg',
        description:
            'A leading higher education institution in Albania providing top quality education in hospitality, data science, and business management.',
        website: 'https://www.umsh.edu.al',
        phone: '+355 68 606 1004',
        email: 'info@umsh.edu.al',
        studentCount: '3,500+',
        courseCount: '8+',
        programTypes: ['course'],
        courseCategories: ['AI', 'Digital Marketing', 'Hospital Administration'],
        courseTitles: [
          'Health Administrator & Management',
          'Professional Training Data Science & AI',
        ],
        achievements: [
          RemoteAchievement(
            title: 'Institutionally Accredited',
            desc: 'Recognized for highest academic and institutional standards.',
            image: '',
          ),
          RemoteAchievement(
            title: 'UNIADRION Full Member',
            desc:
                'Active member in the Adriatic-Ionian university academic network.',
            image: '',
          ),
        ],
        established: '2007',
        rating: '4.8',
      ),
      RemoteUniversity(
        id: 'fallback-srinivas',
        name: 'Srinivas University',
        location: 'Mangaluru, Karnataka, India',
        logoUrl: 'https://skilldad.com/uploads/profileImage-1789980364979.webp',
        coverUrl: '',
        description:
            'Premier private research and skill-focused university in Karnataka established under Karnataka State Act.',
        website: 'https://srinivasuniversity.edu.in',
        phone: '+91 70264 36197',
        email: 'info@srinivasuniversity.edu.in',
        studentCount: '12,000+',
        courseCount: '25+',
        programTypes: ['undergraduate', 'postgraduate', 'course'],
        courseCategories: ['Engineering', 'Computer Science', 'Management', 'Health'],
        courseTitles: ['B.Tech Computer Science', 'MBA Business Analytics'],
        achievements: [
          RemoteAchievement(
            title: 'NAAC A Grade',
            desc: 'Achieved prestigious A Grade accreditation from NAAC.',
            image: '',
          ),
        ],
        established: '2013',
        rating: '4.9',
      ),
      RemoteUniversity(
        id: 'fallback-malta',
        name: 'Malta University Language School',
        location: 'Tal-Qroqq, Msida, Malta',
        logoUrl: 'https://skilldad.com/uploads/profileImage-1787678648930.jpg',
        coverUrl: '',
        description:
            'Delivering world-class accredited English and professional programmes officially validated by the University of Malta (est. 1592).',
        website: 'https://www.universitylanguageschool.com',
        phone: '+356 2132 3603',
        email: 'info@universitylanguageschool.com',
        studentCount: '2,000+',
        courseCount: '10+',
        programTypes: ['wbl_abroad', 'course'],
        courseCategories: ['Language', 'Professional Training', 'Hospitality'],
        courseTitles: ['IELTS & Global Exam Prep', 'Erasmus+ Teacher Training'],
        achievements: [
          RemoteAchievement(
            title: 'Validated by University of Malta',
            desc: 'All programs officially validated by University of Malta.',
            image: '',
          ),
          RemoteAchievement(
            title: 'Erasmus+ Funding Partner',
            desc: 'Eligible for EU flagship international education grants.',
            image: '',
          ),
        ],
        established: '1972',
        rating: '4.9',
      ),
    ];
  }
}

/// An individual accreditation, award or milestone earned by a partner university.
class RemoteAchievement {
  const RemoteAchievement({
    required this.title,
    required this.desc,
    required this.image,
  });

  factory RemoteAchievement.fromJson(Map<String, dynamic> json) {
    final rawImg = (json['image'] ?? json['imageUrl'] ?? '').toString();
    return RemoteAchievement(
      title: (json['title'] ?? json['name'] ?? '').toString().trim(),
      desc: (json['desc'] ?? json['description'] ?? '').toString().trim(),
      image: ApiConfig.mediaUrl(rawImg),
    );
  }

  final String title;
  final String desc;
  final String image;
}

/// A partner or SkillDad-affiliated university fetched from the platform.
class RemoteUniversity {
  const RemoteUniversity({
    required this.id,
    required this.name,
    required this.location,
    required this.logoUrl,
    required this.coverUrl,
    required this.description,
    required this.website,
    required this.phone,
    required this.email,
    required this.studentCount,
    required this.courseCount,
    required this.programTypes,
    required this.courseCategories,
    required this.courseTitles,
    required this.achievements,
    required this.established,
    required this.rating,
  });

  factory RemoteUniversity.fromJson(Map<String, dynamic> json) {
    // Handle nested profile object if present
    Map<String, dynamic> profile = {};
    if (json['profile'] is Map<String, dynamic>) {
      profile = json['profile'] as Map<String, dynamic>;
    } else if (json['profile'] is String) {
      try {
        final parsed = jsonDecode(json['profile'] as String);
        if (parsed is Map<String, dynamic>) {
          profile = parsed;
        }
      } catch (_) {}
    }

    final uniName = (json['name'] ?? profile['universityName'] ?? '').toString().trim();
    final nameLower = uniName.toLowerCase();

    // Resolve non-empty logo candidate
    String rawLogo = '';
    for (final candidate in [
      json['logo'],
      json['profile_image'],
      json['profileImage'],
      profile['profileImage'],
      profile['logo'],
      profile['image'],
    ]) {
      if (candidate != null) {
        final val = candidate.toString().trim();
        if (val.isNotEmpty) {
          rawLogo = val;
          break;
        }
      }
    }

    // Official brand logo mappings for Canadian & Mediterranean partner universities
    if (nameLower.contains('canadian') || nameLower.contains('cit')) {
      if (rawLogo.isEmpty) {
        rawLogo = '/uploads/logo-1790586007998.png';
      }
    } else if (nameLower.contains('mediterranean') || nameLower.contains('umsh')) {
      if (rawLogo.isEmpty || rawLogo.contains('profileImage-1777288122537')) {
        rawLogo = '/uploads/logo-1788942072427.png';
      }
    }

    String rawCover = '';
    for (final candidate in [
      json['cover_image'],
      json['coverImage'],
      profile['coverImage'],
      profile['cover_image'],
    ]) {
      if (candidate != null) {
        final val = candidate.toString().trim();
        if (val.isNotEmpty) {
          rawCover = val;
          break;
        }
      }
    }

    final loc = (profile['location'] ?? json['location'] ?? '').toString().trim();
    final site = (profile['website'] ?? json['website'] ?? '').toString().trim();
    final ph = (profile['phone'] ?? json['phone'] ?? '').toString().trim();
    final em = (json['email'] ?? profile['email'] ?? '').toString().trim();
    final bio = (json['bio'] ?? json['description'] ?? profile['bio'] ?? '').toString().trim();

    // Parse achievements
    final List<RemoteAchievement> achievements = [];
    final rawAchievements = profile['achievements'] ?? json['achievements'];
    if (rawAchievements is List) {
      for (final a in rawAchievements) {
        if (a is Map<String, dynamic>) {
          final ach = RemoteAchievement.fromJson(a);
          if (ach.title.isNotEmpty || ach.desc.isNotEmpty) {
            achievements.add(ach);
          }
        }
      }
    }

    final pTypes = (json['programTypes'] is List)
        ? (json['programTypes'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final cCats = (json['courseCategories'] is List)
        ? (json['courseCategories'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final cTitles = (json['courseTitles'] is List)
        ? (json['courseTitles'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final rawStudents = (json['studentCount'] ??
            json['scholarCount'] ??
            json['total_scholars'] ??
            '')
        .toString();
    final rawCourses = (json['courseCount'] ??
            json['specialized_courses'] ??
            (cTitles.isNotEmpty ? '${cTitles.length}' : ''))
        .toString();

    final foundedYear = (profile['foundedYear'] ?? profile['established'] ?? '').toString().trim();

    return RemoteUniversity(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      location: loc.isEmpty ? 'Global' : loc,
      logoUrl: ApiConfig.mediaUrl(rawLogo),
      coverUrl: ApiConfig.mediaUrl(rawCover),
      description: bio.isEmpty
          ? 'Distinguished academic institution partnered with SkillDad to deliver accredited career and industry courses.'
          : bio,
      website: site,
      phone: ph,
      email: em,
      studentCount: (rawStudents.isEmpty || rawStudents == '0') ? 'Active' : rawStudents,
      courseCount: (rawCourses.isEmpty || rawCourses == '0')
          ? (cTitles.isNotEmpty ? '${cTitles.length}' : 'Programs')
          : rawCourses,
      programTypes: pTypes,
      courseCategories: cCats,
      courseTitles: cTitles,
      achievements: achievements,
      established: foundedYear.isNotEmpty ? foundedYear : 'Recognized',
      rating: '4.9',
    );
  }

  final String id;
  final String name;
  final String location;
  final String logoUrl;
  final String coverUrl;
  final String description;
  final String website;
  final String phone;
  final String email;
  final String studentCount;
  final String courseCount;
  final List<String> programTypes;
  final List<String> courseCategories;
  final List<String> courseTitles;
  final List<RemoteAchievement> achievements;
  final String established;
  final String rating;

  /// Returns 1-2 initials for avatar badge if logo fails to load.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'U';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words[1].substring(0, 1)}'.toUpperCase();
  }

  /// Campus cover image URL matching the desktop card banner, with
  /// architectural photography fallback if no custom cover was uploaded.
  String get effectiveCoverUrl {
    if (coverUrl.isNotEmpty) return coverUrl;
    final index = name.hashCode.abs() % kCampusFallbacks.length;
    return kCampusFallbacks[index];
  }

  /// Official accreditation title or verified status.
  String get accreditationText {
    if (achievements.isNotEmpty) {
      return achievements.first.title;
    }
    return 'Verified Partner Institution';
  }

  /// Highlights top course categories or titles offered by the university.
  String get popularCoursesText {
    if (courseCategories.isNotEmpty) {
      return courseCategories.take(3).join(', ');
    }
    if (courseTitles.isNotEmpty) {
      return courseTitles.take(2).map((t) => t.trim()).join(', ');
    }
    return 'Degree & Skill Programs';
  }

  /// Available degree and program pathways.
  String get programLevelsText {
    if (programTypes.isNotEmpty) {
      return programTypes
          .map((p) {
            if (p == 'wbl_abroad') return 'WBL Abroad';
            if (p == 'wbl_domestic') return 'WBL Domestic';
            if (p == 'course') return 'Skill Courses';
            if (p == 'degree') return 'Degree';
            return p;
          })
          .take(3)
          .join(' · ');
    }
    return 'Undergraduate & Professional';
  }
}

/// Curated high-resolution architectural campus images for fallbacks,
/// mirroring the web platform's CAMPUS_FALLBACKS in client/src/pages/Platform.jsx.
const List<String> kCampusFallbacks = [
  'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1498243691581-b145c3f54a5a?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1592280771190-3e2e4d571952?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1576495199011-eb94736d05d6?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1590012314607-cda9d9b699ae?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1607237138185-eedd9c632b0b?auto=format&fit=crop&q=80&w=800',
  'https://images.unsplash.com/photo-1525921429624-479b6a26d84d?auto=format&fit=crop&q=80&w=800',
];
