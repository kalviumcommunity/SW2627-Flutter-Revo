import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/rehearsal.dart';

class RehearsalInput {
  final String productionId;
  final String venueId;
  final DateTime startAt;
  final DateTime endAt;
  final List<String> participantIds;

  RehearsalInput({
    required this.productionId,
    required this.venueId,
    required this.startAt,
    required this.endAt,
    required this.participantIds,
  });
}

class RehearsalSaveResult {
  final Rehearsal? rehearsal; // set when saved
  final List<Conflict> conflicts; // non-empty = NOT confirmed

  RehearsalSaveResult({
    this.rehearsal,
    this.conflicts = const [],
  });

  bool get confirmed => rehearsal?.status == RehearsalStatus.confirmed;
}

abstract class RehearsalRepository {
  Future<RehearsalSaveResult> createRehearsal(RehearsalInput input);
  Future<RehearsalSaveResult> updateRehearsal(String rehearsalId, RehearsalInput input);
  Future<void> cancelRehearsal(String rehearsalId); // sets status = cancelled (BR-08)
  Future<Rehearsal> getRehearsal(String rehearsalId);
}
