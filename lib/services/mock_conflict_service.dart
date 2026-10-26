import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import 'conflict_service.dart';
import 'mock_data_service.dart';

/// Concrete Mock Implementation of [ConflictService] (FR-05, FR-08, Issue #21).
/// Provides deterministic pre-confirmation interval-overlap collision detection
/// for venues and cast participants against confirmed production schedules.
class MockConflictService implements ConflictService {
  final MockDataService _dataService;

  MockConflictService({MockDataService? dataService})
    : _dataService = dataService ?? MockDataService();

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Checks whether two time intervals overlap.
  /// Standard interval formula: proposedStart < existingEnd && existingStart < proposedEnd.
  /// Adjacent intervals (e.g. 10:00-11:00 and 11:00-12:00) do NOT overlap.
  bool _isOverlapping({
    required DateTime proposedStart,
    required DateTime proposedEnd,
    required DateTime existingStart,
    required DateTime existingEnd,
  }) {
    return ConflictDetectionRules.intervalsOverlap(
      startA: proposedStart,
      endA: proposedEnd,
      startB: existingStart,
      endB: existingEnd,
    );
  }

  /// Friendly convenience alias for check(...) supporting date and time arguments.
  Future<List<Conflict>> checkConflicts({
    required String venueId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    required List<String> participantIds,
    String? productionId,
    String? excludeRehearsalId,
  }) async {
    return check(
      venueId: venueId,
      startAt: startTime,
      endAt: endTime,
      participantIds: participantIds,
      excludeRehearsalId: excludeRehearsalId,
    );
  }

  @override
  Future<List<Conflict>> check({
    required String venueId,
    required DateTime startAt,
    required DateTime endAt,
    required List<String> participantIds,
    String? excludeRehearsalId,
  }) async {
    // Bug 4 fix: Return empty list for invalid intervals instead of throwing.
    // The repository layer calls validateInterval() before check(), so strict
    // validation is still enforced on all confirmed rehearsal paths. Returning
    // [] here prevents partial UI date-picker states from crashing the screen.
    try {
      ConflictDetectionRules.validateInterval(startAt: startAt, endAt: endAt);
    } on RevoException {
      return [];
    }

    final conflicts = <Conflict>[];
    final allRehearsals = _dataService.getAllRehearsals();

    // Only confirmed rehearsals create blocking conflicts (cancelled & proposed are ignored)
    final eligibleRehearsals = allRehearsals.where((r) {
      if (r.status != RehearsalStatus.confirmed) return false;
      if (excludeRehearsalId != null && r.rehearsalId == excludeRehearsalId) {
        return false;
      }
      return true;
    }).toList();

    // ── 1. Check Venue Conflicts ─────────────────────────────────────────────
    for (final rehearsal in eligibleRehearsals) {
      if (rehearsal.venueId == venueId) {
        if (_isOverlapping(
          proposedStart: startAt,
          proposedEnd: endAt,
          existingStart: rehearsal.startAt,
          existingEnd: rehearsal.endAt,
        )) {
          final venue = _dataService.getVenueById(venueId);
          final prod = _dataService.getProductionById(rehearsal.productionId);
          final venueName = venue?.name ?? 'Selected Venue ($venueId)';
          final prodName = prod?.name ?? 'Assigned Production';

          conflicts.add(
            Conflict(
              conflictId: 'cnf_venue_${venueId}_${rehearsal.rehearsalId}',
              type: ConflictType.venue,
              resourceId: venueId,
              resourceName: venueName,
              conflictingRehearsalId: rehearsal.rehearsalId,
              conflictingProductionName: prodName,
              conflictingStart: rehearsal.startAt,
              conflictingEnd: rehearsal.endAt,
              proposedStart: startAt,
              proposedEnd: endAt,
              severity: ConflictSeverity.blocking,
              explanation:
                  '$venueName is double-booked by "$prodName" '
                  'from ${_formatTime(rehearsal.startAt)} to ${_formatTime(rehearsal.endAt)}.',
              availableResolutions: const [
                ConflictResolutionOption.changeVenue,
                ConflictResolutionOption.changeTime,
              ],
            ),
          );
        }
      }
    }

    // ── 2. Check Cast Member Conflicts ───────────────────────────────────────
    for (final participantId in participantIds.toSet()) {
      for (final rehearsal in eligibleRehearsals) {
        if (rehearsal.participantIds.contains(participantId)) {
          if (_isOverlapping(
            proposedStart: startAt,
            proposedEnd: endAt,
            existingStart: rehearsal.startAt,
            existingEnd: rehearsal.endAt,
          )) {
            final actorName = _dataService.getUserName(participantId);
            final prod = _dataService.getProductionById(rehearsal.productionId);
            final prodName = prod?.name ?? 'Assigned Production';

            conflicts.add(
              Conflict(
                conflictId:
                    'cnf_cast_${participantId}_${rehearsal.rehearsalId}',
                type: ConflictType.cast,
                resourceId: participantId,
                resourceName: actorName,
                conflictingRehearsalId: rehearsal.rehearsalId,
                conflictingProductionName: prodName,
                conflictingStart: rehearsal.startAt,
                conflictingEnd: rehearsal.endAt,
                proposedStart: startAt,
                proposedEnd: endAt,
                severity: ConflictSeverity.blocking,
                explanation:
                    '$actorName is already scheduled for "$prodName" '
                    'from ${_formatTime(rehearsal.startAt)} to ${_formatTime(rehearsal.endAt)}.',
                availableResolutions: const [
                  ConflictResolutionOption.changeParticipants,
                  ConflictResolutionOption.changeTime,
                ],
              ),
            );
          }
        }
      }
    }

    return conflicts;
  }
}
