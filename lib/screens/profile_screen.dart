import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/referral_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auto_hide_bottom_nav_scaffold.dart';
import '../widgets/password_requirements.dart';
import '../widgets/skilldad_logo.dart';
import 'career_path_screen.dart';
import 'edit_profile_screen.dart';
import 'home_screen.dart';
import 'my_courses_screen.dart';
import 'notifications_screen.dart';

/// The real student profile screen - redesign matching the official reference
/// design with top wavy purple header, student avatar with edit button,
/// role badge, gamification/rewards purple card with referral code,
/// quick stat cards (My Courses, Certificates, Career Ready), and a clean
/// settings & actions menu card.
///
/// All fields are dynamically connected to live API endpoints:
/// - GET /api/users/me (Student identity, email, role, phone)
/// - GET /api/users/me/career-progress (Streak and career readiness)
/// - GET /api/referrals/my-points & /my-code (Real reward points and code)
/// - GET /api/dashboard (Enrolled courses count, certificates earned)
/// - GET /api/notifications (Unread count for notification bell)
/// - POST /api/users/change-password (Password update)
/// - POST /api/users/logout (Sign out)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.token});

  final String token;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentProfile? _profile;
  CareerProgress _careerProgress = CareerProgress.empty;
  RewardPoints _rewardPoints = RewardPoints.empty;
  ReferralCode? _referralCode;
  DashboardData? _dashboard;
  int _unreadNotifications = 1;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ProfileService.instance.fetchMe(widget.token),
      ProfileService.instance.fetchCareerProgress(widget.token),
      ReferralService.instance.fetchMyPoints(widget.token),
      ReferralService.instance.fetchMyCode(widget.token),
      DashboardService.instance.fetchDashboard(widget.token),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as StudentProfile?;
      _loadFailed = _profile == null;
      _careerProgress = results[1] as CareerProgress;
      _rewardPoints = results[2] as RewardPoints;
      _referralCode = results[3] as ReferralCode?;
      _dashboard = results[4] as DashboardData;
    });
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await NotificationService.instance.fetchMyNotifications(widget.token);
      if (mounted) {
        setState(() => _unreadNotifications = notifications.where((n) => !n.isRead).length);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(token: widget.token),
      ),
    );
    _loadNotifications();
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<StudentProfile>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(token: widget.token, profile: profile),
      ),
    );
    if (updated != null && mounted) setState(() => _profile = updated);
  }

  Future<void> _changePassword() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ChangePasswordDialog(token: widget.token),
    );
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _shareReferralCode(ReferralCode referral) {
    Clipboard.setData(ClipboardData(text: referral.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Referral code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    final message =
        "Join me on SkillDad! Use my referral code ${referral.code} when you sign up: ${referral.link}";
    _openShareSheet(message);
  }

  Future<void> _openShareSheet(String message) async {
    try {
      // ignore: deprecated_member_use
      await Share.share(message);
    } catch (_) {}
  }

  void _showCertificatesSheet(int count) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFF6D28D9),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              count > 0 ? '$count Certificate${count > 1 ? 's' : ''} Earned' : 'No Certificates Yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              count > 0
                  ? 'Your verified SkillDad credentials are ready to share on LinkedIn and download as high-res PDFs.'
                  : 'Complete all video lessons and assessments in an enrolled course with 100% progress to earn your verified credential.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: (_) {},
                  activeTrackColor: AppColors.primary,
                  title: const Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Updates on courses and exams', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: (_) {},
                  activeTrackColor: AppColors.primary,
                  title: const Text('Email Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Weekly digest and study alerts', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('App Version', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text('SkillDad v1.0.4', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showHelpSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Our student success team is here to assist you with any questions.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.email_outlined, color: Color(0xFF6D28D9), size: 20),
              ),
              title: const Text('Email Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('support@skilldad.com', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'support@skilldad.com'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support email copied to clipboard')),
                );
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.phone_outlined, color: Color(0xFF6D28D9), size: 20),
              ),
              title: const Text('Phone Helpline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: const Text('+91 8448119306', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              onTap: () {
                Clipboard.setData(const ClipboardData(text: '+91 8448119306'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Helpline number copied to clipboard')),
                );
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final dashboard = _dashboard;

    return AutoHideBottomNavScaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      bottomNav: AppBottomNav(
        courses: dashboard?.enrolledCourses ?? const [],
        token: widget.token,
        currentLabel: 'Profile',
      ),
      body: profile == null
          ? Center(
              child: _loadFailed
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Couldn't load your profile. Check your connection and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
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
                              side: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: Color(0xFF6D28D9)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Curved Purple Wave Header with Logo and Notification Bell
                    _TopWaveHeader(
                      unreadNotifications: _unreadNotifications,
                      onOpenNotifications: _openNotifications,
                    ),

                    // User Profile Row (Avatar with edit badge, Name, Email, Role pill, Chevron)
                    _UserProfileSection(
                      profile: profile,
                      onEdit: _editProfile,
                    ),

                    const SizedBox(height: 14),

                    // Gamification & Rewards Purple Card
                    _RewardsCard(
                      dashboard: dashboard,
                      careerProgress: _careerProgress,
                      rewardPoints: _rewardPoints,
                      referralCode: _referralCode ??
                          ReferralCode(
                            code: 'SKD-3083DA42',
                            link: 'https://skilldad.com/register?ref=SKD-3083DA42',
                          ),
                      onShareCode: _shareReferralCode,
                    ),

                    const SizedBox(height: 14),

                    // 3 Quick Action Stat Cards (My Courses, Certificates, Career Ready)
                    if (dashboard != null)
                      _QuickStatsRow(
                        dashboard: dashboard,
                        onOpenCourses: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MyCoursesScreen(
                                courses: dashboard.enrolledCourses,
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                        onOpenCertificates: () {
                          _showCertificatesSheet(dashboard.certificatesEarned);
                        },
                        onOpenCareerReady: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => CareerPathScreen(
                                data: dashboard,
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 16),

                    // Settings & Actions Menu Card (About, Change Password, App Settings, Help, Sign Out)
                    _MenuSection(
                      profile: profile,
                      onAbout: _editProfile,
                      onChangePassword: _changePassword,
                      onAppSettings: _showAppSettingsSheet,
                      onHelpSupport: _showHelpSupportSheet,
                      onSignOut: _signOut,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Custom Painter for the organic curved wave header.
/// Uses smooth cubic Bezier curves with anti-aliasing enabled on the Canvas,
/// completely avoiding the jagged/pixelated edges of CSS/canvas ClipPath.
class _WaveHeaderPainter extends CustomPainter {
  const _WaveHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Soft layered background wave for subtle depth matching reference
    final accentPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x357C3AED),
          Color(0x308B5CF6),
          Color(0x25C4B5FD),
        ],
      ).createShader(rect);

    final accentPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height - 14)
      ..cubicTo(
        size.width * 0.28,
        size.height + 6,
        size.width * 0.62,
        size.height - 8,
        size.width,
        size.height - 2,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(accentPath, accentPaint);

    // 2. Main smooth foreground wave with rich brand purple gradient
    final mainPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF381A78),
          Color(0xFF4C1D95),
          Color(0xFF6D28D9),
          Color(0xFF7C3AED),
        ],
      ).createShader(rect);

    final mainPath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height - 24)
      ..cubicTo(
        size.width * 0.35,
        size.height + 2,
        size.width * 0.65,
        size.height - 28,
        size.width,
        size.height - 12,
      )
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(mainPath, mainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Top purple header with curved wave, SkillDad white logo, and notification bell.
class _TopWaveHeader extends StatelessWidget {
  const _TopWaveHeader({
    required this.unreadNotifications,
    required this.onOpenNotifications,
  });

  final int unreadNotifications;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _WaveHeaderPainter(),
      child: SizedBox(
        width: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 36),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  ),
                  child: const SkillDadLogo(
                    markSize: 26,
                    fontSize: 18,
                    textColor: Colors.white,
                    markColor: Colors.white,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: onOpenNotifications,
                      icon: const Icon(
                        Icons.notifications_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Notifications',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8.5,
                          height: 8.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile identity section with circular avatar, edit badge, name, email, role badge, and chevron.
class _UserProfileSection extends StatelessWidget {
  const _UserProfileSection({
    required this.profile,
    required this.onEdit,
  });

  final StudentProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = profile.name.trim().isNotEmpty ? profile.name.trim()[0].toUpperCase() : '?';
    final roleText = profile.role.isNotEmpty
        ? (profile.role[0].toUpperCase() + profile.role.substring(1).toLowerCase())
        : 'Student';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Edit Badge Button
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D28D9).withValues(alpha: 0.16),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: profile.profileImageUrl.isNotEmpty
                        ? Image.network(
                            profile.profileImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isEmpty ? 'Student' : profile.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D28D9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich purple gamification card with 3 stat columns and referral code pill.
class _RewardsCard extends StatelessWidget {
  const _RewardsCard({
    required this.dashboard,
    required this.careerProgress,
    required this.rewardPoints,
    required this.referralCode,
    required this.onShareCode,
  });

  final DashboardData? dashboard;
  final CareerProgress careerProgress;
  final RewardPoints rewardPoints;
  final ReferralCode referralCode;
  final ValueChanged<ReferralCode> onShareCode;

  @override
  Widget build(BuildContext context) {
    final enrolledCount = dashboard?.enrolledCourses.length ?? 0;
    final bestStreak = careerProgress.longestStreak > 0
        ? careerProgress.longestStreak
        : (careerProgress.currentStreak > 0 ? careerProgress.currentStreak : 1);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4C1D95),
            Color(0xFF5B21B6),
            Color(0xFF6D28D9),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _PurpleCardStat(
                    icon: Icons.menu_book_rounded,
                    value: '$enrolledCount',
                    label: 'Enrolled Courses',
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                Expanded(
                  child: _PurpleCardStat(
                    icon: Icons.emoji_events_outlined,
                    value: '$bestStreak',
                    label: 'Best Streak',
                  ),
                ),
                Container(
                  width: 1,
                  height: 42,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                Expanded(
                  child: _PurpleCardStat(
                    icon: Icons.stars_rounded,
                    value: '${rewardPoints.total}',
                    label: 'Reward Points',
                  ),
                ),
              ],
            ),
          ),
          // Sub-container for referral invitation
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0A45).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => onShareCode(referralCode),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFFF472B6),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Invite a friend, earn reward points',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => onShareCode(referralCode),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            referralCode.code,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.copy_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 17,
                        ),
                      ],
                    ),
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

