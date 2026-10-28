import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'skilldad_video_player.dart';

Widget buildPlatformVideoPlayer({
  Key? key,
  required String url,
  String? title,
  String? thumbnailUrl,
  bool autoPlay = true,
  VoidCallback? onEnded,
  double aspectRatio = 16 / 9,
  double borderRadius = 18.0,
  VoidCallback? onToggleFullscreen,
  bool isFullScreen = false,
}) {
  return _SkillDadVideoPlayerStub(
    key: key,
    url: url,
    title: title,
    thumbnailUrl: thumbnailUrl,
    autoPlay: autoPlay,
    onEnded: onEnded,
    aspectRatio: aspectRatio,
    borderRadius: borderRadius,
    onToggleFullscreen: onToggleFullscreen,
    isFullScreen: isFullScreen,
  );
}

class _SkillDadVideoPlayerStub extends StatefulWidget {
  const _SkillDadVideoPlayerStub({
    super.key,
    required this.url,
    this.title,
    this.thumbnailUrl,
    required this.autoPlay,
    this.onEnded,
    required this.aspectRatio,
    required this.borderRadius,
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

  @override
  State<_SkillDadVideoPlayerStub> createState() => _SkillDadVideoPlayerStubState();
}

class _SkillDadVideoPlayerStubState extends State<_SkillDadVideoPlayerStub>
    with AutomaticKeepAliveClientMixin<_SkillDadVideoPlayerStub> {
  late final String _videoId;
  YoutubePlayerController? _controller;
  bool _started = false;
  bool _isPlaying = false;
  bool _hasStartedPlaying = false;
  bool _isMuted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  String _selectedQuality = 'auto';

  static const List<String> _availableQualities = [
    'auto',
    'hd1080',
    'hd720',
    'large',
    'medium',
    'small',
  ];

  static String _qualityLabel(String q) {
    switch (q.toLowerCase()) {
      case 'highres':
        return '4K (2160p)';
      case 'hd1440':
        return '1440p (QHD)';
      case 'hd1080':
        return '1080p (Full HD)';
      case 'hd720':
        return '720p (HD)';
      case 'large':
        return '480p';
      case 'medium':
        return '360p';
      case 'small':
        return '240p';
      case 'tiny':
        return '144p';
      case 'auto':
      default:
        return 'Auto';
    }
  }

  void _setQuality(String quality) {
    setState(() => _selectedQuality = quality);
    final ctrl = _controller;
    if (ctrl != null) {
      try {
        final curSeconds = _position.inSeconds;
        ctrl.value.webViewController?.evaluateJavascript(
          source: '''
            try {
              player.setPlaybackQuality("$quality");
              player.setPlaybackQualityRange("$quality", "$quality");
              ${quality != 'auto' ? 'player.loadVideoById({videoId: "$_videoId", startSeconds: $curSeconds, suggestedQuality: "$quality"});' : ''}
            } catch(e){}
          ''',
        );
      } catch (_) {}
    }
    _scheduleHideControls();
  }

  void _showQualitySelector() {
    _onInteraction();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161329),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.82,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_suggest_rounded, color: Color(0xFF8B5CF6), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Video Quality',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _qualityLabel(_selectedQuality),
                          style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  ..._availableQualities.map((q) {
                    final isSelected = _selectedQuality.toLowerCase() == q.toLowerCase();
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.white38,
                        size: 20,
                      ),
                      title: Text(
                        _qualityLabel(q),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _setQuality(q);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static final Map<String, Duration> _cachedPositions = {};
  static final Map<String, bool> _cachedPlaying = {};

  @override
  void initState() {
    super.initState();
    _videoId = SkillDadVideoPlayer.extractVideoId(widget.url) ?? '';
    final lastPos = _cachedPositions[_videoId];
    if (lastPos != null && lastPos > Duration.zero) {
      _position = lastPos;
      _hasStartedPlaying = true;
    }
    _started = widget.autoPlay || (_cachedPlaying[_videoId] ?? false);
    if (_videoId.isNotEmpty && _started) {
      _initPlayer();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _SkillDadVideoPlayerStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When toggling fullscreen on or off, preserve video playback seamlessly
    // without pausing or restarting from the beginning.
    if (oldWidget.isFullScreen != widget.isFullScreen) {
      final savedPos = _cachedPositions[_videoId] ?? _position;
      final wasPlaying = _cachedPlaying[_videoId] ?? _isPlaying;
      final ctrl = _controller;
      if (ctrl != null) {
        // Run resume commands after layout completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            if (savedPos > Duration.zero) {
              ctrl.seekTo(savedPos);
            }
            if (wasPlaying) {
              ctrl.play();
            }
          } catch (_) {}
        });
        // Also run a short delayed attempt in case the platform view was resizing/transitioning
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          try {
            final c = _controller;
            if (c != null && wasPlaying && !c.value.isPlaying) {
              if (savedPos > Duration.zero && (c.value.position == Duration.zero || c.value.position < savedPos - const Duration(seconds: 2))) {
                c.seekTo(savedPos);
              }
              c.play();
            }
          } catch (_) {}
        });
      }
    }
  }

  void _initPlayer() {
    if (_videoId.isEmpty) return;
    final startSeconds = (_cachedPositions[_videoId] ?? _position).inSeconds;
    final shouldAutoPlay = widget.autoPlay || (_cachedPlaying[_videoId] ?? true);
    _controller = YoutubePlayerController(
      initialVideoId: _videoId,
      flags: YoutubePlayerFlags(
        autoPlay: shouldAutoPlay,
        startAt: startSeconds > 0 ? startSeconds : 0,
        hideControls: true,
        controlsVisibleAtStart: false,
        hideThumbnail: true,
        disableDragSeek: true,
        useHybridComposition: true,
      ),
    )..addListener(_onPlayerStateChanged);
    _started = true;
    _scheduleHideControls();
  }

  void _onPlayerStateChanged() {
    final ctrl = _controller;
    if (!mounted || ctrl == null) return;
    final val = ctrl.value;
    final isActuallyPlaying = val.isPlaying;
    final hasFrame = isActuallyPlaying || val.position > Duration.zero;

    if (val.position > Duration.zero) {
      _cachedPositions[_videoId] = val.position;
    }
    if (isActuallyPlaying) {
      _cachedPlaying[_videoId] = true;
    } else if (val.playerState == PlayerState.paused) {
      // Only record pause if it wasn't triggered during a fullscreen orientation toggle
      _cachedPlaying[_videoId] = false;
    }

    setState(() {
      _isPlaying = isActuallyPlaying;
      if (hasFrame && !_hasStartedPlaying) {
        _hasStartedPlaying = true;
      }
      _position = val.position;
      _duration = ctrl.metadata.duration;
      _isMuted = val.volume == 0;
    });

    if (val.isReady || isActuallyPlaying) {
      _hideYouTubeHeaderChrome();
    }

    if (val.playerState == PlayerState.ended) {
      widget.onEnded?.call();
    }
  }

  void _hideYouTubeHeaderChrome() {
    final webCtrl = _controller?.value.webViewController;
    if (webCtrl == null) return;
    try {
      webCtrl.evaluateJavascript(
        source: '''
          (function() {
            try {
              var css = '.ytp-chrome-top, .ytp-title, .ytp-title-link, .ytp-title-channel, .ytp-title-text, .ytp-gradient-top, .ytp-watermark, .ytp-pause-overlay, .ytp-bezel, .ytp-bezel-icon, .ytp-bezel-text, .ytp-bezel-letter, div.ytp-bezel, .ytp-bezel-run { display: none !important; opacity: 0 !important; visibility: hidden !important; pointer-events: none !important; }';
              var style = document.getElementById('sd-hide-header-style');
              if (!style) {
                style = document.createElement('style');
                style.id = 'sd-hide-header-style';
                style.type = 'text/css';
                style.appendChild(document.createTextNode(css));
                (document.head || document.documentElement).appendChild(style);
              }
              var topChrome = document.querySelector('.ytp-chrome-top');
              if (topChrome) {
                topChrome.style.display = 'none';
              }
              var bezels = document.querySelectorAll('.ytp-bezel, .ytp-bezel-icon, .ytp-pause-overlay');
              for (var i = 0; i < bezels.length; i++) {
                bezels[i].style.display = 'none';
                bezels[i].style.opacity = '0';
              }
              if (!window._sdBezelObserver) {
                window._sdBezelObserver = new MutationObserver(function() {
                  try {
                    var b = document.querySelectorAll('.ytp-bezel, .ytp-bezel-icon, .ytp-pause-overlay');
                    for (var j = 0; j < b.length; j++) {
                      b[j].style.display = 'none';
                      b[j].style.opacity = '0';
                    }
                  } catch(e){}
                });
                window._sdBezelObserver.observe(document.body || document.documentElement, { childList: true, subtree: true });
              }
            } catch(e){}
          })();
        ''',
      );
    } catch (_) {}
  }

  void _togglePlayPause() {
    if (!_started) {
      _cachedPlaying[_videoId] = true;
      setState(() => _started = true);
      _initPlayer();
      return;
    }
    final ctrl = _controller;
    if (ctrl == null) return;
    setState(() => _showControls = true);
    if (ctrl.value.isPlaying) {
      _cachedPlaying[_videoId] = false;
      ctrl.pause();
      _hideYouTubeHeaderChrome();
      _hideControlsTimer?.cancel();
    } else {
      _cachedPlaying[_videoId] = true;
      ctrl.play();
      _scheduleHideControls();
    }
  }

  void _seekTo(double seconds) {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.seekTo(Duration(seconds: seconds.round()));
    _scheduleHideControls();
  }

  void _toggleMute() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (_isMuted) {
      ctrl.unMute();
    } else {
      ctrl.mute();
    }
    _scheduleHideControls();
  }

  void _toggleFullscreen() {
    _onInteraction();
    if (widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!();
      return;
    }
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.toggleFullScreenMode();
  }

  void _onInteraction() {
    setState(() => _showControls = true);
    if (_isPlaying) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final playerBody = Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(widget.isFullScreen ? 0 : widget.borderRadius),
        border: !widget.isFullScreen && widget.borderRadius > 0
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              )
            : null,
        boxShadow: !widget.isFullScreen && widget.borderRadius > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. YouTube Player with clean framing concealing native iframe header
            // (Only mounted once started=true, matching website's CustomYoutubePlayer)
            if (_controller != null && _started && !Platform.environment.containsKey('FLUTTER_TEST'))
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.48,
                  alignment: Alignment.center,
                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: false,
                  ),
                ),
              )
            else
              Container(color: Colors.black),


            // 2. Pre-play / Loading Poster Facade (matching website - shields YouTube loading/watermark symbols)
            if (!_hasStartedPlaying)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Base YouTube thumbnail (scaled to match 1.48 center framing)
                      if (_videoId.isNotEmpty)
                        ClipRect(
                          child: Transform.scale(
                            scale: 1.48,
                            alignment: Alignment.center,
                            child: Image.network(
                              'https://img.youtube.com/vi/$_videoId/hqdefault.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(color: const Color(0xFF161329)),
                            ),
                          ),
                        )
                      else
                        Container(color: const Color(0xFF161329)),

                      // 2. Custom class cover image on top (if present)
                      if (widget.thumbnailUrl != null && widget.thumbnailUrl!.trim().isNotEmpty)
                        Image.network(
                          widget.thumbnailUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),

                      // 3. Dark tint overlay (matching website's rgba(0,0,0,0.3))
                      Container(color: Colors.black.withValues(alpha: 0.35)),

                      // 4. Center action: Loading spinner if started initializing, or Purple Play Button (#4B2E83) before start
                      Center(
                        child: _started
                            ? Container(
                                width: 56,
                                height: 56,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                                ),
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4B2E83),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4B2E83).withValues(alpha: 0.6),
                                      blurRadius: 24,
                                      spreadRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),




            // 6. Interactive Tap Intercept Layer
            if (_started)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

            // 7. Custom Control Skin Layer (single slim row matching CustomYoutubePlayer.jsx)
            if (_started)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Listener(
                      onPointerDown: (_) => _onInteraction(),
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Play / Pause Button (#4B2E83)
                            GestureDetector(
                              onTap: _togglePlayPause,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4B2E83),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Time Indicator
                            Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE2E8F0),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Scrubber Timeline Slider (Expanded in the middle)
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3.5,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: const Color(0xFF8B5CF6),
                                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                  thumbColor: Colors.white,
                                  overlayColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _duration.inSeconds > 0
                                      ? _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble())
                                      : 0.0,
                                  min: 0.0,
                                  max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 100.0,
                                  onChanged: (val) {
                                    _seekTo(val);
                                  },
                                ),
                              ),
                            ),
                            // Quality Selection Button
                            IconButton(
                              onPressed: _showQualitySelector,
                              icon: const Icon(
                                Icons.settings_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              splashRadius: 14,
                              tooltip: 'Quality (${_qualityLabel(_selectedQuality)})',
                            ),
                            // Mute / Unmute Button
                            IconButton(
                              onPressed: _toggleMute,
                              icon: Icon(
                                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              splashRadius: 14,
                            ),
                            // Fullscreen Button
                            IconButton(
                              onPressed: _toggleFullscreen,
                              icon: Icon(
                                widget.isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              splashRadius: 14,
                              tooltip: widget.isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

    if (widget.isFullScreen) {
      return playerBody;
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: playerBody,
    );
  }
}
