import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/career_journey_tracker.dart';
import '../widgets/continue_learning_card.dart';
import '../widgets/performance_donut.dart';
import '../widgets/performance_sparkline.dart';
import '../widgets/skilldad_logo.dart';
import 'career_path_screen.dart';
import 'course_player_screen.dart';
import 'courses_catalog_screen.dart';
import 'exams_screen.dart';
import 'home_screen.dart';
import 'live_sessions_screen.dart';
import 'my_courses_screen.dart';
import 'notifications_screen.dart';

/// The signed-in student's home base. Redesigned for mobile rather than a
/// shrunk copy of client/src/pages/student/StudentDashboard.jsx: the same
/// real sections (hero, continue learning, career journey, upcoming,
/// performance) in a single scrolling column with a bottom nav, instead of
/// that page's two-column desktop layout with an expandable calendar.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.user});

  final AuthUser user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnreadNotifications();
  }

  Future<void> _load() async {
    final data = await DashboardService.instance.fetchDashboard(widget.user.token);
    if (!mounted) return;
    setState(() => _data = data);
  }

  Future<void> _loadUnreadNotifications() async {
    final notifications = await NotificationService.instance.fetchMyNotifications(widget.user.token);
    if (!mounted) return;
    setState(() => _unreadNotifications = notifications.where((n) => !n.isRead).length);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NotificationsScreen(token: widget.user.token)),
    );
    // Reflect any mark-all-read the student just did back on the bell badge.
    _loadUnreadNotifications();
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.split(' ').first;
    final data = _data;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: data == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TopBar(
                        name: widget.user.name,
                        unreadNotifications: _unreadNotifications,
                        onSignOut: _signOut,
                        onOpenNotifications: _openNotifications,
                      ),
                      const SizedBox(height: 18),
                      _HeroCard(firstName: firstName, data: data, token: widget.user.token),
                      const SizedBox(height: 22),
                      _PerformanceCard(data: data),
                      const SizedBox(height: 22),
                      _ContinueLearningSection(data: data, token: widget.user.token),
                      const SizedBox(height: 22),
                      _UpcomingSection(items: data.upcoming, token: widget.user.token),
                      const SizedBox(height: 22),
                      _CareerJourneyCard(data: data, token: widget.user.token),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: AppBottomNav(
        courses: data?.enrolledCourses ?? const [],
        token: widget.user.token,
        currentLabel: 'Home',
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.name,
    required this.unreadNotifications,
    required this.onSignOut,
    required this.onOpenNotifications,
  });

  final String name;
  final int unreadNotifications;
  final VoidCallback onSignOut;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            // Dashboard is the root route after sign-in (login uses
            // pushAndRemoveUntil), so there's no earlier "home" screen on
            // the stack to pop back to - push the real public landing page
            // instead, matching the website's logo-goes-home behaviour.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            ),
            child: const SkillDadLogo(markSize: 26, fontSize: 17),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onOpenNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
              color: AppColors.textPrimary,
            ),
            if (unreadNotifications > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'signout') onSignOut();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.firstName, required this.data, required this.token});

  final String firstName;
  final DashboardData data;
  final String token;

  @override
  Widget build(BuildContext context) {
    final hasStarted = data.enrolledCourses.any((c) => c.progress > 0);
    final ctaLabel = data.enrolledCourses.isEmpty
        ? 'Browse Courses'
        : hasStarted
        ? 'Resume Learning'
        : 'Start Learning';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF4C1D95), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft decorative glow blobs for a premium, non-flat background.
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            right: 20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFA78BFA).withValues(alpha: 0.35), const Color(0xFFA78BFA).withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName 👋',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Keep Learning,\nKeep Growing',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Continue learning and take the next step toward your career goal.',
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75), height: 1.4),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  if (data.enrolledCourses.isEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CoursesCatalogScreen()),
                    );
                    return;
                  }
                  final featured = [...data.enrolledCourses]
                    ..sort((a, b) => b.progress.compareTo(a.progress));
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CoursePlayerScreen(
                        courseId: featured.first.courseId,
                        courseTitle: featured.first.title,
                        token: token,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    Text(ctaLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final completed = data.enrolledCourses.where((c) => c.isCompleted).length;
    final inProgress = data.enrolledCourses.length - completed;
    final careerMilestones = data.careerSteps.where((s) => s.done).length;

    // Same 4-ring colors as the reference chart (outer to inner):
    // pink/magenta, violet/purple, sky blue, amber.
    final segments = [
      PerformanceSegment(label: 'Completed', value: completed, color: const Color(0xFFF2419B)),
      PerformanceSegment(label: 'In Progress', value: inProgress, color: const Color(0xFFA78BFA)),
      PerformanceSegment(label: 'Certificates', value: data.certificatesEarned, color: const Color(0xFF4FC3F7)),
      PerformanceSegment(label: 'Career Milestones', value: careerMilestones, color: const Color(0xFFF7B733)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Performance Overview',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PerformanceDonut(segments: segments),
          if (data.performance.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'This Week',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            PerformanceSparkline(points: data.performance),
          ],
        ],
      ),
    );
  }
}

class _ContinueLearningSection extends StatelessWidget {
  const _ContinueLearningSection({required this.data, required this.token});

  final String token;

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    if (data.enrolledCourses.isEmpty) return const SizedBox.shrink();

    final featured = [...data.enrolledCourses]..sort((a, b) => b.progress.compareTo(a.progress));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Continue Learning',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MyCoursesScreen(courses: data.enrolledCourses, token: token),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ContinueLearningCard(
          course: featured.first,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CoursePlayerScreen(
                courseId: featured.first.courseId,
                courseTitle: featured.first.title,
                token: token,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.items, required this.token});

  final List<UpcomingItem> items;
  final String token;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nothing scheduled yet',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            )
          else
            ...items.map(
              (item) => InkWell(
                onTap: () => _openUpcomingItem(context, item),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.isSession ? Icons.play_arrow_rounded : Icons.event_note_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.isSession ? 'Live Session' : 'Exam',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _formatWhen(item.dateTime),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openUpcomingItem(BuildContext context, UpcomingItem item) {
    if (item.isSession) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => LiveSessionsScreen(token: token)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ExamsScreen(token: token)),
      );
    }
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $time';
    return '${dt.day}/${dt.month} · $time';
  }
}

class _CareerJourneyCard extends StatelessWidget {
  const _CareerJourneyCard({required this.data, required this.token});

  final DashboardData data;
  final String token;

  @override
  Widget build(BuildContext context) {
    if (data.careerSteps.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.track_changes_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Your Career Journey',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${data.careerReadiness}%',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Track your progress and achieve your goals.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          CareerJourneyTracker(steps: data.careerSteps),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CareerPathScreen(data: data, token: token),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View Path', style: TextStyle(fontSize: 12.5)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

