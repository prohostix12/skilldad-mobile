import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../services/course_player_service.dart';
import '../theme/app_colors.dart';
import 'course_player_screen.dart';
import 'login_screen.dart';

/// The public course detail page - real title, description, instructor,
/// university, price and module/lesson outline (GET /api/courses/:id,
/// unauthenticated shape). If the visitor is signed in and already
/// enrolled, this opens the real lesson player instead of re-showing the
/// public page; otherwise it offers the real enrollment page on the
/// website, since in-app payment isn't wired up on mobile yet. Resolves
/// the student's session itself, so callers (the public catalog, the
/// landing page) don't need to know or care whether anyone's signed in.
class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  PublicCourseDetail? _detail;
  bool _loadFailed = false;
  bool _isEnrolled = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AuthService.instance.restoreSession();
    final token = user?.token;
    final results = await Future.wait([
      ContentService.instance.fetchCourseDetail(widget.courseId),
      if (token != null) CoursePlayerService.instance.fetchProgress(widget.courseId, token),
    ]);
    if (!mounted) return;
    setState(() {
      _detail = results[0] as PublicCourseDetail?;
      _loadFailed = _detail == null;
      _token = token;
      _isEnrolled = token != null && (results[1] as CourseProgressState).isEnrolled;
    });
  }

  void _continueLearning() {
    final token = _token;
    final detail = _detail;
    if (token == null || detail == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CoursePlayerScreen(courseId: detail.id, courseTitle: detail.title, token: token),
      ),
    );
  }

  Future<void> _enroll() async {
    if (_token == null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            onLoginSuccess: (user) {
              setState(() => _token = user.token);
              _load();
            },
          ),
        ),
      );
      return;
    }
    // In-app payment isn't wired up on mobile yet - hand off to the real
    // checkout page (client/src/pages/student/PaymentInitiation.jsx, route
    // `/dashboard/payment/:courseId`) the website's own "Enroll Now" button
    // (CourseEnrollment.jsx's handleEnrollment) itself navigates to - not
    // the course player page, which only works once already enrolled.
    final uri = Uri.parse('https://skilldad.com/dashboard/payment/${widget.courseId}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the enrollment page.')),
      );
    }
  }

  bool _isBookmarked = false;
  int _selectedTab = 0; // 0: Course Outline, 1: About
  bool _isDescriptionExpanded = false;

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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
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
            child: SingleChildScrollView(
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
                              RemoteCourse.cleanDescription(detail.description),
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
                            if (RemoteCourse.cleanDescription(detail.description).length > 120)
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
                                _PublicModuleSection(
                                  moduleIndex: i,
                                  module: detail.modules[i],
                                  courseThumbnail: detail.thumbnailUrl,
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
                                        ? RemoteCourse.cleanDescription(detail.description)
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
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.payments_outlined, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        detail.isFree ? 'Free Enrollment' : 'Fee: ₹${detail.price}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                    ],
                                  ),
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
                    onPressed: _isEnrolled ? _continueLearning : _enroll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB), // Vibrant blue matching reference
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _isEnrolled ? 'Continue Learning' : 'Enroll Now',
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

class _PublicModuleSection extends StatelessWidget {
  const _PublicModuleSection({
    required this.moduleIndex,
    required this.module,
    this.courseThumbnail = '',
  });

  final int moduleIndex;
  final CourseModuleSummary module;
  final String courseThumbnail;

  @override
  Widget build(BuildContext context) {
    final isEmpty = module.lessonCount == 0 && module.lessons.isEmpty;

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
          key: PageStorageKey('pub_module_${module.title}_$moduleIndex'),
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
                          '${module.lessonCount} Video${module.lessonCount == 1 ? '' : 's'}',
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
            if (module.lessons.isNotEmpty)
              for (var i = 0; i < module.lessons.length; i++)
                _PublicLessonTile(
                  lessonIndex: i,
                  lesson: module.lessons[i],
                )
            else
              for (var i = 0; i < module.lessonCount; i++)
                _PublicLessonTile(
                  lessonIndex: i,
                  lesson: CourseLessonSummary(
                    id: 'lesson_$i',
                    title: 'Class ${i + 1}',
                    duration: '',
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PublicLessonTile extends StatelessWidget {
  const _PublicLessonTile({
    required this.lessonIndex,
    required this.lesson,
  });

  final int lessonIndex;
  final CourseLessonSummary lesson;

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: lesson.thumbnailUrl.isNotEmpty
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
                        color: Colors.black.withValues(alpha: 0.22),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  )
                : Container(
                    color: const Color(0xFFF3E8FF),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
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
                  'Lecture ${(lessonIndex + 1).toString().padLeft(2, '0')}${lesson.duration.isNotEmpty ? ' • ${lesson.duration}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_rounded,
            color: Color(0xFF94A3B8),
            size: 18,
          ),
        ],
      ),
    );
  }
}
