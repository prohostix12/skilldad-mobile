import 'package:flutter/material.dart';

import '../services/dashboard_service.dart';
import '../services/profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/auto_hide_bottom_nav_scaffold.dart';
import '../widgets/skilldad_logo.dart';
import 'live_session_player_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// The student's real live-session screen backed by GET /api/sessions.
/// Redesigned to match the SkillDad premium design system:
/// - Header: SKILLDAD Logo + Notification Bell with red badge + Student Circle Avatar
/// - Header Title & Subtitle: "Live Sessions - Interactive sessions, expert guidance..."
/// - Toggle Pill Bar: "Upcoming & Live" (with radio signal icon & count) vs "Recordings"
/// - Redesigned Card: Left date/time block with status pill (LIVE / UPCOMING / RECORDED)
///   + Right content block with Category pill, Topic title, Instructor row, and Action button.
class LiveSessionsScreen extends StatefulWidget {
  const LiveSessionsScreen({super.key, required this.token, this.courses = const []});

  final String token;
  final List<EnrolledCourse> courses;

  @override
  State<LiveSessionsScreen> createState() => _LiveSessionsScreenState();
}

class _LiveSessionsScreenState extends State<LiveSessionsScreen> with SingleTickerProviderStateMixin {
  List<LiveSession>? _sessions;
  StudentProfile? _studentProfile;
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DashboardService.instance.fetchSessions(widget.token),
        ProfileService.instance.fetchMe(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _sessions = results[0] as List<LiveSession>;
        _studentProfile = results[1] as StudentProfile?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sessions. Please try again.';
        _loading = false;
      });
    }
  }

  void _openSessionInApp(BuildContext context, LiveSession session, {bool isRecording = false}) {
    final url = isRecording ? session.recordingPlayUrl : session.meetingLink;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRecording ? 'No recording is available yet.' : 'No join link is available yet for this session.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LiveSessionPlayerScreen(
          session: session,
          token: widget.token,
          videoUrl: url,
          isRecording: isRecording,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSessions = _sessions ?? [];
    final upcomingLive = allSessions.where((s) => !s.isEnded).toList()
      ..sort((a, b) {
        if (a.isLive && !b.isLive) return -1;
        if (!a.isLive && b.isLive) return 1;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });
    final completed = allSessions.where((s) => s.isEnded).toList()
      ..sort((a, b) {
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });

    final profileImage = _studentProfile?.profileImageUrl ?? '';
    final studentName = _studentProfile?.name ?? '';

    return AutoHideBottomNavScaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      bottomNav: AppBottomNav(courses: widget.courses, token: widget.token, currentLabel: 'Sessions'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar: SKILLDAD Logo + Notification Bell + Profile Circle Avatar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  const SkillDadLogo(),
                  const Spacer(),
                  // Notification Bell Icon with Red Dot Badge
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => NotificationsScreen(token: widget.token),
                        ),
                      );
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 24),
                        Positioned(
                          right: 1,
                          top: 1,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2D55),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Profile Circle Avatar
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(token: widget.token),
                        ),
                      );
                      _load();
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: ClipOval(
                        child: profileImage.isNotEmpty
                            ? Image.network(
                                profileImage,
                                width: 35,
                                height: 35,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(studentName),
                              )
                            : _buildInitialAvatar(studentName),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title & Subtitle Section
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Live Sessions',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Interactive sessions, expert guidance and real-time learning.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Toggle Bar (Upcoming & Live vs Recordings)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                labelPadding: EdgeInsets.zero,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF6338F6),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6338F6).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.podcasts_rounded, size: 15),
                            const SizedBox(width: 5),
                            const Text('Upcoming & Live'),
                            if (!_loading && upcomingLive.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${upcomingLive.length}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Tab(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_outline_rounded, size: 15),
                            const SizedBox(width: 5),
                            const Text('Recordings'),
                            if (!_loading && completed.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${completed.length}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab View Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF6338F6)),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6338F6),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSessionList(
                              context: context,
                              sessions: upcomingLive,
                              emptyTitle: 'No Upcoming Live Sessions',
                              emptySubtitle:
                                  'You have no scheduled masterclasses or live lectures right now. New sessions will appear here as soon as they are announced.',
                              isPast: false,
                            ),
                            _buildSessionList(
                              context: context,
                              sessions: completed,
                              emptyTitle: 'No Session Recordings Yet',
                              emptySubtitle:
                                  'Recordings of past live sessions will be available here after sessions conclude and are processed.',
                              isPast: true,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSessionList({
    required BuildContext context,
    required List<LiveSession> sessions,
    required String emptyTitle,
    required String emptySubtitle,
    required bool isPast,
  }) {
    if (sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF6338F6),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          children: [
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF6338F6).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPast ? Icons.video_library_outlined : Icons.calendar_today_rounded,
                  color: const Color(0xFF6338F6),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Center(
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6338F6),
                  side: const BorderSide(color: Color(0xFF6338F6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6338F6),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
        itemCount: sessions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (ctx, index) => _SessionCard(
          session: sessions[index],
          onOpenSession: (session, isRecording) => _openSessionInApp(ctx, session, isRecording: isRecording),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onOpenSession,
  });

  final LiveSession session;
  final void Function(LiveSession session, bool isRecording) onOpenSession;

  @override
  Widget build(BuildContext context) {
    final isLive = session.isLive;
    final isPast = session.isEnded;

    final dateStr = _formatDate(session.startTime);
    final timeStr = _formatTime(session.startTime);
    final rangeStr = _formatTimeRange(session.startTime, session.durationMinutes);

    final categoryText = session.category.isNotEmpty
        ? session.category
        : (session.courseTitle.isNotEmpty ? session.courseTitle : 'Masterclass');

    final instructorName = session.instructorName.isNotEmpty
        ? session.instructorName
        : (session.courseTitle.isNotEmpty ? session.courseTitle : 'SkillDad Faculty');
    final instructorTitle = session.instructorTitle.isNotEmpty
        ? session.instructorTitle
        : 'Senior Faculty';
    final instructorAvatar = session.instructorAvatar;

    return InkWell(
      onTap: () {
        if (isLive) {
          onOpenSession(session, false);
        } else if (isPast && session.hasRecording) {
          onOpenSession(session, true);
        } else if (session.meetingLink.isNotEmpty) {
          onOpenSession(session, false);
        }
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLive ? const Color(0xFFFF2D55).withValues(alpha: 0.3) : const Color(0xFFEEEDF5),
            width: isLive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Category Badge + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      categoryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6338F6),
                      ),
                    ),
                  ),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.white),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  )
                else if (isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('RECORDED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E0FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('UPCOMING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6338F6))),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Topic Title
            Text(
              session.topic,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),

            // Date & Time Row
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$dateStr · $timeStr ($rangeStr)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Instructor & Action Button Row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF6338F6).withValues(alpha: 0.1),
                  backgroundImage: instructorAvatar.isNotEmpty ? NetworkImage(instructorAvatar) : null,
                  child: instructorAvatar.isEmpty
                      ? Text(
                          instructorName.isNotEmpty ? instructorName[0].toUpperCase() : 'F',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6338F6)),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instructorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        instructorTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLive)
                  ElevatedButton.icon(
                    onPressed: () => onOpenSession(session, false),
                    icon: const Icon(Icons.podcasts_rounded, size: 14),
                    label: const Text('Join Live Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      shape: const StadiumBorder(),
                    ),
                  )
                else if (!isPast)
                  OutlinedButton.icon(
                    onPressed: session.meetingLink.isNotEmpty
                        ? () => onOpenSession(session, false)
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reminder set for this session!'), behavior: SnackBarBehavior.floating),
                            );
                          },
                    icon: Icon(session.meetingLink.isNotEmpty ? Icons.videocam_outlined : Icons.calendar_today_outlined, size: 13),
                    label: Text(session.meetingLink.isNotEmpty ? 'Join Meeting' : 'Set Reminder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6338F6),
                      side: const BorderSide(color: Color(0xFF6338F6), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      shape: const StadiumBorder(),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: session.hasRecording ? () => onOpenSession(session, true) : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 15),
                    label: Text(session.hasRecording ? 'Play Recording' : 'No Video'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      side: BorderSide(color: session.hasRecording ? const Color(0xFF10B981) : const Color(0xFFCBD5E1), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 34),
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

  }
}

String _formatDate(DateTime? dt) {
  if (dt == null) return 'TBA';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String _formatTime(DateTime? dt) {
  if (dt == null) return '--:--';
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
}

String _formatTimeRange(DateTime? dt, int? durationMinutes) {
  if (dt == null) return '--:--';
  if (durationMinutes == null || durationMinutes <= 0) return _formatTime(dt);
  final end = dt.add(Duration(minutes: durationMinutes));
  return _formatTime(end);
}
