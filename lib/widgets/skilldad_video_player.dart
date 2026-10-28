import 'package:flutter/material.dart';

import 'skilldad_video_player_stub.dart'
    if (dart.library.js_interop) 'skilldad_video_player_web.dart';

/// SkillDad custom video player matching the website's `CustomYoutubePlayer.jsx`.
///
/// Features:
/// 1. Zoom-in effect (`scale(1.34)` centered in a clipped container) that crops out
///    the YouTube icon, watermark, channel header, and share buttons.
/// 2. Top and bottom dark gradient edge masks to prevent any chrome leakage.
/// 3. Modern container styling: rounded corners (18px), subtle glass border,
///    deep elevation shadow, and 16:9 aspect ratio.
/// 4. Pre-play poster facade with high-res thumbnail, dark tint, and SkillDad
///    signature purple play button (#4B2E83) with white icon and glow.
/// 5. Custom controls skin with purple play/pause button, time indicator,
///    timeline scrubber, mute/volume button, and fullscreen mode.
class SkillDadVideoPlayer extends StatefulWidget {
  const SkillDadVideoPlayer({
    super.key,
    required this.url,
    this.title,
    this.thumbnailUrl,
    this.autoPlay = true,
    this.onEnded,
    this.aspectRatio = 16 / 9,
    this.borderRadius = 18.0,
    this.onToggleFullscreen,
    this.isFullScreen = false,
  });

  final String url;
  final String? title;
  final String? thumbnailUrl;
  final bool autoPlay;
  final VoidCallback? onEnded;
  final double aspectRatio;
  final double borderRadius;
  final VoidCallback? onToggleFullscreen;
  final bool isFullScreen;

  /// Helper to extract YouTube ID from any YouTube URL format.
  static String? extractVideoId(String urlStr) {
    if (urlStr.trim().isEmpty) return null;
    final match = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/|youtube-nocookie\.com\/embed\/)([\w-]+)',
    ).firstMatch(urlStr.trim());
    return match?.group(1);
  }

  @override
  State<SkillDadVideoPlayer> createState() => _SkillDadVideoPlayerState();
}

class _SkillDadVideoPlayerState extends State<SkillDadVideoPlayer> {
  @override
  Widget build(BuildContext context) {
    return buildPlatformVideoPlayer(
      url: widget.url,
      title: widget.title,
      thumbnailUrl: widget.thumbnailUrl,
      autoPlay: widget.autoPlay,
      onEnded: widget.onEnded,
      aspectRatio: widget.aspectRatio,
      borderRadius: widget.borderRadius,
      onToggleFullscreen: widget.onToggleFullscreen,
      isFullScreen: widget.isFullScreen,
    );
  }
}
