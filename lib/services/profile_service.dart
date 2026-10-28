import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// The real signed-in student's profile - server/controllers/userController.js
/// `getMe` (GET /api/users/me). `profile` there is a free-form JSON blob;
/// only the real keys the web Settings page itself reads/writes are parsed.
class StudentProfile {
  StudentProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.bio,
    required this.phone,
    required this.location,
    required this.website,
    required this.profileImageUrl,
    this.role = 'student',
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['profile'];
    Map<String, dynamic> profile = const {};
    if (rawProfile is Map<String, dynamic>) {
      profile = rawProfile;
    } else if (rawProfile is String && rawProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProfile);
        if (decoded is Map<String, dynamic>) profile = decoded;
      } catch (_) {}
    }

    final rawImage = (
      profile['profileImage'] ??
      profile['profileImageUrl'] ??
      profile['avatar'] ??
      profile['image'] ??
      json['profileImage'] ??
      json['avatar'] ??
      json['image'] ??
      ''
    ).toString();

    return StudentProfile(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      bio: (json['bio'] ?? '').toString(),
      phone: (profile['phone'] ?? '').toString(),
      location: (profile['location'] ?? '').toString(),
      website: (profile['website'] ?? '').toString(),
      profileImageUrl: rawImage.isEmpty ? '' : ApiConfig.mediaUrl(rawImage),
      role: (json['role'] ?? profile['role'] ?? 'student').toString(),
    );
  }

  final String id;
  final String name;
  final String email;
  final String bio;
  final String phone;
  final String location;
  final String website;
  final String profileImageUrl;
  final String role;
}

/// The real career-progress signals behind the student's streak -
/// server/controllers/careerProgressController.js's `getCareerProgress`
/// (GET /api/users/me/career-progress). `currentStreak`/`longestStreak` are
/// real columns on the `users` table, not a client-side invention.
class CareerProgress {
  const CareerProgress({
    required this.currentStreak,
    required this.longestStreak,
    required this.careerGoal,
    required this.hasResumeUploaded,
    required this.interviewPrepCompleted,
  });

  factory CareerProgress.fromJson(Map<String, dynamic> json) {
    return CareerProgress(
      currentStreak: _toInt(json['currentStreak']) ?? 0,
      longestStreak: _toInt(json['longestStreak']) ?? 0,
      careerGoal: (json['careerGoal'] as String?)?.trim(),
      hasResumeUploaded: json['hasResumeUploaded'] == true,
      interviewPrepCompleted: json['interviewPrepCompleted'] == true,
    );
  }

  static const empty = CareerProgress(
    currentStreak: 0,
    longestStreak: 0,
    careerGoal: null,
    hasResumeUploaded: false,
    interviewPrepCompleted: false,
  );

  final int currentStreak;
  final int longestStreak;
  final String? careerGoal;
  final bool hasResumeUploaded;
  final bool interviewPrepCompleted;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// The signed-in student's real profile, identity and password -
/// server/controllers/userController.js, mounted at /api/users.
class ProfileService {
  ProfileService({http.Client? client}) : _client = client ?? http.Client();

  static ProfileService instance = ProfileService();

  final http.Client _client;

  Future<StudentProfile?> fetchMe(String token) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/users/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return StudentProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<CareerProgress> fetchCareerProgress(String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/users/me/career-progress'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return CareerProgress.empty;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return CareerProgress.empty;
      return CareerProgress.fromJson(decoded);
    } catch (_) {
      return CareerProgress.empty;
    }
  }

  /// Saves the real edited profile fields. Throws [ApiException] with the
  /// server's real message on failure (e.g. email already in use).
  Future<StudentProfile> updateProfile({
    required String token,
    required String name,
    required String bio,
    required String phone,
    required String location,
    required String website,
    String? profileImage,
  }) async {
    final Map<String, dynamic> profileMap = {
      'phone': phone,
      'location': location,
      'website': website,
    };
    if (profileImage != null && profileImage.trim().isNotEmpty) {
      final img = profileImage.trim();
      profileMap['profileImage'] = img;
      profileMap['avatar'] = img;
      profileMap['image'] = img;
    }

    final response = await _client
        .put(
          Uri.parse('${ApiConfig.baseUrl}/api/users/profile'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({
            'name': name,
            'bio': bio,
            'profileImage': profileImage?.trim(),
            'profile': profileMap,
          }),
        )
        .timeout(const Duration(seconds: 20));

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      throw ApiException(
        decoded is Map<String, dynamic> && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Could not save your profile. Please try again.',
      );
    }
    return StudentProfile.fromJson(decoded);
  }

  /// Changes the real account password. Throws [ApiException] with the
  /// server's real validation message (the same 4-rule policy Register.jsx
  /// enforces) on failure.
  Future<void> updatePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client
        .put(
          Uri.parse('${ApiConfig.baseUrl}/api/users/password'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 200) return;
    final decoded = jsonDecode(response.body);
    throw ApiException(
      decoded is Map<String, dynamic> && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Could not change your password. Please try again.',
    );
  }

  /// Uploads a raw image file from the student's device to POST /api/users/upload-profile-image.
  /// Returns the absolute media URL of the uploaded image.
  Future<String> uploadProfileImage({
    required String token,
    required List<int> bytes,
    required String filename,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/users/upload-profile-image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'profileImage',
        bytes,
        filename: filename.isNotEmpty ? filename : 'profile_image.jpg',
      ));

    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      throw ApiException(
        decoded is Map<String, dynamic> && decoded['message'] != null
            ? decoded['message'].toString()
            : 'Could not upload image from your device. Please try again.',
      );
    }

    final rawUrl = (decoded['imageUrl'] ?? decoded['image'] ?? '').toString();
    return ApiConfig.mediaUrl(rawUrl);
  }
}
