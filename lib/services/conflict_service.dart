import '../core/errors/revo_exception.dart';

abstract class ConflictService {
  /// Returns every conflict. Empty list = safe to confirm.
  Future<List<Conflict>> check({
    required String venueId,
    required DateTime startAt,
    required DateTime endAt,
    required List<String> participantIds,
    String? excludeRehearsalId, // pass when editing an existing rehearsal
  });
}
