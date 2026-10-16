import '../enums/revo_enums.dart';

enum RevoErrorCode {
  unauthenticated,
  unauthorized,
  permissionDenied,
  notFound,
  invalidInput,
  alreadyApplied,
  auditionClosed,
  notSelected,
  schedulingConflict,
  referenceMissing,
  network,
  unknown,
}

enum ConflictSeverity {
  blocking,
  warning,
}

enum ConflictResolutionOption {
  changeVenue,
  changeTime,
  changeParticipants,
}

class Conflict {
  final String conflictId;
  final ConflictType type; // venue | cast
  final String resourceId; // venueId or castMemberId
  final String resourceName; // for display
  final String conflictingRehearsalId;
  final String? conflictingProductionName;
  final DateTime conflictingStart;
  final DateTime conflictingEnd;
  final DateTime? proposedStart;
  final DateTime? proposedEnd;
  final ConflictSeverity severity;
  final String? explanation;
  final List<ConflictResolutionOption> availableResolutions;

  Conflict({
    String? conflictId,
    required this.type,
    required this.resourceId,
    required this.resourceName,
    required this.conflictingRehearsalId,
    this.conflictingProductionName,
    required this.conflictingStart,
    required this.conflictingEnd,
    this.proposedStart,
    this.proposedEnd,
    this.severity = ConflictSeverity.blocking,
    this.explanation,
    List<ConflictResolutionOption>? availableResolutions,
  })  : conflictId = conflictId ??
            'cnf_${type.name}_${resourceId}_$conflictingRehearsalId',
        availableResolutions = availableResolutions ??
            (type == ConflictType.venue
                ? [
                    ConflictResolutionOption.changeVenue,
                    ConflictResolutionOption.changeTime,
                  ]
                : [
                    ConflictResolutionOption.changeParticipants,
                    ConflictResolutionOption.changeTime,
                  ]);

  bool get isBlocking => severity == ConflictSeverity.blocking;
}

class RevoException implements Exception {
  final RevoErrorCode code;
  final String message;
  final List<Conflict> conflicts;

  RevoException(
    this.code,
    this.message, {
    this.conflicts = const [],
  });

  @override
  String toString() => 'RevoException($code): $message';
}
