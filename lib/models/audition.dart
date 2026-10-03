import '../core/enums/revo_enums.dart';

class Audition {
  final String auditionId;
  final String productionId;
  final DateTime startAt;
  final DateTime endAt;
  final String? venueId;
  final List<String> availableRoles;
  final AuditionStatus status;

  Audition({
    required this.auditionId,
    required this.productionId,
    required this.startAt,
    required this.endAt,
    this.venueId,
    required this.availableRoles,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'auditionId': auditionId,
      'productionId': productionId,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'venueId': venueId,
      'availableRoles': availableRoles,
      'status': status.name,
    };
  }

  factory Audition.fromMap(Map<String, dynamic> map, String id) {
    return Audition(
      auditionId: id,
      productionId: map['productionId'] ?? '',
      startAt: DateTime.tryParse(map['startAt'].toString()) ?? DateTime.now(),
      endAt: DateTime.tryParse(map['endAt'].toString()) ?? DateTime.now(),
      venueId: map['venueId'],
      availableRoles: List<String>.from(map['availableRoles'] ?? []),
      status: AuditionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AuditionStatus.open,
      ),
    );
  }
}

class AuditionInput {
  final String productionId;
  final DateTime startAt;
  final DateTime endAt;
  final String? venueId;
  final List<String> availableRoles;

  AuditionInput({
    required this.productionId,
    required this.startAt,
    required this.endAt,
    this.venueId,
    required this.availableRoles,
  });
}
