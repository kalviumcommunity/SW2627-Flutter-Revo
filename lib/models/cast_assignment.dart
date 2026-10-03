import '../core/enums/revo_enums.dart';

class CastAssignment {
  final String assignmentId;
  final String productionId;
  final String roleId;
  final String castMemberId;
  final DateTime assignedAt;
  final AssignmentStatus status;

  CastAssignment({
    required this.assignmentId,
    required this.productionId,
    required this.roleId,
    required this.castMemberId,
    required this.assignedAt,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'productionId': productionId,
      'roleId': roleId,
      'castMemberId': castMemberId,
      'assignedAt': assignedAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory CastAssignment.fromMap(Map<String, dynamic> map, String id) {
    return CastAssignment(
      assignmentId: id,
      productionId: map['productionId'] ?? '',
      roleId: map['roleId'] ?? '',
      castMemberId: map['castMemberId'] ?? '',
      assignedAt: DateTime.tryParse(map['assignedAt'].toString()) ?? DateTime.now(),
      status: AssignmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AssignmentStatus.active,
      ),
    );
  }
}
