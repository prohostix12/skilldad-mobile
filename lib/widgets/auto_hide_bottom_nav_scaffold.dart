import 'dart:async';

import 'package:flutter/material.dart';

/// A [Scaffold] whose bottom nav bar shows itself on any touch and hides
/// again after 3 seconds of inactivity, instead of permanently occupying
/// screen space or being missing entirely on secondary screens.
class AutoHideBottomNavScaffold extends StatefulWidget {
  const AutoHideBottomNavScaffold({
    super.key,
    required this.body,
    required this.bottomNav,
    this.backgroundColor,
  });

  final Widget body;
  final Widget bottomNav;
  final Color? backgroundColor;

  @override
  State<AutoHideBottomNavScaffold> createState() => _AutoHideBottomNavScaffoldState();
}

class _AutoHideBottomNavScaffoldState extends State<AutoHideBottomNavScaffold> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _showBar() {
    if (!_visible) setState(() => _visible = true);
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      // A Listener (rather than a GestureDetector) never enters the gesture
      // arena, so it doesn't compete with taps on buttons/cards inside body.
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _showBar(),
        child: Stack(
          children: [
            Positioned.fill(child: widget.body),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                offset: _visible ? Offset.zero : const Offset(0, 1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _visible ? 1 : 0,
                  child: widget.bottomNav,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
