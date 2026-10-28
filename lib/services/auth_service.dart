import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'api_exception.dart';

/// The authenticated user, as returned by the real
/// POST /api/users/login and POST /api/users endpoints.
class AuthUser {
  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'student',
      token: json['token']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String email;
  final String role;
  final String token;

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'email': email,
    'role': role,
    'token': token,
  };
}

/// Talks to the real SkillDad authentication API
/// (server/controllers/userController.js: registerUser / loginUser) and
/// persists the session locally so it survives an app restart.
class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// The instance the app uses everywhere. Tests may replace this with an
  /// `AuthService(client: MockClient(...))` before pumping a widget tree, so
  /// screens under test never make a real network call.
  static AuthService instance = AuthService();

  static const _prefsKey = 'skilldad_auth_user';

  final http.Client _client;
  AuthUser? _cachedUser;

  Future<AuthUser> login({required String email, required String password}) async {
    final response = await _post(
      '/api/users/login',
      body: {'email': email, 'password': password},
    );

    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(body['message']?.toString() ?? 'Sign in failed. Please try again.');
    }

    final user = AuthUser.fromJson(body);
    await _persist(user);
    return user;
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await _post(
      '/api/users',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': 'student',
      },
    );

    final body = _decodeBody(response);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException(
        body['message']?.toString() ?? 'Registration failed. Please try again.',
      );
    }

    final user = AuthUser.fromJson(body);
    await _persist(user);
    return user;
  }

  /// Real forgot-password request (server/controllers/userController.js:
  /// forgotPassword) - sends a password-reset email with a link to the
  /// website's reset page, the same flow the web app uses. Returns the
  /// server's own confirmation message.
  Future<String> requestPasswordReset(String email) async {
    final response = await _post(
      '/api/users/forgotpassword',
      body: {'email': email},
    );

    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        body['message']?.toString() ?? 'Could not send the recovery email. Please try again.',
      );
    }
    return body['message']?.toString() ?? 'Recovery link dispatched to your inbox';
  }

  Future<AuthUser?> restoreSession() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    try {
      _cachedUser = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  /// Permanently deletes the signed-in student's account
  /// (server/controllers/userController.js: deleteMyAccount). The password is
  /// re-checked server-side. On success the local session is cleared.
  Future<void> deleteAccount({required String token, required String password}) async {
    http.Response response;
    try {
      final request = http.Request('DELETE', Uri.parse('${ApiConfig.baseUrl}/api/users/me'))
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        })
        ..body = jsonEncode({'password': password});
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 20)),
      );
    } catch (_) {
      throw ApiException('Could not reach SkillDad. Check your connection and try again.');
    }
    if (response.statusCode != 200) {
      throw ApiException(
        _decodeBody(response)['message']?.toString() ?? 'Could not delete the account. Please try again.',
      );
    }
    await signOut();
  }

  Future<void> signOut() async {
    _cachedUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _persist(AuthUser user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(user.toJson()));
  }

  Future<http.Response> _post(String path, {required Map<String, dynamic> body}) async {
    try {
      return await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Could not reach SkillDad. Check your connection and try again.');
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) return {};
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }
}
