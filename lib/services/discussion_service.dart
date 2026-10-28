import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One real discussion message (or reply, when [parentId] is set) under a
/// lesson - server: `discussions` table via GET /api/discussions/:courseId/:videoId.
class Discussion {
  Discussion({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.content,
    required this.parentId,
    required this.createdAt,
    required this.likedBy,
  });

  factory Discussion.fromJson(Map<String, dynamic> json) {
    final rawLikedBy = json['liked_by'];
    return Discussion(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      userName: (json['user_name'] ?? 'Student').toString(),
      userProfileImage: (json['user_profile_image'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      parentId: json['parent_id']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      likedBy: (rawLikedBy is List ? rawLikedBy : const []).map((e) => e.toString()).toList(),
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String content;
  final String? parentId;
  final DateTime createdAt;
  final List<String> likedBy;

  bool get isReply => parentId != null;
}

/// The real per-lesson Discussion Hub - server/controllers/DiscussionController.js,
/// mounted at /api/discussions.
class DiscussionService {
  DiscussionService({http.Client? client}) : _client = client ?? http.Client();

  static DiscussionService instance = DiscussionService();

  final http.Client _client;

  Future<List<Discussion>> fetchDiscussions(String courseId, String videoId, String token) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/discussions/$courseId/$videoId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      return (decoded is List ? decoded : const []).whereType<Map<String, dynamic>>().map(Discussion.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Discussion?> postDiscussion({
    required String courseId,
    required String videoId,
    required String content,
    String? parentId,
    required String token,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/discussions'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({
              'courseId': courseId,
              'videoId': videoId,
              'content': content,
              'parentId': parentId,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return Discussion.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Toggles the signed-in student's like and returns the real updated
  /// `liked_by` list, or null on failure.
  Future<List<String>?> toggleLike(String discussionId, String token) async {
    try {
      final response = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/api/discussions/$discussionId/like'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final rawLikedBy = decoded['likedBy'];
      return (rawLikedBy is List ? rawLikedBy : const []).map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }
}
