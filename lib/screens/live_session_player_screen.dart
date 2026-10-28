import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';
import '../widgets/discussion_hub.dart';
import '../widgets/in_app_web_embed.dart';
import '../widgets/skilldad_video_player.dart';

/// Plays a live masterclass or recorded session directly inside the app's
/// built-in video stage, eliminating external browser redirects and keeping
/// the student 100% inside the app.
class LiveSessionPlayerScreen extends StatefulWidget {
  const LiveSessionPlayerScreen({
    super.key,
    required this.session,
    required this.token,
    this.initialVideoId,
    this.videoUrl,
    this.isRecording = false,
  });

  final LiveSession session;
  final String token;
  final String? initialVideoId;
  final String? videoUrl;
  final bool isRecording;

  @override
  State<LiveSessionPlayerScreen> createState() => _LiveSessionPlayerScreenState();
}

class _LiveSessionPlayerScreenState extends State<LiveSessionPlayerScreen> with SingleTickerProviderStateMixin {
  String? _videoId;
  YoutubePlayerController? _controller;
  bool _showEmbeddedStream = false;
  bool _isFullScreen = false;
  late TabController _detailTabController;

  @override
  void initState() {
    super.initState();
    _detailTabController = TabController(length: 2, vsync: this);
    final rawUrl = widget.videoUrl ??
        (widget.isRecording ? widget.session.recordingPlayUrl : widget.session.meetingLink);
    _videoId = widget.initialVideoId ?? extractYouTubeVideoId(rawUrl);
    if (_videoId == null && rawUrl.trim().isNotEmpty) {
      _showEmbeddedStream = true;
      if (widget.session.isLive) {
        _isFullScreen = true;
      }
    }
    _initPlayer();
  }

  void _initPlayer() {
    final vid = _videoId;
    if (vid == null || vid.isEmpty) return;

    _controller = YoutubePlayerController(
      initialVideoId: vid,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        isLive: widget.session.isLive,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detailTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLive = widget.session.isLive;
    final isRec = widget.isRecording || widget.session.isEnded;
    final controller = _controller;
    final videoId = _videoId;
    final targetUrl = widget.videoUrl ??
        (widget.isRecording ? widget.session.recordingPlayUrl : widget.session.meetingLink);

    final subtitleParts = [
      if (widget.session.courseTitle.isNotEmpty) widget.session.courseTitle,
      if (widget.session.instructorName.isNotEmpty) widget.session.instructorName,
    ];
    final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join(' · ') : widget.session.category;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Bar
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.session.topic,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isRec)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'RECORDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isFullScreen = !_isFullScreen;
                      });
                    },
                    icon: Icon(
                      _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: _isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                  ),
                ],
              ),
            ),

            // Video / Embedded Live Stream Player Container
            _buildPlayerStage(controller, videoId, targetUrl, isLive),

            // If Full Screen is active, the player stage takes the full screen height
            if (!_isFullScreen) ...[
              // Tab Bar for Overview vs Discussion/Q&A
              Container(
                color: Colors.black,
                child: TabBar(
                  controller: _detailTabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: const TextStyle(fontSize: 12.5),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Q&A & Discussion'),
                  ],
                ),
              ),

              // Session Details & In-App Content TabBarView
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: AppColors.background,
                  child: TabBarView(
                    controller: _detailTabController,
                    children: [
                      // Tab 1: Overview
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isLive
                                            ? Colors.red
                                            : (isRec ? const Color(0xFF10B981) : AppColors.primary))
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    isLive
                                        ? '🔴 Live Class'
                                        : (isRec ? '🟢 Recorded Lecture' : '📅 Scheduled Session'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isLive
                                          ? Colors.red
                                          : (isRec ? const Color(0xFF10B981) : AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (widget.session.startTime != null)
                                  Text(
                                    _formatSessionDateTime(
                                        widget.session.startTime, widget.session.durationMinutes),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            Text(
                              widget.session.topic,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.fieldBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.school_rounded,
                                        color: AppColors.primary, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (widget.session.instructorName.isNotEmpty)
                                          Text(
                                            'Instructor: ${widget.session.instructorName}',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        if (widget.session.courseTitle.isNotEmpty)
                                          Text(
                                            widget.session.courseTitle,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (widget.session.description.isNotEmpty) ...[
                              const Text(
                                'About this session',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.session.description,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Tab 2: Q&A & Discussion Hub
                      SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        child: widget.token.isNotEmpty && widget.session.id.isNotEmpty
                            ? DiscussionHub(
                                courseId: widget.session.courseTitle.isNotEmpty
                                    ? widget.session.courseTitle
                                    : 'live_sessions',
                                videoId: widget.session.id,
                                token: widget.token,
                              )
                            : const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Text('Sign in to participate in the discussion.'),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStage(
    YoutubePlayerController? controller,
    String? videoId,
    String targetUrl,
    bool isLive,
  ) {
    Widget stageContent;

    if (videoId != null && videoId.isNotEmpty) {
      stageContent = SkillDadVideoPlayer(
        url: targetUrl.isNotEmpty ? targetUrl : 'https://www.youtube.com/watch?v=$videoId',
        title: widget.session.topic,
        autoPlay: true,
        isFullScreen: _isFullScreen,
        onToggleFullscreen: () {
          setState(() {
            _isFullScreen = !_isFullScreen;
          });
        },
      );
    } else if (controller != null) {
      stageContent = YoutubePlayer(controller: controller);
    } else if (_showEmbeddedStream && targetUrl.isNotEmpty) {
      stageContent = InAppWebEmbed(url: targetUrl);
    } else {
      stageContent = Container(
        color: const Color(0xFF161329),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isLive ? 'In-App Live Session Room' : 'Live Meeting Room',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                if (targetUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No join link is available yet for this session.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final uri = Uri.tryParse(targetUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                setState(() => _showEmbeddedStream = true);
              },
              icon: const Icon(Icons.videocam_rounded, size: 17),
              label: const Text('Join Classroom'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? const Color(0xFFFF2D55) : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      );
    }

    if (_isFullScreen) {
      return Expanded(
        child: Container(
          width: double.infinity,
          color: Colors.black,
          child: stageContent,
        ),
      );
    } else {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: stageContent,
      );
    }
  }
}

/// Helper that extracts YouTube Video / Stream ID from various URL formats
/// including watch URLs, youtu.be, embed, live, and mobile URLs.
String? extractYouTubeVideoId(String url) {
  if (url.isEmpty) return null;
  final trimmed = url.trim();

  // Try standard converter
  final converted = YoutubePlayer.convertUrlToId(trimmed);
  if (converted != null && converted.isNotEmpty) return converted;

  // Custom regex to match youtube.com/live/<id>, shorts, embed, watch
  final regExp = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|live\/|shorts\/))([\w-]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(trimmed);
  if (match != null && match.groupCount >= 1) {
    return match.group(1);
  }
  return null;
}

String _formatSessionDateTime(DateTime? dt, int? durationMinutes) {
  if (dt == null) return '';
  final now = DateTime.now();
  final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final datePart = isToday ? 'Today' : '${months[dt.month - 1]} ${dt.day}';

  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  final timePart = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';

  return '$datePart · $timePart';
}
