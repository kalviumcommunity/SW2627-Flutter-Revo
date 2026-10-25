import 'dart:async';

import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';
import 'sync/freshness_calculator.dart';
import 'sync/pending_write_op.dart';
import 'sync/sync_cache_store.dart';
import 'sync_service.dart';

/// Unified snapshot representing all independent synchronization dimensions.
class SyncStatusSnapshot {
  final ConnectivityState connectivity;
  final DataFreshness freshness;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final String? lastSyncError;
  final SyncState legacySyncState;

  const SyncStatusSnapshot({
    required this.connectivity,
    required this.freshness,
    this.lastSyncedAt,
    required this.pendingCount,
    this.lastSyncError,
    required this.legacySyncState,
  });

  bool get isOffline => connectivity == ConnectivityState.offline;
  bool get isOnline => connectivity == ConnectivityState.online;
  bool get isFresh => freshness == DataFreshness.fresh;
  bool get isStale => freshness == DataFreshness.stale;
  bool get hasPendingWrites => pendingCount > 0;
  bool get hasError => lastSyncError != null;
}

typedef RemotePersistenceHandler = Future<bool> Function(PendingWriteOp op);
typedef ReconnectRevalidationHandler = Future<void> Function();

/// Centralized, reactive synchronization status service (FR-12, FR-13).
/// Serves as the single source of truth for:
/// - Independent Connectivity State (`online`, `offline`, `unknown`)
/// - Independent Data Freshness State (`fresh`, `stale`, `unknown`)
/// - Independent Write Synchronization State (`pending`, `confirmed`, `failed`)
/// - Human-readable last successful synchronization timestamp.
class SyncStatusService implements SyncService {
  static final SyncStatusService _instance = SyncStatusService._internal();
  static SyncStatusService get instance => _instance;

  factory SyncStatusService({
    SyncCacheStore? cacheStore,
    Duration freshnessThreshold = FreshnessCalculator.defaultFreshnessThreshold,
  }) {
    if (cacheStore != null) {
      _instance._cacheStore = cacheStore;
      _instance._restoreFromCache();
    }
    _instance.freshnessThreshold = freshnessThreshold;
    return _instance;
  }

  SyncCacheStore _cacheStore;
  Duration freshnessThreshold;

  ConnectivityState _connectivity = ConnectivityState.online;
  DataFreshness _freshness = DataFreshness.unknown;
  DateTime? _lastSyncedAt;
  String? _lastSyncError;

  final Map<String, PendingWriteOp> _pendingOps = {};
  RemotePersistenceHandler? _remoteHandler;
  ReconnectRevalidationHandler? _reconnectRevalidator;
  Future<void>? _revalidationInFlight;
  Future<List<Conflict>>? _reconciliationInFlight;

  // Reactive StreamControllers
  final _connectivityController =
      StreamController<ConnectivityState>.broadcast();
  final _freshnessController = StreamController<DataFreshness>.broadcast();
  final _lastSyncedController = StreamController<DateTime?>.broadcast();
  final _pendingOpsController =
      StreamController<List<PendingWriteOp>>.broadcast();
  final _syncStateController = StreamController<SyncState>.broadcast();
  final _snapshotController = StreamController<SyncStatusSnapshot>.broadcast();
  final Map<String, StreamController<WriteSyncStatus>> _entityControllers = {};

  SyncStatusService._internal()
    : _cacheStore = SyncCacheStore(),
      freshnessThreshold = FreshnessCalculator.defaultFreshnessThreshold {
    _restoreFromCache();
  }

  void _restoreFromCache() {
    _lastSyncedAt = _cacheStore.lastSyncedAt;
    _pendingOps.clear();
    for (final op in _cacheStore.pendingOps) {
      _pendingOps[op.operationId] = op;
    }
    _recalculateFreshness(emit: false);
  }

  // ── Public Accessors ────────────────────────────────────────────────────────

  ConnectivityState get connectivity => _connectivity;
  DataFreshness get freshness => _freshness;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastSyncError => _lastSyncError;
  String? get lastError => _lastSyncError;
  List<PendingWriteOp> get pendingOperations =>
      List.unmodifiable(_pendingOps.values);
  List<PendingWriteOp> get pendingOps => pendingOperations;
  int get pendingCount =>
      _pendingOps.values.where((op) => op.isPending || op.isFailed).length;
  bool get hasPendingWrites => pendingCount > 0;

