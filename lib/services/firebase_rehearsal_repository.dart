import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/rehearsal.dart';
import 'firebase_auth_service.dart';
import 'firebase_schedule_service.dart';
import 'rehearsal_repository.dart';

/// Concrete Implementation of RehearsalRepository managing creation, modification, and cancellation of rehearsals (FR-05, FR-09, BR-08).
class FirebaseRehearsalRepository implements RehearsalRepository {
  static final FirebaseRehearsalRepository _instance =
      FirebaseRehearsalRepository._internal();
  factory FirebaseRehearsalRepository() => _instance;

  FirebaseRehearsalRepository._internal();

  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseScheduleService _scheduleService = FirebaseScheduleService();

  @override
  Future<RehearsalSaveResult> createRehearsal(RehearsalInput input) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors are authorized to schedule rehearsals (FR-05).',
      );
    }

    final newRehearsal = Rehearsal(
      rehearsalId: 'reh_${DateTime.now().millisecondsSinceEpoch}',
      productionId: input.productionId,
      venueId: input.venueId,
      startAt: input.startAt,
      endAt: input.endAt,
      participantIds: input.participantIds,
      status: RehearsalStatus.confirmed,
      clientPending: false,
      createdBy: currentUser.userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _scheduleService.addRehearsal(newRehearsal);

    return RehearsalSaveResult(
      rehearsal: newRehearsal,
      conflicts: [],
    );
  }

  @override
  Future<RehearsalSaveResult> updateRehearsal(
      String rehearsalId, RehearsalInput input) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors are authorized to modify rehearsals.',
      );
    }

    final existing = await getRehearsal(rehearsalId);
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
    );

    _scheduleService.updateRehearsal(updated);

    return RehearsalSaveResult(
      rehearsal: updated,
      conflicts: [],
    );
  }

  @override
  Future<void> cancelRehearsal(String rehearsalId) async {
    final currentUser = await _authService.currentUser();
    if (currentUser == null || currentUser.role != UserRole.director) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only Directors can cancel scheduled rehearsals (BR-08).',
      );
    }

    _scheduleService.cancelRehearsal(rehearsalId);
  }

  @override
  Future<Rehearsal> getRehearsal(String rehearsalId) async {
    final rawList = _scheduleService.rawRehearsals;
    final index = rawList.indexWhere((r) => r.rehearsalId == rehearsalId);
    if (index == -1) {
      throw RevoException(RevoErrorCode.notFound, 'Rehearsal not found.');
    }
    return rawList[index];
  }
}
