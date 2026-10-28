import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/auto_hide_bottom_nav_scaffold.dart';
import '../widgets/continue_learning_card.dart';
import '../widgets/skilldad_logo.dart';
import 'course_player_screen.dart';
import 'notifications_screen.dart';

/// The student's full enrolled-course list ("My Courses") redesigned to match
/// the reference mockup: deep purple status bar, branded header with SkillDad logo,
/// notification bell and profile avatar, "My Courses" title & subtitle,
/// modern course cards with badges and stats, and subtle wave background.
class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key, required this.courses, required this.token});

  final List<EnrolledCourse> courses;
  final String token;

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  int _unreadNotifications = 1; // Default to 1 unread indicator as shown in reference

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final notifications = await NotificationService.instance.fetchMyNotifications(widget.token);
      if (!mounted) return;
      setState(() => _unreadNotifications = notifications.where((n) => !n.isRead).length);
    } catch (_) {
      // Keep existing unread count
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => NotificationsScreen(token: widget.token)),
    );
    _loadUnreadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.courses]..sort((a, b) => b.progress.compareTo(a.progress));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0xFF380A78),
      ),
      child: AutoHideBottomNavScaffold(
        backgroundColor: Colors.white,
        bottomNav: AppBottomNav(courses: widget.courses, token: widget.token, currentLabel: 'Courses'),
        body: Column(
          children: [
            // Deep purple status bar matching reference
            Container(
              height: MediaQuery.paddingOf(context).top,
              color: const Color(0xFF380A78),
            ),
            // Main content with subtle background wave
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _BottomWavePainter(),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top header bar: Logo + Bell + Avatar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                child: const SkillDadLogo(markSize: 26, fontSize: 18),
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  onPressed: _openNotifications,
                                  icon: const Icon(Icons.notifications_none_rounded),
                                  color: AppColors.primary,
                                  iconSize: 26,
                                  tooltip: 'Notifications',
                                ),
                                if (_unreadNotifications > 0)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: const CircleAvatar(
                                radius: 17,
                                backgroundColor: Color(0xFFEDE9FE),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF6D28D9),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Title & Subtitle
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'My Courses',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF14102B),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Continue learning and build your future',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Course list
                      Expanded(
                        child: sorted.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    "You haven't enrolled in any courses yet.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 88),
                                itemCount: sorted.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final course = sorted[index];
                                  return ContinueLearningCard(
                                    course: course,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => CoursePlayerScreen(
                                          courseId: course.courseId,
                                          courseTitle: course.title,
                                          token: widget.token,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWavePainter extends CustomPainter {
  const _BottomWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.78);
    path.cubicTo(
      w * 0.25, h * 0.84,
      w * 0.65, h * 0.72,
      w, h * 0.80,
    );
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFF3EFFF).withValues(alpha: 0.55),
          const Color(0xFFEDE7F6).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.70, w, h * 0.30));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

