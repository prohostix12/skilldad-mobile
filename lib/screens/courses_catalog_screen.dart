import 'package:flutter/material.dart';

import '../services/content_service.dart';
import '../theme/app_colors.dart';
import '../widgets/featured_course_card.dart';
import 'course_detail_screen.dart';
import 'study_abroad_screen.dart';

/// The real program-type categories the web catalog filters by
/// (client/src/pages/CourseCatalog.jsx) - not an invented taxonomy.
/// Study Abroad isn't in here: selecting it navigates to its own real
/// drill-down (StudyAbroadScreen) instead of filtering this course list,
/// matching how the web page embeds a completely different component for it.
enum CourseCategory { all, skill, diploma, wbl }

/// Real sub-categories under WBL (client/src/pages/CourseCatalog.jsx's
/// "WBL Sub-tabs"): international placements vs domestic ones.
enum _WblFilter { international, domestic }

/// The public course catalog - every real course on the platform
/// (GET /api/courses, unfiltered), reachable from the landing page's
/// "Explore Courses" button and the footer's "Courses" quick link.
/// Anyone can browse this without signing in, matching the real website.
class CoursesCatalogScreen extends StatefulWidget {
  const CoursesCatalogScreen({super.key, this.initialCategory = CourseCategory.all});

  final CourseCategory initialCategory;

  @override
  State<CoursesCatalogScreen> createState() => _CoursesCatalogScreenState();
}

class _CoursesCatalogScreenState extends State<CoursesCatalogScreen> {
  List<RemoteCourse>? _courses;
  late CourseCategory _category = widget.initialCategory;
  _WblFilter _wblFilter = _WblFilter.international;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final courses = await ContentService.instance.fetchAllCourses();
    if (!mounted) return;
    setState(() => _courses = courses);
  }

  bool _matches(RemoteCourse course) {
    switch (_category) {
      case CourseCategory.all:
        return true;
      case CourseCategory.skill:
        return course.isSkillCourse;
      case CourseCategory.diploma:
        return course.isDiploma;
      case CourseCategory.wbl:
        return _wblFilter == _WblFilter.international ? course.isWblAbroad : course.isWblDomestic;
    }
  }

  void _openStudyAbroad() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const StudyAbroadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = _courses;
    final filtered = courses?.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.fieldBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Courses',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            if (courses != null && courses.isNotEmpty) ...[
              _CategoryTabs(
                courses: courses,
                selected: _category,
                onSelected: (category) => setState(() => _category = category),
                onStudyAbroad: _openStudyAbroad,
              ),
              if (_category == CourseCategory.wbl) ...[
                const SizedBox(height: 10),
                _WblSubTabs(
                  selected: _wblFilter,
                  onSelected: (filter) => setState(() => _wblFilter = filter),
                ),
              ],
            ],
            if (filtered != null && filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${filtered.length} ${filtered.length == 1 ? 'Program' : 'Programs'} Available',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: AppColors.primaryLight),
                        SizedBox(width: 4),
                        Text(
                          'Verified Degrees',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: courses == null
                  ? const Center(child: CircularProgressIndicator())
                  : filtered!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          courses.isEmpty
                              ? 'No courses are published yet. Check back soon.'
                              : 'No courses in this category yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final course = filtered[index];
                          return FeaturedCourseCard(
                            course: course,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CourseDetailScreen(courseId: course.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.courses,
    required this.selected,
    required this.onSelected,
    required this.onStudyAbroad,
  });

  final List<RemoteCourse> courses;
  final CourseCategory selected;
  final ValueChanged<CourseCategory> onSelected;
  final VoidCallback onStudyAbroad;

  @override
  Widget build(BuildContext context) {
    final items = <(CourseCategory?, String, IconData, int?)>[
      (CourseCategory.all, 'All Courses', Icons.apps_rounded, courses.length),
      (
        CourseCategory.skill,
        'Skill Courses',
        Icons.bolt_rounded,
        courses.where((c) => c.isSkillCourse).length,
      ),
      (
        CourseCategory.diploma,
        'Skill Integrated Degree',
        Icons.workspace_premium_outlined,
        courses.where((c) => c.isDiploma).length,
      ),
      (
        CourseCategory.wbl,
        'WBL (Work Based Learning)',
        Icons.handshake_outlined,
        courses.where((c) => c.isWbl).length,
      ),
      // Study Abroad isn't a course filter - it opens the real
      // country -> university -> course drill-down instead.
      (null, 'Study Abroad', Icons.flight_takeoff_rounded, null),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (category, label, icon, count) = items[index];
          final isSelected = category != null && category == selected;
          return InkWell(
            onTap: () => category == null ? onStudyAbroad() : onSelected(category),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.fieldBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: isSelected ? Colors.white : AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    count == null ? label : '$label ($count)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (category == null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.textMuted),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WblSubTabs extends StatelessWidget {
  const _WblSubTabs({required this.selected, required this.onSelected});

  final _WblFilter selected;
  final ValueChanged<_WblFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (_WblFilter.international, 'International Programmes'),
      (_WblFilter.domestic, 'Domestic Programmes'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            for (final (filter, label) in items)
              Expanded(
                child: InkWell(
                  onTap: () => onSelected(filter),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: filter == selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: filter == selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
