import '../core/enums/revo_enums.dart';

class Application {
  final String applicationId;
  final String auditionId;
  final String castMemberId;
  final ApplicationStatus status;
  final DateTime submittedAt;

  Application({
    required this.applicationId,
    required this.auditionId,
    required this.castMemberId,
    required this.status,
    required this.submittedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'auditionId': auditionId,
      'castMemberId': castMemberId,
      'status': status.name,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }

  factory Application.fromMap(Map<String, dynamic> map, String id) {
    return Application(
      applicationId: id,
      auditionId: map['auditionId'] ?? '',
      castMemberId: map['castMemberId'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ApplicationStatus.submitted,
      ),
      submittedAt: DateTime.tryParse(map['submittedAt'].toString()) ?? DateTime.now(),
    );
  }
}
