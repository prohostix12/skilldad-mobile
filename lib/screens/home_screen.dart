import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/home_content.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../theme/app_colors.dart';
import '../widgets/director_card.dart';
import '../widgets/featured_course_card.dart';
import '../widgets/reason_tile.dart';
import '../widgets/skilldad_logo.dart';
import 'course_detail_screen.dart';
import 'courses_catalog_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'universities_screen.dart';
import 'university_detail_screen.dart';

/// The app's entry screen. Mirrors the structure of the web app's landing
/// page and loads its course and leadership content live from the real
/// SkillDad platform (see ContentService) rather than static placeholders.
/// Signing in/up is reached only through the "Sign In" button in the top
/// bar - everything else here is visible to anyone, signed in or not.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AuthUser? _user;
  bool _authChecked = false;

  FeaturedCourses? _courses;
  List<RemoteDirector>? _directors;
  List<RemoteUniversity>? _universities;

  final _featuredCoursesKey = GlobalKey();
  final _partnersKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _openCoursesCatalog({CourseCategory category = CourseCategory.all}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => CoursesCatalogScreen(initialCategory: category)),
    );
  }

  void _openUniversities() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UniversitiesScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadCourses();
    _loadDirectors();
    _loadUniversities();
  }

  Future<void> _loadUniversities() async {
    final universities = await ContentService.instance.fetchUniversities();
    if (!mounted) return;
    setState(() => _universities = universities);
  }

  Future<void> _loadSession() async {
    final user = await AuthService.instance.restoreSession();
    if (!mounted) return;
    setState(() {
      _user = user;
      _authChecked = true;
    });
  }

  Future<void> _loadCourses() async {
    final courses = await ContentService.instance.fetchFeaturedCourses();
    if (!mounted) return;
    setState(() => _courses = courses);
  }

  Future<void> _loadDirectors() async {
    final directors = await ContentService.instance.fetchLandingDirectors();
    if (!mounted) return;
    setState(() => _directors = directors);
  }

  Future<void> _openSignIn() async {
    final result = await Navigator.of(context).push<AuthUser>(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    // The user may have signed in (or up) on the screen(s) pushed above -
    // refresh so the top bar reflects it.
    await _loadSession();
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome, ${result.name.split(' ').first}!')),
      );
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    setState(() => _user = null);
  }

  void _openDashboard() {
    final user = _user;
    if (user == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DashboardScreen(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CurvedHeader(
                user: _authChecked ? _user : null,
                onSignIn: _openSignIn,
                onSignOut: _signOut,
                isSignedIn: _authChecked && _user != null,
                onExploreCourses: _openCoursesCatalog,
                onOpenDashboard: _openDashboard,
              ),
              const SizedBox(height: 18),
              Container(
                key: _featuredCoursesKey,
                child: _FeaturedCoursesSection(
                  courses: _courses,
                  onViewAll: _openCoursesCatalog,
                  onExploreWbl: () => _openCoursesCatalog(category: CourseCategory.wbl),
                  onExploreSkill: () => _openCoursesCatalog(category: CourseCategory.skill),
                ),
              ),
              const SizedBox(height: 24),
              const _WhySkillDadTeaser(),
              const SizedBox(height: 32),
              const _CapabilitiesSection(),
              const SizedBox(height: 32),
              _LeadershipSection(directors: _directors),
              const SizedBox(height: 32),
              Container(
                key: _partnersKey,
                child: _TrustedPartnersSection(
                  universities: _universities,
                  onExploreUniversities: _openUniversities,
                ),
              ),
              const SizedBox(height: 28),
              const _GetStartedBanner(),
              const SizedBox(height: 32),
              _ReasonsSection(onExploreUniversities: _openUniversities),
              const SizedBox(height: 28),
              const _MissionBanner(),
              const SizedBox(height: 32),
              const _LearnersSection(),
              const SizedBox(height: 32),
              _HomeFooter(
                onCourses: _openCoursesCatalog,
                onUniversities: _openUniversities,
                onPartners: () => _scrollTo(_partnersKey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader({
    required this.user,
    required this.onSignIn,
    required this.onSignOut,
    required this.isSignedIn,
    required this.onExploreCourses,
    required this.onOpenDashboard,
  });

  final AuthUser? user;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final bool isSignedIn;
  final VoidCallback onExploreCourses;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return CustomPaint(
      painter: const _HeaderWavePainter(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topInset + 28, 16, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBar(
              user: user,
              onSignIn: onSignIn,
              onSignOut: onSignOut,
            ),
            const SizedBox(height: 36),
            _HeroContent(
              isSignedIn: isSignedIn,
              onExploreCourses: onExploreCourses,
              onOpenDashboard: onOpenDashboard,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.user,
    required this.onSignIn,
    required this.onSignOut,
  });

  final AuthUser? user;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SkillDadLogo(
                markSize: 26,
                fontSize: 18,
                textColor: Colors.white,
                markColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (user != null)
          IconButton(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            tooltip: 'Sign out',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: InkWell(
              onTap: onSignIn,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

bool _isTestRunning() {
  return WidgetsBinding.instance.runtimeType.toString().contains('Test');
}

class _HeroContent extends StatefulWidget {
  const _HeroContent({
    required this.isSignedIn,
    required this.onExploreCourses,
    required this.onOpenDashboard,
  });

  final bool isSignedIn;
  final VoidCallback onExploreCourses;
  final VoidCallback onOpenDashboard;

  @override
  State<_HeroContent> createState() => _HeroContentState();
}

class _HeroContentState extends State<_HeroContent> with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subFade;
  late final Animation<Offset> _subSlide;
  late final Animation<double> _btnFade;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    ));

    _subFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    );
    _subSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));

    _btnFade = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _btnScale = Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
    ));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 15,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _titleFade,
                child: SlideTransition(
                  position: _titleSlide,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confusion to',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Career',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF3E8FF),
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _subFade,
                child: SlideTransition(
                  position: _subSlide,
                  child: const Text(
                    'Learn from top courses, earn certifications and get placement support – all in one place.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFE9D5FF),
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _btnFade,
                child: ScaleTransition(
                  scale: _btnScale,
                  child: _ExploreButton(
                    isSignedIn: widget.isSignedIn,
                    onPressed: widget.isSignedIn ? widget.onOpenDashboard : widget.onExploreCourses,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          flex: 10,
          child: _HeroGraphic(),
        ),
      ],
    );
  }
}

class _ExploreButton extends StatefulWidget {
  const _ExploreButton({
    required this.isSignedIn,
    required this.onPressed,
  });

  final bool isSignedIn;
  final VoidCallback onPressed;

  @override
  State<_ExploreButton> createState() => _ExploreButtonState();
}

class _ExploreButtonState extends State<_ExploreButton> with SingleTickerProviderStateMixin {
  late final AnimationController _arrowCtrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_isTestRunning()) {
      _arrowCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: const Color(0xFF3B0764).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.isSignedIn ? 'Go to Dashboard' : 'Explore Courses',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4C1D95),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedBuilder(
                    animation: _arrowCtrl,
                    builder: (context, child) {
                      final dx = CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut).value * 3.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Icon(
                          widget.isSignedIn ? Icons.dashboard_rounded : Icons.arrow_forward_rounded,
                          size: 15,
                          color: const Color(0xFF4C1D95),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGraphic extends StatelessWidget {
  const _HeroGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft glowing backdrop blob behind the student
          Positioned(
            right: 4,
            top: 20,
            width: 140,
            height: 180,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: const RadialGradient(
                  colors: [
                    Color.fromRGBO(139, 92, 246, 0.38),
                    Color.fromRGBO(126, 34, 206, 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Subtle dashed journey progress curves
          const Positioned.fill(
            child: CustomPaint(
              painter: _JourneyCurvesPainter(),
            ),
          ),
          // Student illustration static in place
          Positioned(
            left: 0,
            right: 12,
            top: 14,
            bottom: 0,
            child: Image.asset(
              'assets/images/login_student.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
            ),
          ),
          // Top badge: Graduation Cap
          const Positioned(
            left: 6,
            top: 2,
            child: _HeroBadgeCard(icon: Icons.school_outlined),
          ),
          // Middle-right badge: Briefcase
          const Positioned(
            right: 0,
            top: 48,
            child: _HeroBadgeCard(icon: Icons.work_outline_rounded),
          ),
          // Bottom-right badge: Certificate
          const Positioned(
            right: 4,
            bottom: 32,
            child: _HeroBadgeCard(icon: Icons.workspace_premium_outlined),
          ),
        ],
      ),
    );
  }
}

class _HeroBadgeCard extends StatelessWidget {
  const _HeroBadgeCard({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.42),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: 19,
        color: Colors.white,
      ),
    );
  }
}

class _JourneyCurvesPainter extends CustomPainter {
  const _JourneyCurvesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Curve 1: Top badge (Graduation Cap) to Middle-right badge (Briefcase)
    final path1 = Path();
    path1.moveTo(36, 20);
    path1.cubicTo(size.width * 0.55, 12, size.width * 0.72, 30, size.width - 24, 56);

    // Curve 2: Middle-right badge (Briefcase) to Bottom-right badge (Certificate)
    final path2 = Path();
    path2.moveTo(size.width - 16, 90);
    path2.cubicTo(size.width + 4, 118, size.width - 2, 138, size.width - 12, 150);

    // Subtle faint loop pointing up to top badge
    final path3 = Path();
    path3.moveTo(size.width * 0.30, 70);
    path3.cubicTo(size.width * 0.20, 50, 24, 42, 24, 34);

    _drawDashedPath(canvas, path1, paint);
    _drawDashedPath(canvas, path2, paint);
    _drawDashedPath(canvas, path3, paint);

    _drawArrowHead(canvas, Offset(size.width - 24, 56), 0.7, paint);
    _drawArrowHead(canvas, Offset(size.width - 12, 150), 1.9, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dash = 4.0, double gap = 3.0}) {
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Paint strokePaint) {
    final fillPaint = Paint()
      ..color = strokePaint.color
      ..style = PaintingStyle.fill;
    const arrowSize = 4.5;
    final path = Path();
    final p1 = Offset(
      tip.dx - arrowSize * math.cos(angle - 0.5),
      tip.dy - arrowSize * math.sin(angle - 0.5),
    );
    final p2 = Offset(
      tip.dx - arrowSize * math.cos(angle + 0.5),
      tip.dy - arrowSize * math.sin(angle + 0.5),
    );
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeaderWavePainter extends CustomPainter {
  const _HeaderWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Secondary (lower translucent) wave path
    final secondaryPath = Path();
    secondaryPath.moveTo(0, 0);
    secondaryPath.lineTo(0, h * 0.915);
    secondaryPath.cubicTo(
      w * 0.10, h * 0.950,
      w * 0.22, h * 0.985,
      w * 0.36, h * 0.985,
    );
    secondaryPath.cubicTo(
      w * 0.60, h * 0.985,
      w * 0.82, h * 0.900,
      w, h * 0.860,
    );
    secondaryPath.lineTo(w, 0);
    secondaryPath.close();

    // Primary (foreground deep purple) wave path
    final primaryPath = Path();
    primaryPath.moveTo(0, 0);
    primaryPath.lineTo(0, h * 0.880);
    primaryPath.cubicTo(
      w * 0.10, h * 0.915,
      w * 0.20, h * 0.950,
      w * 0.32, h * 0.950,
    );
    primaryPath.cubicTo(
      w * 0.55, h * 0.950,
      w * 0.78, h * 0.865,
      w, h * 0.825,
    );
    primaryPath.lineTo(w, 0);
    primaryPath.close();

    // 1. Subtle ambient shadow underneath
    final shadowPaint = Paint()
      ..color = const Color(0xFF2E0854).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(secondaryPath, shadowPaint);

    // 2. Secondary translucent wave
    final secondaryPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF8B5CF6).withValues(alpha: 0.35),
          const Color(0xFFA855F7).withValues(alpha: 0.22),
          const Color(0xFFC084FC).withValues(alpha: 0.14),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(secondaryPath, secondaryPaint);

    // 3. Primary deep purple gradient wave
    final primaryPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF280757),
          Color(0xFF380A78),
          Color(0xFF4C1093),
          Color(0xFF651AC3),
        ],
        stops: [0.0, 0.32, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(primaryPath, primaryPaint);

    // 4. Soft radial glow on the right (behind student)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.55, -0.1),
        radius: 0.75,
        colors: [
          const Color(0xFF9333EA).withValues(alpha: 0.35),
          const Color(0xFF7E22CE).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(primaryPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}


class _FeaturedCoursesSection extends StatelessWidget {
  const _FeaturedCoursesSection({
    required this.courses,
    required this.onViewAll,
    required this.onExploreWbl,
    required this.onExploreSkill,
  });

  /// Null while still loading; an empty [FeaturedCourses] if the platform
  /// currently has nothing featured or the request failed.
  final FeaturedCourses? courses;
  final VoidCallback onViewAll;
  final VoidCallback onExploreWbl;
  final VoidCallback onExploreSkill;

  @override
  Widget build(BuildContext context) {
    // Mirrors the web landing page: the whole section is hidden if there's
    // nothing featured right now, rather than showing an empty shell.
    if (courses != null && courses!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionEyebrow('Featured Courses'),
                    const SizedBox(height: 8),
                    const Text(
                      'Our Career Transforming\nProgrammes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
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
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Learn the skills and knowledge you need to build a successful career.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: courses == null
                ? const Padding(
                    key: ValueKey('courses_loading'),
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    key: const ValueKey('courses_loaded'),
                    children: [
                      if (courses!.wbl.isNotEmpty) ...[
                        _CourseGroup(
                          label: 'Work-Based Learning Programme',
                          exploreLabel: 'Explore WBL Catalog',
                          courses: courses!.wbl,
                          onExplore: onExploreWbl,
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (courses!.skill.isNotEmpty)
                        _CourseGroup(
                          label: 'Skill Courses',
                          exploreLabel: 'Explore Skill Courses',
                          courses: courses!.skill,
                          onExplore: onExploreSkill,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CourseGroup extends StatelessWidget {
  const _CourseGroup({
    required this.label,
    required this.exploreLabel,
    required this.courses,
    required this.onExplore,
  });

  final String label;
  final String exploreLabel;
  final List<RemoteCourse> courses;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (courses.length <= 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < courses.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: FeaturedCourseCard(
                    course: courses[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CourseDetailScreen(courseId: courses[i].id),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < courses.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: 165,
                    child: FeaturedCourseCard(
                      course: courses[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CourseDetailScreen(courseId: courses[i].id),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onExplore,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(exploreLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WhySkillDadTeaser extends StatelessWidget {
  const _WhySkillDadTeaser();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionEyebrow('Why SkillDad'),
            const SizedBox(height: 8),
            const Text(
              'Intelligent Tools For\nDynamic Teams',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A growing toolkit built to equip students, universities and '
              'enterprises with the right tools for learning, hiring and growth.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: link to a capabilities/features detail screen.
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Explore More', style: TextStyle(fontSize: 12.5)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 15),
                    ],
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

class _CapabilitiesSection extends StatelessWidget {
  const _CapabilitiesSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < kPlatformCapabilities.length; i++) ...[
            if (i > 0) const SizedBox(height: 18),
            ReasonTile(
              icon: kPlatformCapabilities[i].icon,
              title: kPlatformCapabilities[i].title,
              description: kPlatformCapabilities[i].description,
            ),
          ],
        ],
      ),
    );
  }
}

class _LeadershipSection extends StatelessWidget {
  const _LeadershipSection({required this.directors});

  /// Null while still loading.
  final List<RemoteDirector>? directors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionEyebrow('Innovation Leadership'),
              const SizedBox(height: 8),
              const Text(
                'Managed by IITians in INDIA',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our team of experienced IITians and industry experts is '
                'dedicated to providing the best learning experience.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 200,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: directors == null
                ? const Center(key: ValueKey('directors_loading'), child: CircularProgressIndicator())
                : ListView.separated(
                    key: const ValueKey('directors_loaded'),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: directors!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => SizedBox(
                      width: 140,
                      child: DirectorCard(director: directors![index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TrustedPartnersSection extends StatelessWidget {
  const _TrustedPartnersSection({required this.universities, required this.onExploreUniversities});

  /// Null while still loading; real partner universities from
  /// GET /api/public/universities + /api/public/skilldad-universities
  /// (same live data ContentService.fetchUniversities already provides for
  /// UniversitiesScreen) - never a fabricated brand-name list.
  final List<RemoteUniversity>? universities;
  final VoidCallback onExploreUniversities;

  @override
  Widget build(BuildContext context) {
    final list = universities ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionEyebrow('Trusted Partners'),
              const SizedBox(height: 8),
              const Text(
                'Trusted by Leading Universities\n& Companies',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We work with top universities and industry partners to bring '
                'you the best opportunities.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: universities == null
              ? const Padding(
                  key: ValueKey('partners_loading'),
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : SizedBox(
                  key: const ValueKey('partners_loaded'),
                  height: 114,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _PartnerCardItem(uni: list[index]),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: InkWell(
            onTap: onExploreUniversities,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Explore Partner Universities & Accreditations',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PartnerCardItem extends StatefulWidget {
  const _PartnerCardItem({required this.uni});

  final RemoteUniversity uni;

  @override
  State<_PartnerCardItem> createState() => _PartnerCardItemState();
}

class _PartnerCardItemState extends State<_PartnerCardItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final uni = widget.uni;
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UniversityDetailScreen(uni: uni),
            ),
          );
        },
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 156,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (uni.logoUrl.isNotEmpty)
                SizedBox(
                  height: 30,
                  child: Image.network(
                    uni.logoUrl,
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                )
              else
                const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                uni.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonsSection extends StatelessWidget {
  const _ReasonsSection({required this.onExploreUniversities});

  final VoidCallback onExploreUniversities;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Reasons to Choose SkillDad',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          const ReasonTile(
            icon: Icons.school_rounded,
            title: 'Industry-relevant Courses',
            description: 'Get job-ready with courses designed by industry experts.',
          ),
          const SizedBox(height: 18),
          const ReasonTile(
            icon: Icons.verified_rounded,
            title: 'Verified Certifications',
            description: 'Showcase your skills with trusted certificates.',
          ),
          const SizedBox(height: 18),
          const ReasonTile(
            icon: Icons.handshake_rounded,
            title: 'Placement Assistance',
            description: 'Get end-to-end support for better career opportunities.',
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onExploreUniversities,
            borderRadius: BorderRadius.circular(16),
            child: const ReasonTile(
              icon: Icons.business_center_rounded,
              title: 'Trusted by Universities & Companies',
              description: 'Learn from the best. Tap to browse verified partners.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionBanner extends StatelessWidget {
  const _MissionBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Career\nOur Mission',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Empowering learners with skills, certifications and '
                    'opportunities for a brighter future.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.track_changes_rounded, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedBanner extends StatelessWidget {
  const _GetStartedBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ready to take the next step\nin your career?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join SkillDad today and get access to world-class '
              'courses, certifications and placement support.',
              style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, 54),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Get Started'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnersSection extends StatelessWidget {
  const _LearnersSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionEyebrow('SkillDad'),
          const SizedBox(height: 8),
          const Text(
            'What Our Learners Say',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 26),
                const SizedBox(height: 8),
                const Text(
                  'Real learner stories are on their way - as our placed '
                  'students share their journeys, you\'ll find them here.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.fieldBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter({
    required this.onCourses,
    required this.onUniversities,
    required this.onPartners,
  });

  final VoidCallback onCourses;
  final VoidCallback onUniversities;
  final VoidCallback onPartners;

  static const _links = ['Courses', 'Universities', 'Partners', 'Contact'];

  void _handleTap(BuildContext context, String label) {
    switch (label) {
      case 'Courses':
        onCourses();
      case 'Universities':
        onUniversities();
      case 'Partners':
        onPartners();
      case 'Contact':
        showDialog<void>(context: context, builder: (_) => const _ContactDialog());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      color: AppColors.surface,
      child: Column(
        children: [
          const SkillDadLogo(markSize: 26, fontSize: 17),
          const SizedBox(height: 8),
          const Text(
            'Learn  ·  Grow  ·  Get Hired',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.fieldBorder),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Links',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Column(
            children: _links
                .map(
                  (label) => InkWell(
                    key: ValueKey('footer_link_$label'),
                    onTap: () => _handleTap(context, label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.fieldBorder),
          const SizedBox(height: 16),
          const Text(
            '© 2026 SkillDad. All rights reserved.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Real SkillDad contact details, matching the web footer
/// (client/src/components/ui/Footer.jsx) - not a placeholder.
class _ContactDialog extends StatelessWidget {
  const _ContactDialog();

  static const _phone = '+918448119306';
  static const _email = 'skilldad12@gmail.com';

  Future<void> _launch(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that app on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact SkillDad',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.call_outlined, color: AppColors.primary),
              title: const Text('+91 8448119306'),
              onTap: () => _launch(context, Uri(scheme: 'tel', path: _phone)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
              title: const Text(_email),
              onTap: () => _launch(context, Uri(scheme: 'mailto', path: _email)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
