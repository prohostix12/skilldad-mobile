import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One real notification log row - server: `notification_logs` table via
/// GET /api/notifications/my (server/routes/notificationRoutes.js).
/// `title`/`message` are derived client-side from `type`/`metadata`, the
/// same way the website's SocketContext.jsx's `getTitleFromType`/
/// `getMessageFromLog` do, so the title/message strings match exactly.
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.rawMessage,
    required this.metadata,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    Map<String, dynamic> metadata = const {};
    if (rawMetadata is Map<String, dynamic>) {
      metadata = rawMetadata;
    } else if (rawMetadata is String && rawMetadata.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic>) metadata = decoded;
      } catch (_) {}
    }

    return AppNotification(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      rawMessage: (json['message'] ?? '').toString(),
      metadata: metadata,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }

  final String id;
  final String type;
  final String rawMessage;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isRead;

  static const _titles = {
    'liveSession': '🔴 Live Session Scheduled',
    'enrollment': '✅ Enrollment Confirmed',
    'exam': '📝 Exam Scheduled',
    'exam_scheduled': '📝 Exam Scheduled',
    'examResult': '🏆 Exam Result',
    'examReminder': '⏰ Exam Reminder',
    'examCancelled': '❌ Exam Cancelled',
    'welcome': '👋 Welcome to SkillDad',
  };

  String get title => _titles[type] ?? '🔔 Notification';

  String get message {
    switch (type) {
      case 'liveSession':
        final topic = metadata['topic'] ?? '';
        final startTime = DateTime.tryParse((metadata['startTime'] ?? '').toString());
        final when = startTime == null ? '' : _formatDateTime(startTime);
        return '"$topic" scheduled for $when';
      case 'enrollment':
        return 'You have been enrolled in ${metadata['courseTitle'] ?? ''}';
      case 'exam':
      case 'exam_scheduled':
        return 'Exam "${metadata['examTitle'] ?? ''}" scheduled';
      case 'examResult':
        final percentage = metadata['percentage'];
        final percentText = percentage is num ? '${percentage.toStringAsFixed(1)}%' : '';
        return 'Result for "${metadata['examTitle'] ?? ''}": ${metadata['score'] ?? ''} ($percentText)';
      default:
        return rawMessage.isEmpty ? 'You have a new notification' : rawMessage;
    }
  }
}

String _formatDateTime(DateTime dateTime) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final hour12 = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${months[dateTime.month - 1]} ${dateTime.day}, $hour12:$minute $period';
}

/// The real notifications feature - server/routes/notificationRoutes.js,
/// mounted at /api/notifications.
class NotificationService {
  NotificationService({http.Client? client}) : _client = client ?? http.Client();

  static NotificationService instance = NotificationService();

  final http.Client _client;

  Future<List<AppNotification>> fetchMyNotifications(String token) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/notifications/my'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      return (decoded is List ? decoded : const [])
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> markAllRead(String token) async {
    try {
      final response = await _client
          .put(Uri.parse('${ApiConfig.baseUrl}/api/notifications/read'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