  SyncStatusSnapshot get currentSnapshot => SyncStatusSnapshot(
    connectivity: _connectivity,
    freshness: _freshness,
    lastSyncedAt: _lastSyncedAt,
    pendingCount: pendingCount,
    lastSyncError: _lastSyncError,
    legacySyncState: _computeLegacySyncState(),
  );

  void setRemoteHandler(RemotePersistenceHandler? handler) {
    _remoteHandler = handler;
  }

  /// Registers the authoritative session/data check that must run before
  /// pending writes are replayed after connectivity is restored.
  void setReconnectRevalidator(ReconnectRevalidationHandler? handler) {
    _reconnectRevalidator = handler;
  }

  void clearReconnectRevalidator(ReconnectRevalidationHandler handler) {
    if (identical(_reconnectRevalidator, handler)) {
      _reconnectRevalidator = null;
    }
  }

  // ── Reactive Streams ────────────────────────────────────────────────────────

  Stream<ConnectivityState> watchConnectivity() async* {
    yield _connectivity;
    yield* _connectivityController.stream;
  }

  Stream<DataFreshness> watchFreshness() async* {
    yield _freshness;
    yield* _freshnessController.stream;
  }

  @override
  Stream<DateTime?> watchLastSyncedAt() async* {
    yield _lastSyncedAt;
    yield* _lastSyncedController.stream;
  }

  Stream<List<PendingWriteOp>> watchPendingOperations() async* {
    yield pendingOperations;
    yield* _pendingOpsController.stream;
  }

  Stream<SyncStatusSnapshot> watchSnapshot() async* {
    yield currentSnapshot;
    yield* _snapshotController.stream;
  }

  @override
  Stream<SyncState> watchSyncState() async* {
    yield _computeLegacySyncState();
    yield* _syncStateController.stream;
  }

  WriteSyncStatus getEntityStatus(String entityId) {
    final matching = _pendingOps.values.where((op) => op.entityId == entityId);
    if (matching.isEmpty) return WriteSyncStatus.confirmed;
    if (matching.any((op) => op.isFailed)) return WriteSyncStatus.failed;
    if (matching.any((op) => op.isPending)) return WriteSyncStatus.pending;
    return WriteSyncStatus.confirmed;
  }

  Stream<WriteSyncStatus> watchEntityStatus(String entityId) async* {
    yield getEntityStatus(entityId);
    _entityControllers.putIfAbsent(
      entityId,
      () => StreamController<WriteSyncStatus>.broadcast(),
    );
    yield* _entityControllers[entityId]!.stream;
  }

  // ── Connectivity Management (FR-12, FR-13) ──────────────────────────────────

  /// Updates connectivity state reactively and triggers reconnection reconciliation if restored.
  void setConnectivity(ConnectivityState newState) {
    if (_connectivity == newState) return;
    final previousState = _connectivity;
    _connectivity = newState;
    _connectivityController.add(_connectivity);

    _recalculateFreshness(emit: true);
    _notifySnapshot();

    // Scenario D: Reconnection: Online transition triggers pending write sync
    if (previousState == ConnectivityState.offline &&
        newState == ConnectivityState.online) {
      unawaited(revalidateOnReconnect());
    }
  }

  /// Revalidates the authenticated session and remote data once per online
  /// transition. Failed validation leaves pending work intact for retry.
  Future<void> revalidateOnReconnect() {
    final inFlight = _revalidationInFlight;
    if (inFlight != null) return inFlight;

    final future = _runReconnectRevalidation();
    _revalidationInFlight = future;
    unawaited(
      future.then(
        (_) => _clearRevalidation(future),
        onError: (Object _, StackTrace _) => _clearRevalidation(future),
      ),
    );
    return future;
  }

  void _clearRevalidation(Future<void> future) {
    if (identical(_revalidationInFlight, future)) {
      _revalidationInFlight = null;
    }
  }

