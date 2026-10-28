/// Base URL of the real SkillDad platform this app talks to. Every screen
/// that shows data (courses, leadership, auth) goes through here rather
/// than static/dummy content.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://skilldad.com';

  /// Resolves a relative media path (e.g. "/uploads/thumbnail-1.jpg" or
  /// "/assets/directors/ramiz.png") returned by the API into a fully
  /// qualified URL this app can load directly, matching the website's media.js.
  static String mediaUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    var clean = path.trim();
    if (clean == 'null' || clean == 'undefined') return '';

    // If it's already an absolute URL pointing to localhost / emulator, rewrite to relative
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      if (clean.contains('localhost') || clean.contains('127.0.0.1') || clean.contains('10.0.2.2')) {
        clean = clean.replaceFirst(RegExp(r'^https?:\/\/[^\/]+'), '');
      } else {
        return clean;
      }
    }

    // Standardize leading slash and upload directory prefix matching website's media.js
    if (clean.startsWith('assets/')) {
      clean = '/$clean';
    } else if (clean.startsWith('uploads/')) {
      clean = '/$clean';
    } else if (!clean.startsWith('/')) {
      clean = '/uploads/$clean';
    } else if (!clean.startsWith('/uploads/') && !clean.startsWith('/assets/')) {
      clean = '/uploads$clean';
    }

    return '$baseUrl$clean';
  }
}
