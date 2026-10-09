import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/firebase_notification_service.dart';

/// FR-11: In-App Notifications Screen.
/// Displays all real-time schedule updates, conflict alerts, and audition status
/// notifications for the authenticated cast member or director. Supports mark-as-read
/// with an amber badge for unread items and a "Mark all read" action.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifService = FirebaseNotificationService();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF171B26),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Mark all read'),
            onPressed: () async {
              await notifService.markAllRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notifService.watchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF8C95A8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule updates and alerts will appear here.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF8C95A8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return _NotificationCard(
                notification: notif,
                onMarkRead: () => notifService.markRead(notif.notificationId),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onMarkRead;

  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;
    final typeConfig = _notifTypeConfig(notification.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isUnread ? typeConfig.surfaceColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isUnread ? typeConfig.accentColor : Colors.transparent,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF171B26).withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: isUnread ? onMarkRead : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: typeConfig.accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeConfig.icon,
                  color: typeConfig.accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeConfig.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            typeConfig.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: typeConfig.accentColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeConfig.accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.w400,
                        color: const Color(0xFF171B26),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8C95A8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onMarkRead,
                        child: Text(
                          'Tap to mark as read',
                          style: TextStyle(
                            fontSize: 11,
                            color: typeConfig.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  _NotifTypeConfig _notifTypeConfig(String type) {
    switch (type) {
      case 'ConflictAlert':
        return _NotifTypeConfig(
          label: 'CONFLICT',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFF2B33D),
          surfaceColor: const Color(0xFFFEF8EC),
        );
      case 'AuditionStatus':
        return _NotifTypeConfig(
          label: 'AUDITION',
          icon: Icons.how_to_reg_outlined,
          accentColor: const Color(0xFF3FA672),
          surfaceColor: const Color(0xFFEBF7F1),
        );
      case 'ScheduleUpdate':
      default:
        return _NotifTypeConfig(
          label: 'SCHEDULE',
          icon: Icons.event_note_outlined,
          accentColor: const Color(0xFF3B4A9A),
          surfaceColor: const Color(0xFFEEF1FB),
        );
    }
  }
}

class _NotifTypeConfig {
  final String label;
  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;

  const _NotifTypeConfig({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
  });
}
