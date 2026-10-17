import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import '../models/rehearsal.dart';
import 'auth_service.dart';
import 'conflict_service.dart';
import 'firebase_auth_service.dart';
import 'mock_conflict_service.dart';
import 'mock_data_service.dart';
import 'rehearsal_repository.dart';

/// In-memory mock repository implementing [RehearsalRepository] (FR-05, FR-08, Issue #21).
/// Enforces role-based permissions, cross-entity relational validation,
/// pre-confirmation conflict validation, and updates the shared [MockDataService].
class MockRehearsalRepository implements RehearsalRepository {
  static final MockRehearsalRepository _instance =
      MockRehearsalRepository._internal();
  factory MockRehearsalRepository({
    MockDataService? dataService,
    ConflictService? conflictService,
    AuthService? authService,
  }) {
    if (dataService != null || conflictService != null || authService != null) {
      return MockRehearsalRepository._custom(
        dataService ?? MockDataService(),
        conflictService ?? MockConflictService(),
        authService ?? FirebaseAuthService(),
      );
    }
    return _instance;
  }

  final MockDataService _dataService;
  final ConflictService _conflictService;
  final AuthService _authService;

  MockRehearsalRepository._internal()
      : _dataService = MockDataService(),
        _conflictService = MockConflictService(),
        _authService = FirebaseAuthService();

  MockRehearsalRepository._custom(
    this._dataService,
    this._conflictService,
    this._authService,
  );

  Future<AppUser> _requireAuthorizedUser() async {
    final user = await _authService.currentUser();
    if (user == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication required to perform rehearsal scheduling.',
      );
    }
    if (user.role == UserRole.cast) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cast members do not have permission to schedule or manage rehearsals.',
      );
    }
    return user;
  }

  void _validateProductionOwnership(AppUser user, String productionId) {
    if (user.role == UserRole.admin) return;

    final production = _dataService.getProductionById(productionId);
    if (production == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production $productionId not found.',
      );
    }

    if (user.role == UserRole.director &&
        production.directorId != user.userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Directors can only schedule rehearsals for productions they are assigned to manage.',
      );
    }
  }

  void _validateInput(RehearsalInput input) {
    if (!input.startAt.isBefore(input.endAt)) {
      throw RevoException(
        RevoErrorCode.invalidInput,
        'Rehearsal end time must be after start time.',
      );
    }

    final prod = _dataService.getProductionById(input.productionId);
    if (prod == null) {
      throw RevoException(
        RevoErrorCode.referenceMissing,
        'Invalid production reference: ${input.productionId}',
      );
    }

    final venue = _dataService.getVenueById(input.venueId);
    if (venue == null) {
      throw RevoException(
        RevoErrorCode.referenceMissing,
        'Invalid venue reference: ${input.venueId}',
      );
    }

    // Validate that participants are assigned to this production
    final assignments =
        _dataService.getCastAssignmentsForProduction(input.productionId);
    final assignedUserIds =
        assignments.map((a) => a.castMemberId).toSet();

    for (final participantId in input.participantIds) {
      if (!assignedUserIds.contains(participantId)) {
        throw RevoException(
          RevoErrorCode.invalidInput,
          'Participant $participantId is not an assigned cast member for production "${prod.name}".',
        );
      }
    }
  }

  @override
  Future<RehearsalSaveResult> createRehearsal(
    RehearsalInput input, {
    AppUser? user,
  }) async {
    final effectiveUser = user ?? await _requireAuthorizedUser();
    if (effectiveUser.role == UserRole.cast) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cast members do not have permission to schedule or manage rehearsals.',
      );
    }
    _validateProductionOwnership(effectiveUser, input.productionId);
    _validateInput(input);

    // Pre-confirmation Conflict Check (FR-08)
    final conflicts = await _conflictService.check(
      venueId: input.venueId,
      startAt: input.startAt,
      endAt: input.endAt,
      participantIds: input.participantIds,
    );

    final blockingConflicts = conflicts.where((c) => c.isBlocking).toList();
    if (blockingConflicts.isNotEmpty) {
      return RehearsalSaveResult(
        rehearsal: null,
        conflicts: blockingConflicts,
      );
    }

    final created = await _dataService.createRehearsal(
      input: input,
      createdBy: effectiveUser.userId,
      status: RehearsalStatus.confirmed,
    );

    return RehearsalSaveResult(
      rehearsal: created,
      conflicts: [],
    );
  }

  @override
  Future<RehearsalSaveResult> updateRehearsal(
    String rehearsalId,
    RehearsalInput input, {
    AppUser? user,
  }) async {
    final effectiveUser = user ?? await _requireAuthorizedUser();
    if (effectiveUser.role == UserRole.cast) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cast members do not have permission to schedule or manage rehearsals.',
      );
    }
    final existing = await getRehearsal(rehearsalId);
    _validateProductionOwnership(effectiveUser, input.productionId);
    _validateInput(input);

    // Check conflicts excluding the current rehearsal
    final conflicts = await _conflictService.check(
      venueId: input.venueId,
      startAt: input.startAt,
      endAt: input.endAt,
      participantIds: input.participantIds,
      excludeRehearsalId: rehearsalId,
    );

    final blockingConflicts = conflicts.where((c) => c.isBlocking).toList();
    if (blockingConflicts.isNotEmpty) {
      return RehearsalSaveResult(
        rehearsal: null,
        conflicts: blockingConflicts,
      );
    }

    final updated = Rehearsal(
      rehearsalId: existing.rehearsalId,
      productionId: input.productionId,
      venueId: input.venueId,
      startAt: input.startAt,
      endAt: input.endAt,
      participantIds: input.participantIds,
      status: existing.status,
      clientPending: existing.clientPending,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      title: input.title ?? existing.title,
      notes: input.notes ?? existing.notes,
    );

    await _dataService.updateRehearsal(updated);

    return RehearsalSaveResult(
      rehearsal: updated,
      conflicts: [],
    );
  }

  @override
  Future<void> cancelRehearsal(String rehearsalId, {AppUser? user}) async {
    final effectiveUser = user ?? await _requireAuthorizedUser();
    if (effectiveUser.role == UserRole.cast) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Cast members do not have permission to schedule or manage rehearsals.',
      );
    }
    final existing = await getRehearsal(rehearsalId);
    _validateProductionOwnership(effectiveUser, existing.productionId);

    await _dataService.cancelRehearsal(rehearsalId);
  }

  @override
  Future<Rehearsal> getRehearsal(String rehearsalId) async {
    final rehearsal = _dataService.getRehearsalById(rehearsalId);
    if (rehearsal == null) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Rehearsal $rehearsalId was not found.',
      );
    }
    return rehearsal;
  }

  Future<Rehearsal?> getRehearsalById(String rehearsalId) async {
    return _dataService.getRehearsalById(rehearsalId);
  }
}
