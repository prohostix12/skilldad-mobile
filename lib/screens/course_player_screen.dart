import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/course_player_service.dart';
import '../theme/app_colors.dart';
import 'lesson_video_screen.dart';

/// Lets a student watch a course's real lessons and complete its real
/// exercises on mobile - backed by GET /api/courses/:id (full content only
/// when the signed-in student is enrolled) and
/// PUT /api/enrollment/progress for marking lessons/exercises done.
class CoursePlayerScreen extends StatefulWidget {
  const CoursePlayerScreen({super.key, required this.courseId, required this.courseTitle, required this.token});

  final String courseId;
  final String courseTitle;
  final String token;

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  CoursePlayerDetail? _detail;
  CourseProgressState _progress = CourseProgressState.empty;
  bool _loadFailed = false;
  bool _isBookmarked = false;
  int _selectedTab = 0; // 0: Course Outline, 1: About
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      CoursePlayerService.instance.fetchCourseDetail(widget.courseId, widget.token),
      CoursePlayerService.instance.fetchProgress(widget.courseId, widget.token),
    ]);
    if (!mounted) return;
    setState(() {
      _detail = results[0] as CoursePlayerDetail?;
      _progress = results[1] as CourseProgressState;
      _loadFailed = _detail == null;
    });
  }

  CourseLesson? get _nextUnwatchedLesson {
    final detail = _detail;
    if (detail == null) return null;
    for (final module in detail.modules) {
      for (final lesson in module.lessons) {
        if (!_progress.completedVideoIds.contains(lesson.id)) {
          return lesson;
        }
      }
    }
    for (final module in detail.modules) {
      for (final lesson in module.lessons) {
        if (lesson.hasVideo) return lesson;
      }
    }
    return null;
  }

  void _onBottomAction() {
    final next = _nextUnwatchedLesson;
    if (next != null) {
      _watchLesson(next);
    } else if (_detail?.modules.isNotEmpty == true && _detail!.modules.first.lessons.isNotEmpty) {
      _watchLesson(_detail!.modules.first.lessons.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video lessons available yet.')),
      );
    }
  }

  void _shareCourse() {
    Clipboard.setData(ClipboardData(text: 'https://skilldad.com/courses/${widget.courseId}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Course link copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _watchLesson(CourseLesson lesson) async {
    if (!lesson.hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This lesson has no content yet.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LessonVideoScreen(
          courseId: widget.courseId,
          lesson: lesson,
          isWatched: _progress.completedVideoIds.contains(lesson.id),
          isExerciseDone: _progress.completedExerciseVideoIds.contains(lesson.id),
          token: widget.token,
          onMarkComplete: () => _markLessonComplete(lesson),
          onExercise: () => _openExercise(lesson),
        ),
      ),
    );
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

  Future<void> _markLessonComplete(CourseLesson lesson) async {
    final progress = await CoursePlayerService.instance.markVideoComplete(
      widget.courseId,
      lesson.id,
      widget.token,
    );
    if (!mounted) return;
    if (progress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your progress. Please try again.')),
      );
      return;
    }
    setState(() {
      _progress = CourseProgressState(
        completedVideoIds: {..._progress.completedVideoIds, lesson.id},
        completedExerciseVideoIds: _progress.completedExerciseVideoIds,
      );
    });
  }

  Future<void> _openExercise(CourseLesson lesson) async {
    if (!lesson.hasExercises) return;
    if (!_progress.completedVideoIds.contains(lesson.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please attend or watch "${lesson.title}" before taking the assessment.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Watch Now',
            textColor: Colors.white,
            onPressed: () => _watchLesson(lesson),
          ),
        ),
      );
      return;
    }
    final scorePercent = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseSheet(exercises: lesson.exercises),
    );
    if (scorePercent != null && mounted) {
      final progress = await CoursePlayerService.instance.submitExerciseScore(
        widget.courseId,
        lesson.id,
        scorePercent,
        widget.token,
      );
      if (!mounted) return;
      if (progress != null) {
        setState(() {
          _progress = CourseProgressState(
            completedVideoIds: _progress.completedVideoIds,
            completedExerciseVideoIds: {..._progress.completedExerciseVideoIds, lesson.id},
          );
        });
      }
    }
  }

  Widget _defaultHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.school_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _circularFrostedButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'SD';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    if (detail == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          ),
          title: Text(widget.courseTitle, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: _loadFailed
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Couldn't load this course. Check your connection and try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _loadFailed = false);
                          _load();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final categoryLabel = detail.category.isNotEmpty
        ? detail.category
        : (detail.universityName.isNotEmpty ? detail.universityName : 'Course');

    final instructorOrUni = detail.instructorName.isNotEmpty
        ? detail.instructorName
        : detail.universityName;

    final durationText = detail.durationWeeks.isNotEmpty ? '${detail.durationWeeks} weeks' : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Top Hero Banner
                  Stack(
                    children: [
                      SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: detail.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                detail.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _defaultHero(),
                              )
                            : _defaultHero(),
                      ),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _circularFrostedButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Navigator.of(context).maybePop(),
                              ),
                              _circularFrostedButton(
                                icon: Icons.share_outlined,
                                onPressed: _shareCourse,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Sheet Body with rounded top
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Pill + Bookmark Icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (categoryLabel.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    categoryLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox.shrink(),
                              IconButton(
                                icon: Icon(
                                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  color: _isBookmarked ? AppColors.primary : AppColors.textPrimary,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(() => _isBookmarked = !_isBookmarked);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_isBookmarked ? 'Saved to bookmarks' : 'Removed from bookmarks'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Course Title
                          Text(
                            detail.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Metadata Row (real data only)
                          Row(
                            children: [
                              if (durationText.isNotEmpty) ...[
                                const Icon(Icons.access_time_rounded, size: 14.5, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  durationText,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                ),
                                const Text('  •  ', style: TextStyle(color: AppColors.textMuted)),
                              ],
                              const Icon(Icons.play_circle_outline_rounded, size: 15, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${detail.totalLessons} lesson${detail.totalLessons == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                              ),
                              if (detail.universityName.isNotEmpty) ...[
                                const Text('  •  ', style: TextStyle(color: AppColors.textMuted)),
                                Expanded(
                                  child: Text(
                                    detail.universityName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Description
                          if (detail.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              cleanCourseDescription(detail.description),
                              maxLines: _isDescriptionExpanded ? null : 3,
                              overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF475569),
                                height: 1.55,
                                letterSpacing: 0.1,
                              ),
                            ),
                            if (cleanCourseDescription(detail.description).length > 120)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isDescriptionExpanded ? 'Show less' : 'Read more',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          _isDescriptionExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],

                          // Instructor / Institution Row
                          if (instructorOrUni.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  child: Text(
                                    _getInitials(instructorOrUni),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        instructorOrUni,
                                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                      ),
                                      Text(
                                        detail.instructorName.isNotEmpty ? 'Course Instructor' : 'Partner Institution',
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Pill Tabs: Course Outline | About
                          Row(
                            children: [
                              _TabPill(
                                title: 'Course Outline',
                                isSelected: _selectedTab == 0,
                                onTap: () => setState(() => _selectedTab = 0),
                              ),
                              const SizedBox(width: 10),
                              _TabPill(
                                title: 'About',
                                isSelected: _selectedTab == 1,
                                onTap: () => setState(() => _selectedTab = 1),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Tab Content
                          if (_selectedTab == 0) ...[
                            if (detail.modules.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No lessons have been published for this course yet.',
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              for (var i = 0; i < detail.modules.length; i++)
                                _ModuleSection(
                                  moduleIndex: i,
                                  module: detail.modules[i],
                                  courseThumbnail: detail.thumbnailUrl,
                                  progress: _progress,
                                  onWatch: _watchLesson,
                                  onOpenDocument: _openDocument,
                                  onMarkComplete: _markLessonComplete,
                                  onExercise: _openExercise,
                                ),
                          ] else ...[
                            // About tab content
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Overview',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    detail.description.isNotEmpty
                                        ? cleanCourseDescription(detail.description)
                                        : 'Comprehensive curriculum designed to equip learners with industry-relevant skills and practical expertise.',
                                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.55),
                                  ),
                                  if (detail.universityName.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance_outlined, size: 16, color: AppColors.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            detail.universityName,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

          // Bottom Floating Capsule Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _onBottomAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Vibrant blue matching reference
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _progress.completedVideoIds.isEmpty ? 'Start Learning' : 'Continue Learning',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({required this.title, required this.isSelected, required this.onTap});

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({
    required this.moduleIndex,
    required this.module,
    this.courseThumbnail = '',
    required this.progress,
    required this.onWatch,
    required this.onOpenDocument,
    required this.onMarkComplete,
    required this.onExercise,
  });

  final int moduleIndex;
  final CourseModule module;
  final String courseThumbnail;
  final CourseProgressState progress;
  final ValueChanged<CourseLesson> onWatch;
  final ValueChanged<String> onOpenDocument;
  final ValueChanged<CourseLesson> onMarkComplete;
  final ValueChanged<CourseLesson> onExercise;

  @override
  Widget build(BuildContext context) {
    final isEmpty = module.lessons.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('module_${module.id}_$moduleIndex'),
          enabled: !isEmpty,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          trailing: isEmpty
              ? null
              : Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF1F5F9),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MODULE ${(moduleIndex + 1).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (!isEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${module.lessons.length} Video${module.lessons.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                module.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              if (isEmpty) ...[
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.hourglass_empty_rounded, size: 12, color: AppColors.textMuted),
                    SizedBox(width: 4),
                    Text(
                      'Lessons coming soon',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
          children: [
            for (var i = 0; i < module.lessons.length; i++)
              _LessonTile(
                 lessonIndex: i,
                 lesson: module.lessons[i],
                 isWatched: progress.completedVideoIds.contains(module.lessons[i].id),
                 isExerciseDone: progress.completedExerciseVideoIds.contains(module.lessons[i].id),
                 onWatch: () => onWatch(module.lessons[i]),
                 onOpenDocument: onOpenDocument,
                 onMarkComplete: () => onMarkComplete(module.lessons[i]),
                 onExercise: () => onExercise(module.lessons[i]),
               ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lessonIndex,
    required this.lesson,
    required this.isWatched,
    required this.isExerciseDone,
    required this.onWatch,
    required this.onOpenDocument,
    required this.onMarkComplete,
    required this.onExercise,
  });

  final int lessonIndex;
  final CourseLesson lesson;
  final bool isWatched;
  final bool isExerciseDone;
  final VoidCallback onWatch;
  final ValueChanged<String> onOpenDocument;
  final VoidCallback onMarkComplete;
  final VoidCallback onExercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onWatch,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isWatched
                          ? Colors.green.withValues(alpha: 0.3)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: lesson.isDocument
                      ? Container(
                          decoration: BoxDecoration(
                            color: isWatched
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFECFDF5),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isWatched ? Icons.check_circle_rounded : Icons.picture_as_pdf_rounded,
                                color: isWatched ? Colors.green : const Color(0xFF059669),
                                size: 20,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'PDF',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : (lesson.thumbnailUrl.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  lesson.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFF3E8FF),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 22,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Container(
                                  color: Colors.black.withValues(alpha: isWatched ? 0.35 : 0.2),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    isWatched ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                    color: isWatched ? Colors.greenAccent : Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              color: isWatched
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : const Color(0xFFF3E8FF),
                              alignment: Alignment.center,
                              child: Icon(
                                isWatched ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                                color: isWatched ? Colors.green : AppColors.primary,
                                size: 22,
                              ),
                            )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        lesson.isDocument
                            ? 'Study Material • PDF'
                            : 'Lecture ${(lessonIndex + 1).toString().padLeft(2, '0')}${lesson.duration.isNotEmpty ? ' • ${lesson.duration}' : ''}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (isWatched)
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                else
                  Icon(
                    lesson.isDocument
                        ? Icons.description_outlined
                        : (lesson.hasVideo ? Icons.play_circle_outline_rounded : Icons.lock_outline_rounded),
                    color: lesson.isDocument
                        ? const Color(0xFF059669)
                        : (lesson.hasVideo ? AppColors.primary : AppColors.textMuted),
                    size: 20,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 54, top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    if (lesson.isDocument) {
                      onOpenDocument(lesson.fullDocumentUrl);
                    } else {
                      onWatch();
                    }
                  },
                  icon: Icon(
                    lesson.isDocument ? Icons.description_outlined : Icons.play_arrow_rounded,
                    size: 15,
                  ),
                  label: Text(lesson.isDocument ? 'View Document' : 'Watch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: lesson.isDocument ? const Color(0xFF059669) : AppColors.primary,
                    side: BorderSide(
                      color: lesson.isDocument ? const Color(0xFF059669) : AppColors.primary,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (!isWatched)
                  TextButton.icon(
                    onPressed: onMarkComplete,
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: Text(lesson.isDocument ? 'Mark Completed' : 'Mark Watched'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (lesson.hasExercises)
                  TextButton.icon(
                    onPressed: isExerciseDone ? null : onExercise,
                    icon: Icon(
                      isExerciseDone
                          ? Icons.fact_check_rounded
                          : (!isWatched ? Icons.lock_outline_rounded : Icons.quiz_outlined),
                      size: 15,
                    ),
                    label: Text(
                      isExerciseDone
                          ? 'Exercise Passed'
                          : (!isWatched
                              ? 'Assessment (Watch first)'
                              : (lesson.exercises.length > 1
                                  ? 'Take Quiz (${lesson.exercises.length})'
                                  : 'Take Exercise')),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isExerciseDone
                          ? Colors.green
                          : (!isWatched ? AppColors.textSecondary : AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A real lesson quiz - every question the instructor attached to this
/// lesson (not just the first one), presented one at a time like the real
/// exam flow, with a final score/grade summary before the result is saved.
class _ExerciseSheet extends StatefulWidget {
  const _ExerciseSheet({required this.exercises});

  final List<LessonExercise> exercises;

  @override
  State<_ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<_ExerciseSheet> {
  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  int _currentIndex = 0;
  final Map<int, String> _answers = {};
  bool _showResult = false;

  void _select(String option) {
    setState(() => _answers[_currentIndex] = option);
  }

  int get _correctCount {
    var count = 0;
    for (var i = 0; i < widget.exercises.length; i++) {
      if (_answers[i] == widget.exercises[i].correctAnswer) count++;
    }
    return count;
  }

  int get _scorePercent =>
      widget.exercises.isEmpty ? 0 : ((_correctCount / widget.exercises.length) * 100).round();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: _showResult ? _buildResult() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final total = widget.exercises.length;
    final exercise = widget.exercises[_currentIndex];
    final selected = _answers[_currentIndex];
    final answeredCount = _answers.length;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        total > 1 ? 'Quiz Practice' : 'Quick Exercise',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ),
                    if (total > 1)
                      Text(
                        '${_currentIndex + 1} / $total  •  $answeredCount/$total answered',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                if (total > 1) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / total,
                      minHeight: 5,
                      backgroundColor: AppColors.fieldBorder,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '${_currentIndex + 1}. ${exercise.question}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.35),
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < exercise.options.length; i++) ...[
                  _OptionCard(
                    letter: _letters[i % _letters.length].toLowerCase(),
                    label: exercise.options[i],
                    isSelected: selected == exercise.options[i],
                    isCorrectAnswer: false,
                    revealResult: false,
                    onTap: () => _select(exercise.options[i]),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_currentIndex > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentIndex -= 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.fieldBorder),
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              if (_currentIndex > 0) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          if (_currentIndex < total - 1) {
                            setState(() => _currentIndex += 1);
                          } else {
                            setState(() => _showResult = true);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(_currentIndex < total - 1 ? 'Next' : 'See Result'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final total = widget.exercises.length;
    final correct = _correctCount;
    final passed = _scorePercent >= 40;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.fieldBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: passed ? [Colors.green.shade600, Colors.green.shade400] : [AppColors.error, const Color(0xFFEF6666)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(passed ? Icons.celebration_rounded : Icons.replay_rounded, color: Colors.white, size: 34),
                const SizedBox(height: 8),
                Text(
                  passed ? 'Well done!' : 'Keep practicing!',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  '$correct / $total correct · $_scorePercent%',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < widget.exercises.length; i++) ...[
            _ExerciseReviewRow(index: i + 1, exercise: widget.exercises[i], selected: _answers[i]),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_scorePercent),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseReviewRow extends StatelessWidget {
  const _ExerciseReviewRow({required this.index, required this.exercise, required this.selected});

  final int index;
  final LessonExercise exercise;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final isCorrect = selected == exercise.correctAnswer;
    final color = isCorrect ? Colors.green : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q$index. ${exercise.question}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                if (!isCorrect) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Correct answer: ${exercise.correctAnswer}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One lettered, tappable answer option. After a submit, the correct
/// answer turns green and a wrongly-picked one turns red, like a standard
/// mobile quiz UI, instead of a plain radio list.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.letter,
    required this.label,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.revealResult,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool revealResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color borderColor = isSelected ? AppColors.primary : AppColors.fieldBorder;
    Color fillColor = isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface;
    Color textColor = isSelected ? AppColors.primary : AppColors.textPrimary;
    IconData? trailingIcon;

    if (revealResult) {
      if (isCorrectAnswer) {
        borderColor = Colors.green;
        fillColor = Colors.green.withValues(alpha: 0.08);
        textColor = Colors.green.shade800;
        trailingIcon = Icons.check_circle_rounded;
      } else if (isSelected) {
        borderColor = AppColors.error;
        fillColor = AppColors.error.withValues(alpha: 0.08);
        textColor = AppColors.error;
        trailingIcon = Icons.cancel_rounded;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: borderColor, width: isSelected || (revealResult && isCorrectAnswer) ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$letter. $label',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, size: 20, color: borderColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
