class AppNotification {
  final String notificationId;
  final String userId;
  final String type;
  final String message;
  final String relatedId;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.message,
    required this.relatedId,
    required this.createdAt,
    required this.read,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'type': type,
      'message': message,
      'relatedId': relatedId,
      'createdAt': createdAt.toIso8601String(),
      'read': read,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    return AppNotification(
      notificationId: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      message: map['message'] ?? '',
      relatedId: map['relatedId'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
      read: map['read'] ?? false,
    );
  }
}
