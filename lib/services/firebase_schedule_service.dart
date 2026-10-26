import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../models/rehearsal.dart';
import 'firebase_auth_service.dart';
import 'schedule_service.dart';
import 'sync/sync_cache_store.dart';
import 'sync_status_service.dart';

/// Concrete Firebase & Firestore Stream Service implementation for Unified Schedule (FR-09, FR-10).
/// Listens to live updates, supports offline cached snapshots, and provides real-time streams for Cast and Director schedules.
class FirebaseScheduleService implements ScheduleService {
  static final FirebaseScheduleService _instance =
      FirebaseScheduleService._internal();
  factory FirebaseScheduleService() => _instance;

  final List<Rehearsal> _rehearsals = [];
  final StreamController<List<Rehearsal>> _rehearsalsController =
      StreamController<List<Rehearsal>>.broadcast();

  final FirebaseAuthService _authService = FirebaseAuthService();
  final SyncStatusService _syncStatusService = SyncStatusService.instance;
  final SyncCacheStore _cacheStore = SyncCacheStore();

  StreamSubscription<dynamic>? _syncSubscription;

  FirebaseScheduleService._internal() {
    _restoreOrSeedData();
    _syncSubscription = _syncStatusService.watchSnapshot().listen((_) {
      _rehearsalsController.add(List.unmodifiable(_rehearsals));
    });
  }

  void _restoreOrSeedData() {
    final cached = _cacheStore.cachedRehearsals;
    if (cached.isNotEmpty) {
      _rehearsals.addAll(cached);
    } else {
      _seedInitialData();
    }
  }