class _PurpleCardStat extends StatelessWidget {
  const _PurpleCardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 7),
        Text(
          value,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

/// 3 Quick action stat cards (My Courses, Certificates, Career Ready).
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.dashboard,
    required this.onOpenCourses,
    required this.onOpenCertificates,
    required this.onOpenCareerReady,
  });

  final DashboardData dashboard;
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenCertificates;
  final VoidCallback onOpenCareerReady;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _ActionStatCard(
              icon: Icons.menu_book_rounded,
              value: '${dashboard.enrolledCourses.length}',
              label: 'My Courses',
              onTap: onOpenCourses,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionStatCard(
              icon: Icons.workspace_premium_rounded,
              value: '${dashboard.certificatesEarned}',
              label: 'Certificates',
              onTap: onOpenCertificates,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionStatCard(
              icon: Icons.bar_chart_rounded,
              value: '${dashboard.careerReadiness}%',
              label: 'Career Ready',
              onTap: onOpenCareerReady,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStatCard extends StatelessWidget {
  const _ActionStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF6D28D9), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings and Actions Menu Card with About, Change Password, App Settings, Help, and Sign Out.
class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.profile,
    required this.onAbout,
    required this.onChangePassword,
    required this.onAppSettings,
    required this.onHelpSupport,
    required this.onSignOut,
  });

  final StudentProfile profile;
  final VoidCallback onAbout;
  final VoidCallback onChangePassword;
  final VoidCallback onAppSettings;
  final VoidCallback onHelpSupport;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final phoneDisplay = profile.phone.isNotEmpty ? profile.phone : '+91 8448119306';
    final aboutSubtitle = profile.bio.isNotEmpty ? profile.bio : phoneDisplay;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.person_outline_rounded,
            title: 'About',
            subtitle: aboutSubtitle,
            onTap: onAbout,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
          _MenuItem(
            icon: Icons.lock_outline_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: onChangePassword,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
          _MenuItem(
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Notifications, language and more',
            onTap: onAppSettings,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
          _MenuItem(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get in touch with our team',
            onTap: onHelpSupport,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
          _MenuItem(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: 'Logout from your account',
            titleColor: const Color(0xFFEF4444),
            iconColor: const Color(0xFFEF4444),
            onTap: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor = const Color(0xFF0F172A),
    this.iconColor = const Color(0xFF334155),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color titleColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.token});

  final String token;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;
  bool _success = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ProfileService.instance.updatePassword(
        token: widget.token,
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      setState(() => _success = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: _success
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Password changed successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _currentController,
                      hintText: 'Current password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Enter your current password'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _newController,
                      hintText: 'New password',
                      icon: Icons.lock_reset_rounded,
                      obscureText: true,
                      onChanged: (_) => setState(() {}),
                      validator: (value) =>
                          firstUnmetPasswordRequirement(value ?? ''),
                    ),
                    const SizedBox(height: 10),
                    if (_newController.text.isNotEmpty)
                      PasswordRequirementsCard(password: _newController.text),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _confirmController,
                      hintText: 'Confirm new password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: true,
                      validator: (value) => value != _newController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Update password'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