  Future<void> _runReconnectRevalidation() async {
    try {
      await _reconnectRevalidator?.call();
    } catch (error) {
      recordSyncFailure(error.toString());
      return;
    }
    await reconcilePending();
  }

  // ── Freshness Evaluation (FR-12) ───────────────────────────────────────────

  /// Re-evaluates data freshness (e.g. when app returns to foreground or timer ticks).
  void reEvaluateFreshness() {
    _recalculateFreshness(emit: true);
    _notifySnapshot();
  }

  void _recalculateFreshness({bool emit = true}) {
    _freshness = FreshnessCalculator.calculate(
      connectivity: _connectivity,
      lastSyncedAt: _lastSyncedAt,
      threshold: freshnessThreshold,
      hasSyncError: _lastSyncError != null,
    );
    if (emit) {
      _freshnessController.add(_freshness);
      _syncStateController.add(_computeLegacySyncState());
    }
  }

  // ── Successful & Failed Sync Recording (FR-12) ──────────────────────────────

  /// Records authoritative successful synchronization.
  /// RULE: ONLY call when server persistence/sync actually succeeds.
  void recordSuccessfulSync({DateTime? timestamp}) {
    _lastSyncedAt = timestamp ?? DateTime.now();
    _lastSyncError = null;
    _cacheStore.saveLastSyncedAt(_lastSyncedAt!);

    _lastSyncedController.add(_lastSyncedAt);
    _recalculateFreshness(emit: true);
    _notifySnapshot();
  }

  /// Alias for recordSuccessfulSync
  void recordSyncSuccess([DateTime? timestamp]) =>
      recordSuccessfulSync(timestamp: timestamp);

  /// Registers an operation directly (useful for testing or migration)
  void registerOperation(PendingWriteOp op) {
    if (_pendingOps.containsKey(op.operationId)) return;
    _pendingOps[op.operationId] = op;
    _cacheStore.savePendingOp(op);
    _notifyPendingOps();
    _notifyEntityStatus(op.entityId, op.status);
    _notifySnapshot();
  }

  /// Marks a specific pending operation as confirmed
  void markOperationConfirmed(String operationId) {
    final op = _pendingOps[operationId];
    if (op != null) {
      op.status = WriteSyncStatus.confirmed;
      _pendingOps.remove(operationId);
      _cacheStore.removePendingOp(operationId);
      _notifyPendingOps();
      _notifyEntityStatus(op.entityId, WriteSyncStatus.confirmed);
      _notifySnapshot();
    }
  }

  /// Records synchronization failure.
  /// RULE: Must NOT overwrite or erase the last successful timestamp.
  void recordSyncFailure(String errorMessage) {
    _lastSyncError = errorMessage;
    _recalculateFreshness(emit: true);
    _notifySnapshot();
  }

  // ── Safe Pending Writes & Reconnection (FR-13) ──────────────────────────────

  /// Queues a pending write operation locally with an idempotent operation ID.
  Future<PendingWriteOp> queuePendingWrite({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
    String? customOperationId,
  }) async {
    final opId =
        customOperationId ??
        'op_${DateTime.now().millisecondsSinceEpoch}_$entityId';

    // Idempotency: if already queued, return existing
    if (_pendingOps.containsKey(opId)) {
      return _pendingOps[opId]!;
    }

    final op = PendingWriteOp(
      operationId: opId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      payload: payload,
      status: WriteSyncStatus.pending,
      createdAt: DateTime.now(),
    );

    _pendingOps[opId] = op;
    _cacheStore.savePendingOp(op);

    _notifyPendingOps();
    _notifyEntityStatus(entityId, WriteSyncStatus.pending);
    _notifySnapshot();

    // If online, immediately attempt synchronization
    if (_connectivity == ConnectivityState.online) {
      _executeOperation(op);
    }

    return op;
  }

  /// Retries a single pending or failed operation.
  Future<bool> retryOperation(String operationId) async {
    final op = _pendingOps[operationId];
    if (op == null) return false;

    op.status = WriteSyncStatus.pending;
    op.errorMessage = null;
    _cacheStore.savePendingOp(op);

    _notifyPendingOps();
    _notifyEntityStatus(op.entityId, WriteSyncStatus.pending);
    _notifySnapshot();

    return _executeOperation(op);
  }