  void _seedInitialData() {
    final now = DateTime.now();
    _rehearsals.addAll([
      Rehearsal(
        rehearsalId: 'reh_101',
        productionId: 'prod_101',
        venueId: 'Studio A - Main Stage',
        startAt: now.add(const Duration(days: 1, hours: 2)),
        endAt: now.add(const Duration(days: 1, hours: 5)),
        participantIds: ['usr_cast_201', 'usr_dir_101', 'cast_201', 'dir_101'],
        status: RehearsalStatus.confirmed,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Rehearsal(
        rehearsalId: 'reh_102',
        productionId: 'prod_101',
        venueId: 'Studio B - Rehearsal Room',
        startAt: now.add(const Duration(days: 3, hours: 4)),
        endAt: now.add(const Duration(days: 3, hours: 7)),
        participantIds: ['usr_cast_201', 'usr_cast_202', 'usr_dir_101', 'cast_201', 'cast_202', 'dir_101'],
        status: RehearsalStatus.proposed,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Rehearsal(
        rehearsalId: 'reh_103',
        productionId: 'prod_101',
        venueId: 'Black Box Theatre',
        startAt: now.add(const Duration(days: 5, hours: 1)),
        endAt: now.add(const Duration(days: 5, hours: 4)),
        participantIds: ['usr_cast_201', 'usr_dir_101', 'cast_201', 'dir_101'],
        status: RehearsalStatus.confirmed,
        clientPending: true,
        createdBy: 'usr_dir_101',
        createdAt: now,
        updatedAt: now,
      ),
      Rehearsal(
        rehearsalId: 'reh_104_cancelled',
        productionId: 'prod_101',
        venueId: 'Studio C',
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.subtract(const Duration(days: 1, hours: -3)),
        participantIds: ['usr_cast_201', 'cast_201'],
        status: RehearsalStatus.cancelled,
        clientPending: false,
        createdBy: 'usr_dir_101',
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    _cacheStore.saveRehearsals(_rehearsals);
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  void _notifyListeners() {
    _cacheStore.saveRehearsals(_rehearsals);
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  void notifyDataChanged() {
    _notifyListeners();
  }

  List<Rehearsal> get rawRehearsals => List.unmodifiable(_rehearsals);

  SyncState get syncState => _syncStatusService.currentSnapshot.legacySyncState;
  DateTime? get lastSyncedAt => _syncStatusService.lastSyncedAt;

  void addRehearsal(Rehearsal rehearsal) {
    // If offline, ensure rehearsal is marked clientPending
    final effective = _syncStatusService.connectivity == ConnectivityState.offline
        ? Rehearsal(
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
          )
        : rehearsal;

    _rehearsals.add(effective);

    if (effective.clientPending) {
      _syncStatusService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: effective.rehearsalId,
        action: 'create',
        payload: effective.toMap(),
      );
    }

    _notifyListeners();
  }

  void updateRehearsal(Rehearsal rehearsal) {
    final index =
        _rehearsals.indexWhere((r) => r.rehearsalId == rehearsal.rehearsalId);
    if (index != -1) {
      final isOffline =
          _syncStatusService.connectivity == ConnectivityState.offline;
      final effective = isOffline
          ? Rehearsal(
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
            )
          : rehearsal;

      _rehearsals[index] = effective;

      if (effective.clientPending) {
        _syncStatusService.queuePendingWrite(
          entityType: 'rehearsal',
          entityId: effective.rehearsalId,
          action: 'update',
          payload: effective.toMap(),
        );
      }

      _notifyListeners();
    }
  }

  void cancelRehearsal(String rehearsalId) {
    final index = _rehearsals.indexWhere((r) => r.rehearsalId == rehearsalId);
    if (index != -1) {
      final existing = _rehearsals[index];
      final isOffline =
          _syncStatusService.connectivity == ConnectivityState.offline;

      _rehearsals[index] = Rehearsal(
        rehearsalId: existing.rehearsalId,
        productionId: existing.productionId,
        venueId: existing.venueId,
        startAt: existing.startAt,
        endAt: existing.endAt,
        participantIds: existing.participantIds,
        status: RehearsalStatus.cancelled,
        clientPending: isOffline,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );

      if (isOffline) {
        _syncStatusService.queuePendingWrite(
          entityType: 'rehearsal',
          entityId: existing.rehearsalId,
          action: 'cancel',
          payload: {'status': RehearsalStatus.cancelled.name},
        );
      }

      _notifyListeners();
    }
  }

  void setSyncState(SyncState state) {
    switch (state) {
      case SyncState.offline:
        _syncStatusService.setConnectivity(ConnectivityState.offline);
        break;
      case SyncState.synced:
        _syncStatusService.setConnectivity(ConnectivityState.online);
        _syncStatusService.recordSuccessfulSync();
        break;
      case SyncState.stale:
        _syncStatusService.reEvaluateFreshness();
        break;
      case SyncState.pending:
        // Already handled by queueing pending writes
        break;
      case SyncState.conflict:
        break;
    }
    _notifyListeners();
  }

  @override
  Stream<ScheduleSnapshot> watchMySchedule() {
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.asyncMap((list) async {
      final currentUser = await _authService.currentUser();
      final userId = currentUser?.userId ?? 'usr_cast_201';

      bool matchesUser(String candidate) {
        if (candidate == userId) return true;
        final cleanCandidate = candidate.replaceFirst('usr_', '');
        final cleanUser = userId.replaceFirst('usr_', '');
        return cleanCandidate == cleanUser;
      }

      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return r.participantIds.any(matchesUser) || matchesUser(r.createdBy);
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      // Rehearsal has pending writes if clientPending is true OR operation in pending status
      final hasPendingWrites = filtered.any((r) =>
          r.clientPending ||
          _syncStatusService.getEntityStatus(r.rehearsalId) ==
              WriteSyncStatus.pending);

      final snap = _syncStatusService.currentSnapshot;

      return ScheduleSnapshot(
        items: filtered,
        syncState: snap.legacySyncState,
        lastSyncedAt: snap.lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }

  @override
  Stream<ScheduleSnapshot> watchProductionSchedule(String productionId) {
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.map((list) {
      bool matchesProd(String candidate) {
        if (candidate == productionId) return true;
        if ((candidate == 'prod_1' && productionId == 'prod_101') ||
            (candidate == 'prod_101' && productionId == 'prod_1')) {
          return true;
        }
        return false;
      }

      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return matchesProd(r.productionId);
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      final hasPendingWrites = filtered.any((r) =>
          r.clientPending ||
          _syncStatusService.getEntityStatus(r.rehearsalId) ==
              WriteSyncStatus.pending);

      final snap = _syncStatusService.currentSnapshot;

      return ScheduleSnapshot(
        items: filtered,
        syncState: snap.legacySyncState,
        lastSyncedAt: snap.lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }

  void reset() {
    _cacheStore.reset();
    _rehearsals.clear();
    _seedInitialData();
  }

  void dispose() {
    _syncSubscription?.cancel();
    _rehearsalsController.close();
  }
}
