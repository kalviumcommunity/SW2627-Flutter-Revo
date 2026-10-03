import '../core/enums/revo_enums.dart';

class Rehearsal {
  final String rehearsalId;
  final String productionId;
  final String venueId;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> participantIds;
  final RehearsalStatus status;
  final bool clientPending;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Rehearsal({
    required this.rehearsalId,
    required this.productionId,
    required this.venueId,
    required this.startAt,
    required this.endAt,
    required this.participantIds,
    required this.status,
    required this.clientPending,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'rehearsalId': rehearsalId,
      'productionId': productionId,
      'venueId': venueId,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'participantIds': participantIds,
      'status': status.name,
      'clientPending': clientPending,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Rehearsal.fromMap(Map<String, dynamic> map, String id) {
    return Rehearsal(
      rehearsalId: id,
      productionId: map['productionId'] ?? '',
      venueId: map['venueId'] ?? '',
      startAt: DateTime.tryParse(map['startAt'].toString()) ?? DateTime.now(),
      endAt: DateTime.tryParse(map['endAt'].toString()) ?? DateTime.now(),
      participantIds: List<String>.from(map['participantIds'] ?? []),
      status: RehearsalStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RehearsalStatus.proposed,
      ),
      clientPending: map['clientPending'] ?? false,
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now(),
    );
  }
}
