import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import '../models/rehearsal.dart';
import 'rehearsal_repository.dart';

class FirebaseRehearsalRepository implements RehearsalRepository {
  FirebaseRehearsalRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  CollectionReference<Map<String, dynamic>> get _rehearsals =>
      _firestore.collection('rehearsals');

  Future<String> _requireManager() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw RevoException(
        RevoErrorCode.unauthenticated,
        'Authentication is required.',
      );
    }
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role']?.toString().toUpperCase();
    if (role != 'DIRECTOR' && role != 'ADMIN') {
      throw RevoException(
        RevoErrorCode.permissionDenied,
        'Only directors or admins can manage rehearsals.',
      );
    }
    return user.uid;
  }

  void _validate(RehearsalInput input) {
    if (input.productionId.trim().isEmpty || input.venueId.trim().isEmpty) {
      throw ArgumentError('Production and venue are required.');
    }
    if (!input.startAt.isBefore(input.endAt)) {
      throw ArgumentError('Rehearsal start must be before its end.');
    }
  }

  DateTime _date(dynamic value) =>
      value is Timestamp ? value.toDate() : DateTime.parse(value.toString());

  Future<List<Conflict>> _conflicts(
    RehearsalInput input, {
    String? excludeRehearsalId,
  }) async {
    final snapshot = await _rehearsals
        .where('status', isEqualTo: RehearsalStatus.confirmed.name)
        .get();
    final conflicts = <Conflict>[];
    for (final document in snapshot.docs) {
      if (document.id == excludeRehearsalId) {
        continue;
      }
      final data = document.data();
      final start = _date(data['startAt']);
      final end = _date(data['endAt']);
      if (end.isAfter(input.startAt) && start.isBefore(input.endAt)) {
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
        for (final participantId in input.participantIds.where(
          participants.contains,
        )) {
          conflicts.add(
            Conflict(
              type: ConflictType.cast,
              resourceId: participantId,
              resourceName: participantId,
              conflictingRehearsalId: document.id,
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
    final normalized = Map<String, dynamic>.from(data)
      ..['startAt'] = _date(data['startAt']).toIso8601String()
      ..['endAt'] = _date(data['endAt']).toIso8601String()
      ..['createdAt'] = _date(data['createdAt']).toIso8601String()
      ..['updatedAt'] = _date(data['updatedAt']).toIso8601String();
    return Rehearsal.fromMap(normalized, document.id);
  }

  @override
  Future<RehearsalSaveResult> createRehearsal(RehearsalInput input) async {
    final userId = await _requireManager();
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
    );
    await ref.set(rehearsal.toMap());
    return RehearsalSaveResult(rehearsal: rehearsal);
  }

  @override
  Future<RehearsalSaveResult> updateRehearsal(
    String rehearsalId,
    RehearsalInput input,
  ) async {
    await _requireManager();
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
    await ref.set(updated.toMap());
    return RehearsalSaveResult(rehearsal: updated);
  }

  @override
  Future<void> cancelRehearsal(String rehearsalId) async {
    await _requireManager();
    final ref = _rehearsals.doc(rehearsalId);
    if (!(await ref.get()).exists) {
      throw RevoException(RevoErrorCode.notFound, 'Rehearsal not found.');
    }
    await ref.update({
      'status': RehearsalStatus.cancelled.name,
      'updatedAt': DateTime.now().toIso8601String(),
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
