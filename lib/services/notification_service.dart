import '../models/app_notification.dart';

abstract class NotificationService {
  Stream<List<AppNotification>> watchMyNotifications();
  Stream<int> watchUnreadCount();
  Future<void> markRead(String notificationId);
  Future<void> notifyParticipants({
    required String type,
    required String message,
    required String relatedId,
    required List<String> userIds,
  });
}
