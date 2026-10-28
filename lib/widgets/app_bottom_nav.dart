import 'package:flutter/material.dart';

import '../screens/jobs_screen.dart';
import '../screens/live_sessions_screen.dart';
import '../screens/my_courses_screen.dart';
import '../screens/profile_screen.dart';
import '../services/dashboard_service.dart';
import '../theme/app_colors.dart';

/// The shared bottom navigation bar used by the dashboard and every screen
/// reachable from it (My Courses, Live Sessions, ...), so the same tabs stay
/// available no matter where the student navigated to.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.courses, required this.token, required this.currentLabel});

  final List<EnrolledCourse> courses;
  final String token;

  /// Which tab to highlight - 'Home', 'Courses', 'Sessions', 'Jobs' or 'Profile'.
  final String currentLabel;

  // The middle slot (index 2) is rendered as a raised floating action
  // button above the bar, matching a premium "FAB-in-navbar" pattern -
  // its icon never changes with the other four's selected/unselected state.
  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.videocam_outlined, 'Sessions'),
    (Icons.menu_book_rounded, 'Courses'),
    (Icons.work_outline_rounded, 'Jobs'),
    (Icons.person_outline_rounded, 'Profile'),
  ];
  static const _raisedIndex = 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: SizedBox(
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < _items.length; i++)
                      Expanded(
                        child: i == _raisedIndex
                            ? const SizedBox.shrink()
                            : _NavIconLabel(
                                icon: _items[i].$1,
                                label: _items[i].$2,
                                selected: _items[i].$2 == currentLabel,
                                onTap: () => _handleTap(context, _items[i].$2),
                              ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: _RaisedNavButton(
                  icon: _items[_raisedIndex].$1,
                  selected: _items[_raisedIndex].$2 == currentLabel,
                  onTap: () => _handleTap(context, _items[_raisedIndex].$2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, String label) {
    if (label == currentLabel) return;
    if (label == 'Home') {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (label == 'Courses') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => MyCoursesScreen(courses: courses, token: token)),
      );
    } else if (label == 'Sessions') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => LiveSessionsScreen(token: token, courses: courses)),
      );
    } else if (label == 'Jobs') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => JobsScreen(token: token, courses: courses)),
      );
    } else if (label == 'Profile') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ProfileScreen(token: token)),
      );
    }
  }
}

class _NavIconLabel extends StatelessWidget {
  const _NavIconLabel({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating circular button that sits raised above the bar, like a FAB
/// built into the nav itself rather than a plain tab - the premium touch
/// the reference design uses for its most-reached-for action.
class _RaisedNavButton extends StatelessWidget {
  const _RaisedNavButton({required this.icon, required this.selected, required this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          border: Border.all(color: AppColors.background, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
