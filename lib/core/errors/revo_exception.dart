import '../enums/revo_enums.dart';

enum RevoErrorCode {
  unauthenticated,
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

class Conflict {
  final ConflictType type; // venue | cast
  final String resourceId; // venueId or castMemberId
  final String resourceName; // for display
  final String conflictingRehearsalId;
  final DateTime conflictingStart;
  final DateTime conflictingEnd;

  Conflict({
    required this.type,
    required this.resourceId,
    required this.resourceName,
    required this.conflictingRehearsalId,
    required this.conflictingStart,
    required this.conflictingEnd,
  });
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
