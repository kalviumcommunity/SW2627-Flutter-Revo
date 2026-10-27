import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/app_user.dart';
import '../models/rehearsal.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'conflict_service.dart';
import 'rehearsal_repository.dart';

class FirebaseRehearsalRepository implements RehearsalRepository {
  FirebaseRehearsalRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    AuthIdentityProvider? identityProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _identityProvider =
           identityProvider ??
           (auth != null
               ? FirebaseAuthIdentityProvider(
                   auth: auth,
                   firestore: firestore ?? FirebaseFirestore.instance,
                 )
               : FirebaseAuthService());

  final FirebaseFirestore _firestore;
  final AuthIdentityProvider _identityProvider;
  CollectionReference<Map<String, dynamic>> get _rehearsals =>
      _firestore.collection('rehearsals');

  Future<String> _requireManager() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    if (identity.role != UserRole.director && identity.role != UserRole.admin) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only directors or admins can manage rehearsals.',
      );
    }
    return identity.userId;
  }

  void _validate(RehearsalInput input) {
    if (input.productionId.trim().isEmpty || input.venueId.trim().isEmpty) {
      throw ArgumentError('Production and venue are required.');
    }
    ConflictDetectionRules.validateInterval(
      startAt: input.startAt,
      endAt: input.endAt,
    );
  }

  /// Bug 3 fix (BR-05): Verify the Director is assigned to the production.
  /// Admins bypass this check. Throws [RevoException] with [RevoErrorCode.permissionDenied]
  /// before any Firestore write is attempted, giving a clear user-facing message.
  Future<void> _requireProductionAccess(String userId, String productionId) async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null) return; // already checked by _requireManager
    if (identity.role == UserRole.admin) return;
    final productionDoc = await _firestore.collection('productions').doc(productionId).get();
    if (!productionDoc.exists) {
      throw RevoException(
        RevoErrorCode.notFound,
        'Production "$productionId" was not found.',
      );
    }
    final directorId = productionDoc.data()?['directorId']?.toString();
    if (directorId != userId) {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Directors can only schedule rehearsals for their own productions.',
      );
    }
  }

  DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Rehearsal date is missing or invalid.');
    }
    return parsed;
  }

  Future<List<Conflict>> _conflicts(
    RehearsalInput input, {
    String? excludeRehearsalId,
  }) async {
    final snapshot = await _rehearsals
        .where('status', isEqualTo: RehearsalStatus.confirmed.name)
        .get();
    final conflicts = <Conflict>[];
    for (final document in snapshot.docs) {
      if (document.id == excludeRehearsalId) continue;
      final data = document.data();
      final start = _date(data['startAt']);
      final end = _date(data['endAt']);
      if (ConflictDetectionRules.intervalsOverlap(
        startA: input.startAt,
        endA: input.endAt,
        startB: start,
        endB: end,
      )) {
        if (data['venueId'] == input.venueId) {
          conflicts.add(
            Conflict(
              type: ConflictType.venue,
              resourceId: input.venueId,
              resourceName: input.venueId,
              conflictingRehearsalId: document.id,
              conflictingStart: start,
              conflictingEnd: end,
            ),
          );
        }
        final participants = List<String>.from(
          data['participantIds'] ?? const <String>[],
        );
        for (final participantId in input.participantIds.toSet().where(
          participants.contains,
        )) {
          conflicts.add(
            Conflict(
              type: ConflictType.cast,
              resourceId: participantId,
              resourceName: participantId,
              conflictingRehearsalId: document.id,
              proposedStart: input.startAt,
              proposedEnd: input.endAt,
              conflictingStart: start,
              conflictingEnd: end,
            ),
          );
        }
      }
    }
    return conflicts;
  }

  Rehearsal _fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    if (data == null) {
      throw StateError('Rehearsal document ${document.id} has no data.');
    }
    return Rehearsal.fromMap(Map<String, dynamic>.from(data), document.id);
  }

  @override
  Future<RehearsalSaveResult> createRehearsal(
    RehearsalInput input, {
    AppUser? user,
  }) async {
    final userId = await _requireManager();
    await _requireProductionAccess(userId, input.productionId); // Bug 3 fix
    _validate(input);
    final conflicts = await _conflicts(input);
    if (conflicts.isNotEmpty) {
      return RehearsalSaveResult(conflicts: conflicts);
    }
    final ref = _rehearsals.doc();
    final now = DateTime.now();
    final rehearsal = Rehearsal(
      rehearsalId: ref.id,
      productionId: input.productionId,
      venueId: input.venueId,
      startAt: input.startAt,
      endAt: input.endAt,
      participantIds: input.participantIds,
      status: RehearsalStatus.confirmed,
      clientPending: false,
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      title: input.title,
      notes: input.notes,
    );
    await ref.set(rehearsal.toMap());
    return RehearsalSaveResult(rehearsal: rehearsal);
  }

  @override
  Future<RehearsalSaveResult> updateRehearsal(
    String rehearsalId,
    RehearsalInput input, {
    AppUser? user,
  }) async {
    final userId = await _requireManager();
    await _requireProductionAccess(userId, input.productionId); // Bug 3 fix
    _validate(input);
    final ref = _rehearsals.doc(rehearsalId);
    final existingSnapshot = await ref.get();
    if (!existingSnapshot.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Rehearsal not found.');
    }
    final existing = _fromDocument(existingSnapshot);
    final conflicts = await _conflicts(input, excludeRehearsalId: rehearsalId);
    if (conflicts.isNotEmpty) {
      return RehearsalSaveResult(conflicts: conflicts);
    }
    final now = DateTime.now();
    final updatedTitle = input.title ?? existing.title;
    final updatedNotes = input.notes ?? existing.notes;
    // Bug 5 fix: Use ref.update() instead of ref.set() to avoid deleting
    // fields not present in toMap() (e.g. null title/notes wipe old values).
    await ref.update({
      'productionId': input.productionId,
      'venueId': input.venueId,
      'startAt': Timestamp.fromDate(input.startAt),
      'endAt': Timestamp.fromDate(input.endAt),
      'participantIds': input.participantIds,
      'status': existing.status.name,
      'clientPending': existing.clientPending,
      'updatedAt': Timestamp.fromDate(now),
      'title': updatedTitle,
      'notes': updatedNotes,
    });
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
      updatedAt: now,
      title: updatedTitle,
      notes: updatedNotes,
    );
    return RehearsalSaveResult(rehearsal: updated);
  }

  @override
  Future<void> cancelRehearsal(String rehearsalId, {AppUser? user}) async {
    await _requireManager();
    final ref = _rehearsals.doc(rehearsalId);
    if (!(await ref.get()).exists) {
      throw RevoException(RevoErrorCode.notFound, 'Rehearsal not found.');
    }
    await ref.update({
      'status': RehearsalStatus.cancelled.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<Rehearsal> getRehearsal(String rehearsalId) async {
    final document = await _rehearsals.doc(rehearsalId).get();
    if (!document.exists) {
      throw RevoException(RevoErrorCode.notFound, 'Rehearsal not found.');
    }
    return _fromDocument(document);
  }
}
