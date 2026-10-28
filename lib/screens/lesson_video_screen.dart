import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/course_player_service.dart';
import '../theme/app_colors.dart';
import '../widgets/discussion_hub.dart';
import '../widgets/skilldad_video_player.dart';

/// Plays a real lesson's video inside the app - styled exactly like the website's
/// video player with a 1.34x zoom-in effect to hide YouTube watermark and chrome,
/// rounded-2xl glass card styling, and custom brand controls.
class LessonVideoScreen extends StatefulWidget {
  const LessonVideoScreen({
    super.key,
    required this.courseId,
    required this.lesson,
    required this.isWatched,
    required this.isExerciseDone,
    required this.token,
    required this.onMarkComplete,
    required this.onExercise,
  });

  final String courseId;
  final CourseLesson lesson;
  final bool isWatched;
  final bool isExerciseDone;
  final String token;
  final Future<void> Function() onMarkComplete;
  final Future<void> Function() onExercise;

  @override
  State<LessonVideoScreen> createState() => _LessonVideoScreenState();
}

class _LessonVideoScreenState extends State<LessonVideoScreen> {
  final GlobalKey _playerKey = GlobalKey();
  bool _isWatched = false;
  bool _isExerciseDone = false;
  bool _marking = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _isWatched = widget.isWatched;
    _isExerciseDone = widget.isExerciseDone;
  }

  @override
  void dispose() {
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (!kIsWeb) {
      if (_isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> _markComplete() async {
    setState(() => _marking = true);
    await widget.onMarkComplete();
    if (!mounted) return;
    setState(() {
      _isWatched = true;
      _marking = false;
    });
  }

  Future<void> _takeExercise() async {
    if (!_isWatched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attend or watch this class before taking the assessment.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await widget.onExercise();
    if (!mounted) return;
    setState(() => _isExerciseDone = true);
  }

  Future<void> _openDocument(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document link not available.')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(clean);
    if (uri == null) return;

    // Web handling: open in new browser tab
    if (kIsWeb) {
      try {
        final ok = await launchUrl(uri, webOnlyWindowName: '_blank');
        if (ok) return;
      } catch (_) {}
    }

    // 1. Try launching with external application (PDF viewer / default handler)
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    // 2. Fallback to platform default browser
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (ok) return;
    } catch (_) {}

    // 3. Fallback to Google Docs Viewer web renderer (works everywhere without extra apps)
    try {
      final docsViewerUri = Uri.parse(
        'https://docs.google.com/viewer?url=${Uri.encodeComponent(clean)}',
      );
      final ok = await launchUrl(docsViewerUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open document. Please check your internet connection.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildDocumentStage(BuildContext context) {
    final docUrl = widget.lesson.fullDocumentUrl;
    final fileName = widget.lesson.fileName.isNotEmpty
        ? widget.lesson.fileName
        : (widget.lesson.title.isNotEmpty ? '${widget.lesson.title}.pdf' : 'Study_Material.pdf');

    return AspectRatio(
      aspectRatio: 16 / 9.8,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF0D1117),
              Color(0xFF064E3B),
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFF34D399),
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.lesson.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fileName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _openDocument(docUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openDocument(docUrl),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoStage = widget.lesson.isDocument
        ? _buildDocumentStage(context)
        : (widget.lesson.url.trim().isNotEmpty
            ? SkillDadVideoPlayer(
                key: _playerKey,
                url: widget.lesson.url,
                title: widget.lesson.title,
                thumbnailUrl: widget.lesson.thumbnailUrl,
                autoPlay: false,
                borderRadius: 0,
                aspectRatio: 16 / 9, // Standard 16:9 widescreen video viewport
                isFullScreen: _isFullScreen,
                onToggleFullscreen: _toggleFullscreen,
                onEnded: () {
                  if (!_isWatched) {
                    _markComplete();
                  }
                },
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: const Color(0xFF131024),
                  alignment: Alignment.center,
                  child: const Text(
                    "Video not available for this lesson.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ));

    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullScreen) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B18), // Deep theater background matching website
        body: SafeArea(
          top: !_isFullScreen,
          bottom: !_isFullScreen,
          left: !_isFullScreen,
          right: !_isFullScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with back button and lesson title (hidden in fullscreen)
              if (!_isFullScreen)
                Container(
                  color: Colors.black,
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        splashRadius: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.lesson.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // Persistent Video or Document Stage Container
              // Using Expanded in both fullscreen and portrait mode ensures the widget element
              // remains at the exact same tree hierarchy depth so the underlying controller/WebView
              // is never unmounted, destroyed, or restarted.
              Expanded(
                flex: _isFullScreen ? 1 : 0,
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: videoStage,
                ),
              ),

              if (!_isFullScreen)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.lesson.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (_isWatched)
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                        ],
                      ),
                      if (widget.lesson.isDocument) ...[
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.picture_as_pdf_rounded, size: 13, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Study Material • PDF Document',
                              style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ] else if (widget.lesson.duration.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(widget.lesson.duration, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                      if (widget.lesson.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.lesson.description,
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (widget.lesson.hasExercises) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isExerciseDone ? null : _takeExercise,
                                icon: Icon(
                                  _isExerciseDone
                                      ? Icons.fact_check_rounded
                                      : (!_isWatched ? Icons.lock_outline_rounded : Icons.quiz_outlined),
                                  size: 18,
                                ),
                                label: Text(
                                  _isExerciseDone
                                      ? 'Exercise Passed'
                                      : (!_isWatched
                                          ? 'Assessment (Locked)'
                                          : (widget.lesson.exercises.length > 1
                                              ? 'Take Quiz (${widget.lesson.exercises.length})'
                                              : 'Take Exercise')),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _isExerciseDone
                                      ? Colors.green
                                      : (!_isWatched ? AppColors.textMuted : AppColors.primary),
                                  side: BorderSide(
                                    color: _isExerciseDone
                                        ? Colors.green
                                        : (!_isWatched ? AppColors.fieldBorder : AppColors.primary),
                                  ),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isWatched || _marking ? null : _markComplete,
                              icon: _marking
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: Text(_isWatched
                                  ? (widget.lesson.isDocument ? 'Completed' : 'Watched')
                                  : (widget.lesson.isDocument ? 'Mark Completed' : 'Mark Watched')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DiscussionHub(courseId: widget.courseId, videoId: widget.lesson.id, token: widget.token),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
