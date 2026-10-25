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
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    rehearsalStreamFactory,
    Future<QuerySnapshot<Map<String, dynamic>>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    rehearsalReadFactory,
  }) {
    if (firestore == null && identityProvider == null) {
      final service = _instance ??= FirebaseScheduleService._internal();
      service._registerReconnectRevalidation();
      return service;
    }
    final service = FirebaseScheduleService._internal(
      firestore: firestore,
      identityProvider: identityProvider,
      rehearsalStreamFactory: rehearsalStreamFactory,
      rehearsalReadFactory: rehearsalReadFactory,
    );
    service._registerReconnectRevalidation();
    return service;
  }

  FirebaseScheduleService._internal({
    this._firestore,
    AuthIdentityProvider? identityProvider,
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    rehearsalStreamFactory,
    Future<QuerySnapshot<Map<String, dynamic>>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    rehearsalReadFactory,
  }) : _identityProvider = identityProvider ?? FirebaseAuthService(),
       _rehearsalStreamFactory =
           rehearsalStreamFactory ?? ((collection) => collection.snapshots()),
       _rehearsalReadFactory =
           rehearsalReadFactory ?? ((collection) => collection.limit(1).get());

  FirebaseFirestore? _firestore;
  final AuthIdentityProvider _identityProvider;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(
    CollectionReference<Map<String, dynamic>>,
  )
  _rehearsalStreamFactory;
  final Future<QuerySnapshot<Map<String, dynamic>>> Function(
    CollectionReference<Map<String, dynamic>>,
  )
  _rehearsalReadFactory;
  final SyncStatusService _syncStatusService = SyncStatusService.instance;
  final List<Rehearsal> _rehearsals = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _rehearsalSubscription;
  Future<void>? _listenerRecovery;
  final StreamController<List<Rehearsal>> _rehearsalsController =
      StreamController<List<Rehearsal>>.broadcast();
  bool _disposed = false;
  late final ReconnectRevalidationHandler _registeredRevalidator =
      _revalidateAfterReconnect;

  bool get _hasFirebaseBackend =>
      _firestore != null || Firebase.apps.isNotEmpty;

  void _registerReconnectRevalidation() {
    if (_hasFirebaseBackend) {
      _syncStatusService.setReconnectRevalidator(_registeredRevalidator);
    }
  }

  Future<void> _revalidateAfterReconnect() async {
    final identity = await _identityProvider.currentIdentity();
    if (identity == null || !identity.isFirebaseAuthenticated) {
      throw StateError('Authentication is no longer valid after reconnect.');
    }

    final firestore =
        _firestore ??
        (Firebase.apps.isEmpty ? null : FirebaseFirestore.instance);
    if (firestore == null) {
      throw StateError('Firebase is unavailable after reconnect.');
    }
    _firestore = firestore;
    await _rehearsalReadFactory(firestore.collection('rehearsals'));
    await _startFirestoreListener();
  }

  void _notifyListeners() {
    if (_disposed || _rehearsalsController.isClosed) return;
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  Future<void> _startFirestoreListener() async {
    final recovery = _listenerRecovery;
    if (recovery != null) {
      await recovery;
    }
    if (_rehearsalSubscription != null || _disposed) return;
    final firestore =
        _firestore ??
        (Firebase.apps.isEmpty ? null : FirebaseFirestore.instance);
    if (firestore == null) return;
    _firestore = firestore;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
    subscription;
    subscription = _rehearsalStreamFactory(firestore.collection('rehearsals'))
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
            unawaited(
              _recoverFailedListener(subscription).then<void>(
                (_) {},
                onError: (Object recoveryError, StackTrace stackTrace) {
                  _syncStatusService.recordSyncFailure(
                    recoveryError.toString(),
                  );
                },
              ),
            );
          },
          onDone: () {
            unawaited(
              _recoverFailedListener(subscription).then<void>(
                (_) {},
                onError: (Object recoveryError, StackTrace stackTrace) {
                  _syncStatusService.recordSyncFailure(
                    recoveryError.toString(),
                  );
                },
              ),
            );
          },
        );
    _rehearsalSubscription = subscription;
  }

  Future<void> _recoverFailedListener(
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>> subscription,
  ) {
    if (_disposed || !identical(_rehearsalSubscription, subscription)) {
      return Future<void>.value();
    }
    final existingRecovery = _listenerRecovery;
    if (existingRecovery != null) {
      return existingRecovery;
    }
    final recovery = subscription.cancel();
    _listenerRecovery = recovery;
    void clearRecoveryReferences() {
      if (identical(_rehearsalSubscription, subscription)) {
        _rehearsalSubscription = null;
      }
      if (identical(_listenerRecovery, recovery)) {
        _listenerRecovery = null;
      }
    }

    unawaited(
      recovery.then<void>(
        (_) => clearRecoveryReferences(),
        onError: (Object _, StackTrace _) {
          clearRecoveryReferences();
        },
      ),
    );
    return recovery;
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
    unawaited(_startFirestoreListener());
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
    unawaited(_startFirestoreListener());
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
    _syncStatusService.clearReconnectRevalidator(_registeredRevalidator);
    await _rehearsalSubscription?.cancel();
    await _listenerRecovery;
    _rehearsalSubscription = null;
    _listenerRecovery = null;
    await _rehearsalsController.close();
  }
}
