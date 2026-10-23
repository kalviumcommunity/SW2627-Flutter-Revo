import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/enums/revo_enums.dart';
import '../models/rehearsal.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'schedule_service.dart';
import 'sync_status_service.dart';

/// Firestore-backed unified schedule service for cast and director schedules.
class FirebaseScheduleService implements ScheduleService {
  static FirebaseScheduleService? _instance;

  factory FirebaseScheduleService({
    FirebaseFirestore? firestore,
    AuthIdentityProvider? identityProvider,
  }) {
    if (firestore == null && identityProvider == null) {
      return _instance ??= FirebaseScheduleService._internal();
    }
    return FirebaseScheduleService._internal(
      firestore: firestore,
      identityProvider: identityProvider,
    );
  }

  FirebaseScheduleService._internal({
    this._firestore,
    AuthIdentityProvider? identityProvider,
  }) : _identityProvider = identityProvider ?? FirebaseAuthService();

  FirebaseFirestore? _firestore;
  final AuthIdentityProvider _identityProvider;
  final SyncStatusService _syncStatusService = SyncStatusService.instance;
  final List<Rehearsal> _rehearsals = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _rehearsalSubscription;
  final StreamController<List<Rehearsal>> _rehearsalsController =
      StreamController<List<Rehearsal>>.broadcast();
  bool _disposed = false;

  void _notifyListeners() {
    if (_disposed || _rehearsalsController.isClosed) return;
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  void _startFirestoreListener() {
    if (_rehearsalSubscription != null || _disposed) return;
    final firestore =
        _firestore ??
        (Firebase.apps.isEmpty ? null : FirebaseFirestore.instance);
    if (firestore == null) return;
    _firestore = firestore;
    _rehearsalSubscription = firestore
        .collection('rehearsals')
        .snapshots()
        .listen(
          (snapshot) {
            try {
              final rehearsals = snapshot.docs
                  .map(
                    (document) =>
                        Rehearsal.fromMap(document.data(), document.id),
                  )
                  .toList();
              _rehearsals
                ..clear()
                ..addAll(rehearsals);
              _syncStatusService.recordSuccessfulSync();
              _notifyListeners();
            } catch (error) {
              _syncStatusService.recordSyncFailure(error.toString());
              _notifyListeners();
            }
          },
          onError: (Object error) {
            _syncStatusService.recordSyncFailure(error.toString());
            _notifyListeners();
          },
        );
  }

  void notifyDataChanged() => _notifyListeners();

  List<Rehearsal> get rawRehearsals => List.unmodifiable(_rehearsals);

  SyncState get syncState => _syncStatusService.currentSnapshot.legacySyncState;
  DateTime? get lastSyncedAt => _syncStatusService.lastSyncedAt;

  void addRehearsal(Rehearsal rehearsal) {
    if (_disposed) return;
    final effective = _withPendingState(rehearsal);
    _rehearsals.add(effective);
    if (effective.clientPending) {
      _queuePendingWrite(effective, 'create');
    }
    _notifyListeners();
  }

  void updateRehearsal(Rehearsal rehearsal) {
    if (_disposed) return;
    final index = _rehearsals.indexWhere(
      (item) => item.rehearsalId == rehearsal.rehearsalId,
    );
    if (index == -1) return;
    final effective = _withPendingState(rehearsal);
    _rehearsals[index] = effective;
    if (effective.clientPending) {
      _queuePendingWrite(effective, 'update');
    }
    _notifyListeners();
  }

  void cancelRehearsal(String rehearsalId) {
    if (_disposed) return;
    final index = _rehearsals.indexWhere(
      (item) => item.rehearsalId == rehearsalId,
    );
    if (index == -1) return;
    final existing = _rehearsals[index];
    final cancelled = Rehearsal(
      rehearsalId: existing.rehearsalId,
      productionId: existing.productionId,
      venueId: existing.venueId,
      startAt: existing.startAt,
      endAt: existing.endAt,
      participantIds: existing.participantIds,
      status: RehearsalStatus.cancelled,
      clientPending:
          _syncStatusService.connectivity == ConnectivityState.offline,
      createdBy: existing.createdBy,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
      title: existing.title,
      notes: existing.notes,
    );
    _rehearsals[index] = cancelled;
    if (cancelled.clientPending) {
      _syncStatusService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: cancelled.rehearsalId,
        action: 'cancel',
        payload: {'status': RehearsalStatus.cancelled.name},
      );
    }
    _notifyListeners();
  }

  void setSyncState(SyncState state) {
    switch (state) {
      case SyncState.offline:
        _syncStatusService.setConnectivity(ConnectivityState.offline);
      case SyncState.synced:
        _syncStatusService.setConnectivity(ConnectivityState.online);
        _syncStatusService.recordSuccessfulSync();
      case SyncState.stale:
        _syncStatusService.reEvaluateFreshness();
      case SyncState.pending:
      case SyncState.conflict:
        break;
    }
    _notifyListeners();
  }

  Rehearsal _withPendingState(Rehearsal rehearsal) {
    if (_syncStatusService.connectivity != ConnectivityState.offline ||
        rehearsal.clientPending) {
      return rehearsal;
    }
    return Rehearsal(
      rehearsalId: rehearsal.rehearsalId,
      productionId: rehearsal.productionId,
      venueId: rehearsal.venueId,
      startAt: rehearsal.startAt,
      endAt: rehearsal.endAt,
      participantIds: rehearsal.participantIds,
      status: rehearsal.status,
      clientPending: true,
      createdBy: rehearsal.createdBy,
      createdAt: rehearsal.createdAt,
      updatedAt: DateTime.now(),
      title: rehearsal.title,
      notes: rehearsal.notes,
    );
  }

  void _queuePendingWrite(Rehearsal rehearsal, String action) {
    _syncStatusService.queuePendingWrite(
      entityType: 'rehearsal',
      entityId: rehearsal.rehearsalId,
      action: action,
      payload: rehearsal.toMap(),
    );
  }

  @override
  Stream<ScheduleSnapshot> watchMySchedule() {
    _startFirestoreListener();
    Future.microtask(_notifyListeners);
    return _rehearsalsController.stream.asyncMap((list) async {
      final identity = await _identityProvider.currentIdentity();
      final userId = identity?.userId;
      final filtered =
          list
              .where(
                (rehearsal) =>
                    rehearsal.status != RehearsalStatus.cancelled &&
                    userId != null &&
                    (rehearsal.participantIds.contains(userId) ||
                        rehearsal.createdBy == userId),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return _snapshot(filtered);
    });
  }

  @override
  Stream<ScheduleSnapshot> watchProductionSchedule(String productionId) {
    _startFirestoreListener();
    Future.microtask(_notifyListeners);
    return _rehearsalsController.stream.map((list) {
      final filtered =
          list
              .where(
                (rehearsal) =>
                    rehearsal.status != RehearsalStatus.cancelled &&
                    rehearsal.productionId == productionId,
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return _snapshot(filtered);
    });
  }

  ScheduleSnapshot _snapshot(List<Rehearsal> items) {
    return ScheduleSnapshot(
      items: items,
      syncState: _syncStatusService.currentSnapshot.legacySyncState,
      lastSyncedAt: _syncStatusService.lastSyncedAt,
      hasPendingWrites: items.any(
        (item) =>
            item.clientPending ||
            _syncStatusService.getEntityStatus(item.rehearsalId) ==
                WriteSyncStatus.pending,
      ),
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _rehearsalSubscription?.cancel();
    _rehearsalSubscription = null;
    await _rehearsalsController.close();
  }
}
