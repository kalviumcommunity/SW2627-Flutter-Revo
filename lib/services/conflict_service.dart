import '../core/errors/revo_exception.dart';

/// Shared scheduling rules used by every conflict-checking implementation.
class ConflictDetectionRules {
  static bool intervalsOverlap({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  static void validateInterval({
    required DateTime startAt,
    required DateTime endAt,
  }) {
    if (!startAt.isBefore(endAt)) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Rehearsal end time must be after start time.',
      );
    }
  }
}

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
