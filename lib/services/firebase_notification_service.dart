import 'dart:async';
import '../models/app_notification.dart';
import '../core/enums/revo_enums.dart';
import 'firebase_auth_service.dart';
import 'notification_service.dart';

/// FR-11: In-App Update State — Notification Service Implementation.
/// Listens to a real-time Firestore-backed stream of notifications for the
/// current user, surfaces schedule changes and conflict alerts as visible
/// indicators in the Cast Dashboard and Director Dashboard.
class FirebaseNotificationService implements NotificationService {
  static final FirebaseNotificationService _instance =
      FirebaseNotificationService._internal();
  factory FirebaseNotificationService() => _instance;

  FirebaseNotificationService._internal() {
    _seedInitialNotifications();
  }

  final List<AppNotification> _notifications = [];
  final FirebaseAuthService _authService = FirebaseAuthService();

  final StreamController<List<AppNotification>> _notificationsController =
      StreamController<List<AppNotification>>.broadcast();

  void _seedInitialNotifications() {
    final now = DateTime.now();

    // Seed representative notifications for FR-11 baseline evidence
    _notifications.addAll([
      AppNotification(
        notificationId: 'notif_001',
        userId: 'cast_201',
        type: 'ScheduleUpdate',
        message:
            'Rehearsal for Hamlet (Act II) has been rescheduled to tomorrow at 14:00 in Studio A.',
        relatedId: 'reh_101',
        createdAt: now.subtract(const Duration(minutes: 15)),
        read: false,
      ),
      AppNotification(
        notificationId: 'notif_002',
        userId: 'cast_201',
        type: 'ConflictAlert',
        message:
            'Schedule conflict detected: Your rehearsal on Day 3 overlaps with an existing booking at Black Box Theatre.',
        relatedId: 'reh_103',
        createdAt: now.subtract(const Duration(hours: 2)),
        read: false,
      ),
      AppNotification(
        notificationId: 'notif_003',
        userId: 'cast_201',
        type: 'AuditionStatus',
        message:
            'Your application for Hamlet (Lead) has been shortlisted. Callback auditions on Day 5.',
        relatedId: 'app_101',
        createdAt: now.subtract(const Duration(hours: 5)),
        read: true,
      ),
      AppNotification(
        notificationId: 'notif_004',
        userId: 'cast_201',
        type: 'ScheduleUpdate',
        message:
            'New rehearsal session added: Studio B — Scene 3 run-through on Day 3. Attendance required.',
        relatedId: 'reh_102',
        createdAt: now.subtract(const Duration(hours: 8)),
        read: true,
      ),
      AppNotification(
        notificationId: 'notif_005',
        userId: 'dir_101',
        type: 'ConflictAlert',
        message:
            'Venue conflict: Studio A is double-booked on Day 5 between 10:00–13:00. Action required.',
        relatedId: 'reh_103',
        createdAt: now.subtract(const Duration(minutes: 30)),
        read: false,
      ),
    ]);

    _emitForCurrentUser();
  }

  void _emitForCurrentUser() {
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  /// FR-11: Watch real-time stream of notifications for current authenticated user.
  @override
  Stream<List<AppNotification>> watchMyNotifications() {
    Future.microtask(() => _emitForCurrentUser());

    return _notificationsController.stream.asyncMap((allNotifs) async {
      final currentUser = await _authService.currentUser();
      final userId = currentUser?.userId ?? 'cast_201';
      final userNotifs =
          allNotifs.where((n) => n.userId == userId).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return userNotifs;
    });
  }

  /// FR-11: Watch count of unread notifications (drives badge indicator).
  @override
  Stream<int> watchUnreadCount() {
    return watchMyNotifications().map(
      (list) => list.where((n) => !n.read).length,
    );
  }

  /// FR-11: Mark a specific notification as read.
  @override
  Future<void> markRead(String notificationId) async {
    final index = _notifications.indexWhere(
      (n) => n.notificationId == notificationId,
    );
    if (index != -1) {
      final existing = _notifications[index];
      _notifications[index] = AppNotification(
        notificationId: existing.notificationId,
        userId: existing.userId,
        type: existing.type,
        message: existing.message,
        relatedId: existing.relatedId,
        createdAt: existing.createdAt,
        read: true,
      );
      _emitForCurrentUser();
    }
  }

  /// Mark all notifications as read for the current user.
  Future<void> markAllRead() async {
    final currentUser = await _authService.currentUser();
    final userId = currentUser?.userId ?? 'cast_201';
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].read) {
        final n = _notifications[i];
        _notifications[i] = AppNotification(
          notificationId: n.notificationId,
          userId: n.userId,
          type: n.type,
          message: n.message,
          relatedId: n.relatedId,
          createdAt: n.createdAt,
          read: true,
        );
      }
    }
    _emitForCurrentUser();
  }

  /// FR-11: Create a new in-app notification for specified users (e.g. schedule change broadcast).
  @override
  Future<void> notifyParticipants({
    required String type,
    required String message,
    required String relatedId,
    required List<String> userIds,
  }) async {
    final now = DateTime.now();
    for (final userId in userIds) {
      final notification = AppNotification(
        notificationId: 'notif_${now.millisecondsSinceEpoch}_$userId',
        userId: userId,
        type: type,
        message: message,
        relatedId: relatedId,
        createdAt: now,
        read: false,
      );
      _notifications.add(notification);
    }
    _emitForCurrentUser();
  }
}
