import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// The real notifications list - GET /api/notifications/my and
/// PUT /api/notifications/read (server/routes/notificationRoutes.js),
/// matching the website's notification bell dropdown
/// (client/src/components/layout/DashboardNavbar.jsx).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.token});

  final String token;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _notifications;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifications = await NotificationService.instance.fetchMyNotifications(widget.token);
    if (!mounted) return;
    setState(() => _notifications = notifications);
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAllRead = true);
    final success = await NotificationService.instance.markAllRead(widget.token);
    if (!mounted) return;
    setState(() {
      _markingAllRead = false;
      if (success) {
        _notifications = _notifications
            ?.map(
              (n) => AppNotification(
                id: n.id,
                type: n.type,
                rawMessage: n.rawMessage,
                metadata: n.metadata,
                createdAt: n.createdAt,
                isRead: true,
              ),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    final unreadCount = notifications?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.textPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.fieldBorder),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markingAllRead ? null : _markAllRead,
                      child: _markingAllRead
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Mark all read', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: notifications == null
                  ? const Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No new notifications',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _NotificationTile(notification: notifications[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notification.isRead ? AppColors.surface : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notification.isRead ? AppColors.fieldBorder : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            )
          else
            const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  _relativeTime(notification.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
