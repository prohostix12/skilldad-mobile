import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

import 'skilldad_video_player.dart';

@JS('JSON.stringify')
external JSString _jsStringify(JSAny? obj);

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
  return _SkillDadVideoPlayerWeb(
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

class _SkillDadVideoPlayerWeb extends StatefulWidget {
  const _SkillDadVideoPlayerWeb({
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
  State<_SkillDadVideoPlayerWeb> createState() => _SkillDadVideoPlayerWebState();
}

class _SkillDadVideoPlayerWebState extends State<_SkillDadVideoPlayerWeb>
    with AutomaticKeepAliveClientMixin<_SkillDadVideoPlayerWeb> {
  late final String _videoId;
  late final String _viewId;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _messageEventListener;
  bool _started = false;
  bool _isPlaying = false;
  bool _hasStartedPlaying = false;
  bool _isMuted = false;
  double _currentTime = 0;
  double _duration = 0;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  Timer? _pollTimer;
  String _selectedQuality = 'auto';
  List<String> _availableQualities = const ['auto', 'hd1080', 'hd720', 'large', 'medium', 'small'];

  static final Map<String, double> _cachedPositions = {};
  static final Map<String, bool> _cachedPlaying = {};

  @override
  void initState() {
    super.initState();
    _videoId = SkillDadVideoPlayer.extractVideoId(widget.url) ?? '';
    _viewId = 'sd-yt-${_videoId.isEmpty ? widget.url.hashCode : _videoId}-${DateTime.now().microsecondsSinceEpoch}';
    final lastTime = _cachedPositions[_videoId] ?? 0.0;
    if (lastTime > 0) {
      _currentTime = lastTime;
      _hasStartedPlaying = true;
    }
    _started = widget.autoPlay || (_cachedPlaying[_videoId] ?? false);
    _isPlaying = widget.autoPlay || (_cachedPlaying[_videoId] ?? false);

    if (_videoId.isNotEmpty && _started) {
      _registerIframe();
      _listenToMessages();
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _SkillDadVideoPlayerWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFullScreen != widget.isFullScreen) {
      // Keep playing seamlessly from current position when toggling fullscreen
      final savedTime = _cachedPositions[_videoId] ?? _currentTime;
      final wasPlaying = _cachedPlaying[_videoId] ?? _isPlaying;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          if (savedTime > 0) {
            _sendCommand('seekTo', [savedTime, true]);
          }
          if (wasPlaying) {
            _sendCommand('playVideo');
          }
        } catch (_) {}
      });
      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        try {
          if (wasPlaying && !_isPlaying) {
            if (savedTime > 0 && (_currentTime == 0 || _currentTime < savedTime - 2)) {
              _sendCommand('seekTo', [savedTime, true]);
            }
            _sendCommand('playVideo');
          }
        } catch (_) {}
      });
    }
  }

  void _registerIframe() {
    final origin = web.window.location.origin;
    final savedTime = (_cachedPositions[_videoId] ?? _currentTime).round();
    final startParam = savedTime > 0 ? '&start=$savedTime' : '';
    final embedUrl =
        'https://www.youtube-nocookie.com/embed/$_videoId?autoplay=1&controls=0&disablekb=1&modestbranding=1&rel=0&iv_load_policy=3&fs=0&playsinline=1&enablejsapi=1&origin=$origin$startParam';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..id = _viewId
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'none' // Intercept layer handles clicks to avoid YT redirects
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      _iframe = iframe;
      iframe.onLoad.listen((_) {
        _sendListening();
      });
      return iframe;
    });

    if (widget.autoPlay) {
      _scheduleHideControls();
    }
  }

  void _listenToMessages() {
    // Listen to YouTube player status postMessages from the iframe
    _messageEventListener = ((web.MessageEvent event) {
      if (!mounted) return;
      try {
        final data = event.data;
        if (data == null) return;
        String? messageStr;
        if (data.typeofEquals('string')) {
          messageStr = (data as JSString).toDart;
        } else {
          try {
            messageStr = _jsStringify(data).toDart;
          } catch (_) {}
        }
        if (messageStr == null || !messageStr.contains('infoDelivery')) return;

        final decoded = jsonDecode(messageStr);
        if (decoded is! Map<String, dynamic>) return;
        final info = decoded['info'];
        if (info is! Map<String, dynamic>) return;

        final state = info['playerState'];
        final cur = info['currentTime'];
        final dur = info['duration'];
        final quality = info['playbackQuality'];
        final qualities = info['availableQualityLevels'];

        if (mounted) {
          setState(() {
            if (cur is num) {
              _currentTime = cur.toDouble();
              if (_currentTime > 0) {
                _cachedPositions[_videoId] = _currentTime;
              }
            }
            if (dur is num && dur > 0) _duration = dur.toDouble();
            if (quality is String && quality.isNotEmpty) {
              _selectedQuality = quality;
            }
            if (qualities is List && qualities.isNotEmpty) {
              final parsed = qualities.map((e) => e.toString()).toList();
              if (!parsed.contains('auto')) parsed.insert(0, 'auto');
              _availableQualities = parsed;
            }
            if (state == 1) {
              _isPlaying = true;
              _hasStartedPlaying = true;
              _cachedPlaying[_videoId] = true;
            } else if (state == 2) {
              _isPlaying = false;
              _cachedPlaying[_videoId] = false;
            } else if (state == 0) {
              _isPlaying = false;
              _cachedPlaying[_videoId] = false;
              widget.onEnded?.call();
            }
          });
        }
      } catch (_) {}
    }).toJS;

    web.window.addEventListener('message', _messageEventListener!);

    // Periodically poll player time & keep state sync active
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (_isPlaying) {
        if (_duration > 0 && _currentTime < _duration) {
          setState(() {
            _currentTime = (_currentTime + 0.5).clamp(0.0, _duration);
          });
        }
        _sendListening();
        _sendCommand('getCurrentTime');
        if (_duration == 0) {
          _sendCommand('getDuration');
        }
      }
    });
  }

  web.HTMLIFrameElement? get _targetIframe {
    if (_iframe != null && _iframe!.contentWindow != null) {
      return _iframe;
    }
    final byId = web.document.getElementById(_viewId);
    if (byId != null && byId.isA<web.HTMLIFrameElement>()) {
      _iframe = byId as web.HTMLIFrameElement;
      return _iframe;
    }
    try {
      final iframes = web.document.querySelectorAll('iframe');
      for (var i = 0; i < iframes.length; i++) {
        final item = iframes.item(i);
        if (item != null && item.isA<web.HTMLIFrameElement>()) {
          final frame = item as web.HTMLIFrameElement;
          if (frame.id == _viewId || (_videoId.isNotEmpty && frame.src.contains(_videoId))) {
            _iframe = frame;
            return frame;
          }
        }
      }
    } catch (_) {}
    return _iframe;
  }

  void _sendListening() {
    final frame = _targetIframe;
    if (frame == null || frame.contentWindow == null) return;
    try {
      final payload = jsonEncode({'event': 'listening'});
      frame.contentWindow!.postMessage(payload.toJS, '*'.toJS);
    } catch (_) {}
  }

  void _sendCommand(String func, [List<dynamic>? args]) {
    final frame = _targetIframe;
    if (frame == null || frame.contentWindow == null) return;
    try {
      final payload = jsonEncode({
        'event': 'command',
        'func': func,
        'args': args ?? const <dynamic>[],
      });
      frame.contentWindow!.postMessage(payload.toJS, '*'.toJS);
    } catch (_) {}
  }

  void _startPlayback() {
    if (!_started) {
      _started = true;
      _registerIframe();
      _listenToMessages();
    }
    setState(() {
      _started = true;
      _isPlaying = true;
    });
    _sendListening();
    _sendCommand('playVideo');
    _scheduleHideControls();
  }

  void _togglePlayPause() {
    _onInteraction();
    if (!_started) {
      _startPlayback();
      return;
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _sendCommand('playVideo');
      _scheduleHideControls();
    } else {
      _sendCommand('pauseVideo');
      _hideControlsTimer?.cancel();
    }
  }

  void _seekTo(double seconds) {
    _onInteraction();
    setState(() => _currentTime = seconds);
    _sendCommand('seekTo', [seconds, true]);
    _scheduleHideControls();
  }

  void _toggleMute() {
    _onInteraction();
    setState(() => _isMuted = !_isMuted);
    _sendCommand(_isMuted ? 'mute' : 'unMute');
    _scheduleHideControls();
  }

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
    final currentPos = _currentTime;

    // Send direct API commands to YouTube iframe
    _sendCommand('setPlaybackQuality', [quality]);
    _sendCommand('setPlaybackQualityRange', [quality, quality]);

    // Re-cue/reload with specific quality if user changes resolution so YouTube adapts immediately
    if (quality != 'auto') {
      _sendCommand('loadVideoById', [
        {
          'videoId': _videoId,
          'startSeconds': currentPos.floor(),
          'suggestedQuality': quality,
        }
      ]);
      // Also seek to ensure smooth continuity
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _sendCommand('seekTo', [currentPos, true]);
          if (_isPlaying) _sendCommand('playVideo');
        }
      });
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
        final options = _availableQualities.isNotEmpty
            ? _availableQualities
            : const ['auto', 'hd1080', 'hd720', 'large', 'medium', 'small'];

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
                  ...options.map((q) {
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

  void _toggleFullscreen() {
    _onInteraction();
    if (widget.onToggleFullscreen != null) {
      widget.onToggleFullscreen!();
      return;
    }
    try {
      if (web.document.fullscreenElement == null) {
        web.document.documentElement?.requestFullscreen();
      } else {
        web.document.exitFullscreen();
      }
    } catch (_) {}
  }

  void _onInteraction() {
    setState(() => _showControls = true);
    if (_isPlaying) {
      _scheduleHideControls();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _formatTime(double sec) {
    if (sec.isNaN || sec < 0) return '0:00';
    final total = sec.round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _pollTimer?.cancel();
    if (_messageEventListener != null) {
      web.window.removeEventListener('message', _messageEventListener!);
    }
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
            // (Only mounted into DOM once started=true, exactly matching website's CustomYoutubePlayer)
            if (_videoId.isNotEmpty && _started)
              Positioned.fill(
                child: Transform.scale(
                  scale: 1.48,
                  alignment: Alignment.center,
                  child: HtmlElementView(viewType: _viewId),
                ),
              )
            else
              Container(color: Colors.black),


            // 2. Pre-play / Loading Poster Facade (matching website - shields YouTube loading/watermark symbols)
            if (!_hasStartedPlaying)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _startPlayback,
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

                      // 4. Center action: Loading spinner if started initializing, or Website's Purple Play Button (#4B2E83) before start
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
                                  color: const Color(0xFF4B2E83), // Website's brand purple
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




            // 6. Interactive Tap Intercept Layer (toggles play/pause & shows controls)
            if (_started)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

            // 7. Website's Custom Control Skin Layer (single slim row matching CustomYoutubePlayer.jsx)
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
                            // Time Indicator (0:00 / 0:00)
                            Text(
                              '${_formatTime(_currentTime)} / ${_formatTime(_duration)}',
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
                                  value: _duration > 0
                                      ? _currentTime.clamp(0.0, _duration)
                                      : 0.0,
                                  min: 0.0,
                                  max: _duration > 0 ? _duration : 100.0,
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
