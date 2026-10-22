import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../core/enums/revo_enums.dart';
import '../models/rehearsal.dart';
import 'auth_identity.dart';
import 'firebase_auth_service.dart';
import 'schedule_service.dart';

/// Concrete Firebase & Firestore Stream Service implementation for Unified Schedule (FR-09, FR-10).
/// Listens to live updates, supports offline cached snapshots, and provides real-time streams for Cast and Director schedules.
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
  final List<Rehearsal> _rehearsals = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _rehearsalSubscription;
  SyncState _syncState = SyncState.synced;
  DateTime? _lastSyncedAt = DateTime.now();
  bool _disposed = false;

  final StreamController<List<Rehearsal>> _rehearsalsController =
      StreamController<List<Rehearsal>>.broadcast();

  void _notifyListeners() {
    if (_disposed || _rehearsalsController.isClosed) {
      return;
    }
    _lastSyncedAt = DateTime.now();
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  void _startFirestoreListener() {
    if (_rehearsalSubscription != null || _disposed) {
      return;
    }
    final firestore = _firestore ??
        (Firebase.apps.isEmpty ? null : FirebaseFirestore.instance);
    if (firestore == null) {
      return;
    }
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
              _syncState = SyncState.synced;
              _notifyListeners();
            } catch (_) {
              _syncState = SyncState.stale;
              _notifyListeners();
            }
          },
          onError: (_, _) {
            _syncState = SyncState.stale;
            _notifyListeners();
          },
        );
  }

  void notifyDataChanged() {
    _notifyListeners();
  }

  List<Rehearsal> get rawRehearsals => List.unmodifiable(_rehearsals);

  void addRehearsal(Rehearsal rehearsal) {
    if (_disposed) return;
    _rehearsals.add(rehearsal);
    _notifyListeners();
  }

  void updateRehearsal(Rehearsal rehearsal) {
    if (_disposed) return;
    final index = _rehearsals.indexWhere(
      (r) => r.rehearsalId == rehearsal.rehearsalId,
    );
    if (index != -1) {
      _rehearsals[index] = rehearsal;
      _notifyListeners();
    }
  }

  void cancelRehearsal(String rehearsalId) {
    if (_disposed) return;
    final index = _rehearsals.indexWhere((r) => r.rehearsalId == rehearsalId);
    if (index != -1) {
      final existing = _rehearsals[index];
      _rehearsals[index] = Rehearsal(
        rehearsalId: existing.rehearsalId,
        productionId: existing.productionId,
        venueId: existing.venueId,
        startAt: existing.startAt,
        endAt: existing.endAt,
        participantIds: existing.participantIds,
        status: RehearsalStatus.cancelled,
        clientPending: existing.clientPending,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _notifyListeners();
    }
  }

  void setSyncState(SyncState state) {
    if (_disposed) return;
    _syncState = state;
    _notifyListeners();
  }

  @override
  Stream<ScheduleSnapshot> watchMySchedule() {
    _startFirestoreListener();
    // Initial emission trigger via microtask so listener immediately receives current cached state
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.asyncMap((list) async {
      final identity = await _identityProvider.currentIdentity();
      final userId = identity?.userId;

      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return userId != null &&
            (r.participantIds.contains(userId) || r.createdBy == userId);
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      final hasPendingWrites = filtered.any((r) => r.clientPending);

      return ScheduleSnapshot(
        items: filtered,
        syncState: _syncState,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }

  @override
  Stream<ScheduleSnapshot> watchProductionSchedule(String productionId) {
    _startFirestoreListener();
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.map((list) {
      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return r.productionId == productionId;
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      final hasPendingWrites = filtered.any((r) => r.clientPending);

      return ScheduleSnapshot(
        items: filtered,
        syncState: _syncState,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    await _rehearsalSubscription?.cancel();
    _rehearsalSubscription = null;
    await _rehearsalsController.close();
  }
}
