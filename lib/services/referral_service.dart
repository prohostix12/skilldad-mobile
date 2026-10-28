import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// The student's real referral code/link -
/// server/controllers/referralController.js's `getMyReferralCode`
/// (GET /api/referrals/my-code). The code is deterministic per account
/// (`SKD-<hash>`), generated/stored server-side on first request.
class ReferralCode {
  ReferralCode({required this.code, required this.link});

  factory ReferralCode.fromJson(Map<String, dynamic> json) {
    return ReferralCode(code: (json['code'] ?? '').toString(), link: (json['link'] ?? '').toString());
  }

  final String code;
  final String link;
}

/// One real reward-point ledger entry (server: `reward_points` table).
class RewardPointEntry {
  RewardPointEntry({required this.points, required this.reason, required this.referenceName});

  factory RewardPointEntry.fromJson(Map<String, dynamic> json) {
    return RewardPointEntry(
      points: (json['points'] is num) ? (json['points'] as num).toInt() : int.tryParse('${json['points']}') ?? 0,
      reason: (json['reason'] ?? '').toString(),
      referenceName: (json['reference_name'] ?? '').toString(),
    );
  }

  final int points;
  final String reason;
  final String referenceName;
}

/// The student's real reward-point balance + history -
/// server/controllers/referralController.js's `getMyRewardPoints`
/// (GET /api/referrals/my-points).
class RewardPoints {
  RewardPoints({required this.total, required this.history});

  factory RewardPoints.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    return RewardPoints(
      total: (json['total'] is num) ? (json['total'] as num).toInt() : int.tryParse('${json['total']}') ?? 0,
      history: (rawHistory is List ? rawHistory : const [])
          .whereType<Map<String, dynamic>>()
          .map(RewardPointEntry.fromJson)
          .toList(),
    );
  }

  static const empty = RewardPoints._empty();
  const RewardPoints._empty() : total = 0, history = const [];

  final int total;
  final List<RewardPointEntry> history;
}

/// The real referral/reward-points system -
/// server/controllers/referralController.js, mounted at /api/referrals.
class ReferralService {
  ReferralService({http.Client? client}) : _client = client ?? http.Client();

  static ReferralService instance = ReferralService();

  final http.Client _client;

  Future<ReferralCode?> fetchMyCode(String token) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/referrals/my-code'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return ReferralCode.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<RewardPoints> fetchMyPoints(String token) async {
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/referrals/my-points'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return RewardPoints.empty;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return RewardPoints.empty;
      return RewardPoints.fromJson(decoded);
    } catch (_) {
      return RewardPoints.empty;
    }
  }
}
