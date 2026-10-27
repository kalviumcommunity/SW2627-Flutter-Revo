import '../../core/enums/revo_enums.dart';

/// Represents an idempotent pending write operation awaiting server persistence (FR-13).
class PendingWriteOp {
  final String operationId;
  final String entityType;
  final String entityId;
  final String action; // 'create', 'update', 'cancel'
  final Map<String, dynamic> payload;
  WriteSyncStatus status;
  final DateTime createdAt;
  DateTime? lastAttemptAt;
  String? errorMessage;
  int retryCount;

  PendingWriteOp({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    this.status = WriteSyncStatus.pending,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
    this.retryCount = 0,
  });

  bool get isPending => status == WriteSyncStatus.pending;
  bool get isConfirmed => status == WriteSyncStatus.confirmed;
  bool get isFailed => status == WriteSyncStatus.failed;

  PendingWriteOp copyWith({
    String? operationId,
    String? entityType,
    String? entityId,
    String? action,
    Map<String, dynamic>? payload,
    WriteSyncStatus? status,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    String? errorMessage,
    int? retryCount,
  }) {
    return PendingWriteOp(
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      errorMessage: errorMessage ?? this.errorMessage,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'payload': payload,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      if (lastAttemptAt != null) 'lastAttemptAt': lastAttemptAt!.toIso8601String(),
      if (errorMessage != null) 'errorMessage': errorMessage,
      'retryCount': retryCount,
    };
  }

  factory PendingWriteOp.fromMap(Map<String, dynamic> map) {
    return PendingWriteOp(
      operationId: map['operationId'] as String,
      entityType: map['entityType'] as String? ?? 'rehearsal',
      entityId: map['entityId'] as String,
      action: map['action'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      status: WriteSyncStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => WriteSyncStatus.pending,
      ),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastAttemptAt: map['lastAttemptAt'] != null
          ? DateTime.tryParse(map['lastAttemptAt'] as String)
          : null,
      errorMessage: map['errorMessage'] as String?,
      retryCount: map['retryCount'] as int? ?? 0,
    );
  }
}