  Future<bool> _executeOperation(PendingWriteOp op) async {
    if (_connectivity != ConnectivityState.online) {
      return false;
    }

    if (_remoteHandler == null) {
      // RULE: Do not simulate server confirmation when no authoritative backend is connected.
      // Writes must remain safely pending locally.
      return false;
    }

    op.lastAttemptAt = DateTime.now();
    op.retryCount++;

    bool success = false;
    try {
      success = await _remoteHandler!(op);
    } catch (e) {
      op.errorMessage = e.toString();
      success = false;
    }

    if (success) {
      op.status = WriteSyncStatus.confirmed;
      op.errorMessage = null;
      _pendingOps.remove(op.operationId);
      _cacheStore.removePendingOp(op.operationId);

      _notifyPendingOps();
      _notifyEntityStatus(op.entityId, WriteSyncStatus.confirmed);
      recordSuccessfulSync();
      return true;
    } else {
      op.status = WriteSyncStatus.failed;
      op.errorMessage ??= 'Synchronization attempt failed.';
      _cacheStore.savePendingOp(op);

      _notifyPendingOps();
      _notifyEntityStatus(op.entityId, WriteSyncStatus.failed);
      recordSyncFailure(op.errorMessage!);
      return false;
    }
  }

  /// Called on reconnect (or manual trigger): iterates and synchronizes all pending writes safely.
  @override
  Future<List<Conflict>> reconcilePending({
    RemotePersistenceHandler? onSyncOp,
  }) {
    final inFlight = _reconciliationInFlight;
    if (inFlight != null) return inFlight;

    final future = _reconcilePending(onSyncOp: onSyncOp);
    _reconciliationInFlight = future;
    unawaited(
      future.then(
        (_) => _clearReconciliation(future),
        onError: (Object _, StackTrace _) => _clearReconciliation(future),
      ),
    );
    return future;
  }

  void _clearReconciliation(Future<List<Conflict>> future) {
    if (identical(_reconciliationInFlight, future)) {
      _reconciliationInFlight = null;
    }
  }

  Future<List<Conflict>> _reconcilePending({
    RemotePersistenceHandler? onSyncOp,
  }) async {
    if (onSyncOp != null) {
      _remoteHandler = onSyncOp;
    }

    if (_connectivity != ConnectivityState.online || _remoteHandler == null) {
      return [];
    }

    final opsToProcess = _pendingOps.values
        .where((op) => op.isPending || op.isFailed)
        .toList();

    for (final op in opsToProcess) {
      await _executeOperation(op);
    }

    if (_pendingOps.isEmpty && opsToProcess.isNotEmpty) {
      recordSuccessfulSync();
    }

    return [];
  }

  // ── Helpers & Test Resets ──────────────────────────────────────────────────

  void _notifyPendingOps() {
    _pendingOpsController.add(pendingOperations);
    _syncStateController.add(_computeLegacySyncState());
  }

  void _notifyEntityStatus(String entityId, WriteSyncStatus status) {
    if (_entityControllers.containsKey(entityId)) {
      _entityControllers[entityId]!.add(status);
    }
  }

  void _notifySnapshot() {
    _snapshotController.add(currentSnapshot);
  }

  SyncState _computeLegacySyncState() {
    if (_connectivity == ConnectivityState.offline) return SyncState.offline;
    if (_lastSyncError != null && _pendingOps.values.any((o) => o.isFailed)) {
      return SyncState.stale;
    }
    if (pendingCount > 0) return SyncState.pending;
    if (_freshness == DataFreshness.stale) return SyncState.stale;
    return SyncState.synced;
  }

  /// Complete reset for test isolation
  void resetForTesting({SyncCacheStore? customStore, bool inMemory = true}) {
    _connectivity = ConnectivityState.online;
    _freshness = DataFreshness.unknown;
    _lastSyncedAt = null;
    _lastSyncError = null;
    _pendingOps.clear();
    _remoteHandler = null;
    _reconnectRevalidator = null;
    _revalidationInFlight = null;
    _reconciliationInFlight = null;
    _cacheStore = customStore ?? SyncCacheStore(inMemoryOnly: inMemory);
    _restoreFromCache();
  }
}
