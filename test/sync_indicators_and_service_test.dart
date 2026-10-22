import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sw2627_flutter_revo_1/core/enums/revo_enums.dart';
import 'package:sw2627_flutter_revo_1/core/theme/revo_theme.dart';
import 'package:sw2627_flutter_revo_1/features/common/widgets/sync_status_indicators.dart';
import 'package:sw2627_flutter_revo_1/models/rehearsal.dart';
import 'package:sw2627_flutter_revo_1/services/sync/freshness_calculator.dart';
import 'package:sw2627_flutter_revo_1/services/sync/pending_write_op.dart';
import 'package:sw2627_flutter_revo_1/services/sync/sync_cache_store.dart';
import 'package:sw2627_flutter_revo_1/services/sync/sync_timestamp_formatter.dart';
import 'package:sw2627_flutter_revo_1/services/sync_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncStatusService syncService;
  late SyncCacheStore cacheStore;
  late File tempTestFile;

  setUp(() {
    tempTestFile = File('${Directory.systemTemp.path}/test_sync_cache_${DateTime.now().millisecondsSinceEpoch}.json');
    cacheStore = SyncCacheStore(customFile: tempTestFile);
    cacheStore.reset();
    syncService = SyncStatusService.instance;
    syncService.resetForTesting(customStore: cacheStore);
  });

  tearDown(() {
    try {
      if (tempTestFile.existsSync()) {
        tempTestFile.deleteSync();
      }
    } catch (_) {}
  });

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: RevoTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  group('1. Initial Synchronization State (FR-12)', () {
    test('Initial sync timestamp is null and formats to "Last synced: Never"', () {
      expect(syncService.lastSyncedAt, isNull);
      expect(SyncTimestampFormatter.formatWithPrefix(null), 'Last synced: Never');
      expect(SyncTimestampFormatter.format(null), 'Never');
    });

    test('Initial state reflects online unknown freshness before authoritative sync', () {
      expect(syncService.connectivity, ConnectivityState.online);
      expect(syncService.freshness, DataFreshness.unknown);
      expect(syncService.pendingOps, isEmpty);
      expect(syncService.hasPendingWrites, isFalse);
    });
  });

  group('2. Online and Offline State Transitions (FR-12)', () {
    test('Switching to offline reactively updates connectivity and data freshness', () async {
      final snapshots = <SyncStatusSnapshot>[];
      final subscription = syncService.watchSnapshot().listen(snapshots.add);

      syncService.setConnectivity(ConnectivityState.offline);
      await pumpEventQueue();

      expect(syncService.connectivity, ConnectivityState.offline);
      expect(syncService.freshness, DataFreshness.stale);
      expect(syncService.currentSnapshot.legacySyncState, SyncState.offline);
      expect(snapshots.any((s) => s.connectivity == ConnectivityState.offline), isTrue);

      await subscription.cancel();
    });

    test('Reconnecting to online restores connectivity state', () async {
      syncService.setConnectivity(ConnectivityState.offline);
      expect(syncService.connectivity, ConnectivityState.offline);

      syncService.setConnectivity(ConnectivityState.online);
      expect(syncService.connectivity, ConnectivityState.online);
    });
  });

  group('3. Data Freshness Evaluation & Thresholds (FR-12)', () {
    test('FreshnessCalculator accurately marks fresh within 5 minutes', () {
      final now = DateTime.now();
      final freshTime = now.subtract(const Duration(minutes: 2));

      final result = FreshnessCalculator.calculate(
        connectivity: ConnectivityState.online,
        lastSyncedAt: freshTime,
        now: now,
      );

      expect(result, DataFreshness.fresh);
    });

    test('FreshnessCalculator marks stale when older than default 5 minute threshold', () {
      final now = DateTime.now();
      final staleTime = now.subtract(const Duration(minutes: 6));

      final result = FreshnessCalculator.calculate(
        connectivity: ConnectivityState.online,
        lastSyncedAt: staleTime,
        now: now,
      );

      expect(result, DataFreshness.stale);
    });

    test('FreshnessCalculator marks stale when offline regardless of timestamp', () {
      final now = DateTime.now();
      final justNow = now.subtract(const Duration(seconds: 10));

      final result = FreshnessCalculator.calculate(
        connectivity: ConnectivityState.offline,
        lastSyncedAt: justNow,
        now: now,
      );

      expect(result, DataFreshness.stale);
    });

    test('FreshnessCalculator marks unknown when never synced', () {
      final result = FreshnessCalculator.calculate(
        connectivity: ConnectivityState.online,
        lastSyncedAt: null,
      );

      expect(result, DataFreshness.unknown);
    });
  });

  group('4. Human-Readable Timestamp Formatting (FR-12)', () {
    test('Formats just now for recent seconds', () {
      final now = DateTime(2026, 10, 19, 10, 45, 0);
      final syncTime = now.subtract(const Duration(seconds: 25));

      expect(SyncTimestampFormatter.formatWithPrefix(syncTime, now: now), 'Last synced: Just now');
      expect(SyncTimestampFormatter.format(syncTime, now: now), 'Just now');
    });

    test('Formats relative minutes for < 60 min', () {
      final now = DateTime(2026, 10, 19, 10, 45, 0);
      final syncTime = now.subtract(const Duration(minutes: 5));

      expect(SyncTimestampFormatter.formatWithPrefix(syncTime, now: now), 'Last synced: 5 min ago');
      expect(SyncTimestampFormatter.format(syncTime, now: now), '5 min ago');
    });

    test('Formats today timestamp for earlier today', () {
      final now = DateTime(2026, 10, 19, 18, 0, 0);
      final syncTime = DateTime(2026, 10, 19, 10, 45, 0);

      expect(SyncTimestampFormatter.formatWithPrefix(syncTime, now: now), 'Last synced: Today, 10:45 AM');
      expect(SyncTimestampFormatter.format(syncTime, now: now), 'Today, 10:45 AM');
    });

    test('Formats date and time for previous days', () {
      final now = DateTime(2026, 10, 25, 12, 0, 0);
      final syncTime = DateTime(2026, 10, 19, 10, 45, 0);

      expect(SyncTimestampFormatter.formatWithPrefix(syncTime, now: now), 'Last synced: 19 Oct, 10:45 AM');
      expect(SyncTimestampFormatter.format(syncTime, now: now), '19 Oct, 10:45 AM');
    });
  });

  group('5. Last-Sync Timestamp Stability & Failure Isolation (FR-12, FR-13)', () {
    test('Failed sync attempt preserves existing successful sync timestamp', () {
      final firstSuccess = DateTime(2026, 10, 19, 9, 30, 0);
      syncService.recordSyncSuccess(firstSuccess);

      expect(syncService.lastSyncedAt, firstSuccess);

      // Record a sync failure
      syncService.recordSyncFailure('Network connection timeout');

      // Timestamp must remain exactly unchanged!
      expect(syncService.lastSyncedAt, firstSuccess);
      expect(syncService.lastError, 'Network connection timeout');
    });

    test('Timestamp does not change merely when write is queued', () {
      final syncTime = DateTime(2026, 10, 19, 10, 0, 0);
      syncService.recordSyncSuccess(syncTime);

      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_101',
        action: 'create',
        payload: {'name': 'Act 1 Run'},
      );

      expect(syncService.lastSyncedAt, syncTime);
      expect(syncService.pendingOps.length, 1);
    });
  });

  group('6. Pending and Confirmed Write Lifecycle (FR-13)', () {
    test('Pending write indicator appears after local change is queued', () {
      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_101',
        action: 'create',
        payload: {'name': 'Act 1 Run'},
      );

      expect(syncService.hasPendingWrites, isTrue);
      expect(syncService.pendingOps.length, 1);
      expect(syncService.getEntityStatus('reh_101'), WriteSyncStatus.pending);
    });

    test('Multiple pending writes are tracked independently', () {
      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_1',
        action: 'create',
        payload: {'name': 'Op 1'},
      );
      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_2',
        action: 'update',
        payload: {'name': 'Op 2'},
      );

      expect(syncService.pendingOps.length, 2);
      expect(syncService.getEntityStatus('reh_1'), WriteSyncStatus.pending);
      expect(syncService.getEntityStatus('reh_2'), WriteSyncStatus.pending);

      // Confirm only reh_1
      final op1 = syncService.pendingOps.firstWhere((o) => o.entityId == 'reh_1');
      syncService.markOperationConfirmed(op1.operationId);

      expect(syncService.getEntityStatus('reh_1'), WriteSyncStatus.confirmed);
      expect(syncService.getEntityStatus('reh_2'), WriteSyncStatus.pending);
      expect(syncService.hasPendingWrites, isTrue);
    });

    test('Idempotency prevents duplicate operations with same ID', () {
      final op1 = PendingWriteOp(
        operationId: 'op_unique_123',
        entityType: 'rehearsal',
        entityId: 'reh_1',
        action: 'create',
        payload: {},
        createdAt: DateTime.now(),
      );

      syncService.registerOperation(op1);
      syncService.registerOperation(op1);

      expect(syncService.pendingOps.length, 1);
    });

    test('Failed writes remain recoverable with error state', () async {
      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_fail_1',
        action: 'create',
        payload: {'title': 'Failed Op'},
      );

      await syncService.reconcilePending(onSyncOp: (op) async {
        return false; // Sync fails
      });

      expect(syncService.pendingOps.length, 1);
      expect(syncService.pendingOps.first.status, WriteSyncStatus.failed);
      expect(syncService.pendingOps.first.retryCount, 1);
      expect(syncService.getEntityStatus('reh_fail_1'), WriteSyncStatus.failed);
    });

    test('Successful reconciliation confirms operations and updates sync time', () async {
      syncService.queuePendingWrite(
        entityType: 'rehearsal',
        entityId: 'reh_success_1',
        action: 'create',
        payload: {'title': 'Success Op'},
      );

      final conflicts = await syncService.reconcilePending(onSyncOp: (op) async {
        return true; // Authoritative persistence acknowledged
      });

      expect(conflicts, isEmpty);
      expect(syncService.pendingOps, isEmpty);
      expect(syncService.getEntityStatus('reh_success_1'), WriteSyncStatus.confirmed);
      expect(syncService.lastSyncedAt, isNotNull);
      expect(syncService.freshness, DataFreshness.fresh);
    });
  });

  group('7. Persistence & Application Restart Safety (FR-12, FR-13)', () {
    test('Restored pending writes remain pending and are NEVER converted to confirmed on restart', () {
      final op = PendingWriteOp(
        operationId: 'op_restart_test',
        entityType: 'rehearsal',
        entityId: 'reh_restart_1',
        action: 'create',
        payload: {'name': 'Preserved Rehearsal'},
        createdAt: DateTime.now(),
        status: WriteSyncStatus.pending,
      );

      cacheStore.savePendingOp(op);
      final syncTime = DateTime(2026, 10, 19, 11, 0, 0);
      cacheStore.saveLastSyncedAt(syncTime);

      // Simulate application restart by loading a fresh store instance from same file
      final restartedStore = SyncCacheStore(customFile: tempTestFile);

      expect(restartedStore.lastSyncedAt, syncTime);
      expect(restartedStore.pendingOps.length, 1);
      expect(restartedStore.pendingOps.first.operationId, 'op_restart_test');
      expect(restartedStore.pendingOps.first.status, WriteSyncStatus.pending);
    });

    test('Cached rehearsals remain available when offline', () {
      final cachedList = [
        Rehearsal(
          rehearsalId: 'reh_cached_1',
          productionId: 'prod_1',
          venueId: 'Main Stage',
          startAt: DateTime(2026, 10, 20, 10, 0),
          endAt: DateTime(2026, 10, 20, 12, 0),
          participantIds: ['u1', 'u2'],
          status: RehearsalStatus.confirmed,
          clientPending: false,
          createdBy: 'dir1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      cacheStore.saveRehearsals(cachedList);

      final reloadedStore = SyncCacheStore(customFile: tempTestFile);
      expect(reloadedStore.cachedRehearsals.length, 1);
      expect(reloadedStore.cachedRehearsals.first.rehearsalId, 'reh_cached_1');
    });
  });

  group('8. Reusable UI Indicators Widget Tests', () {
    testWidgets('OfflineIndicatorBanner renders compact banner with last synced time', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        OfflineIndicatorBanner(
          lastSyncedAt: DateTime(2026, 10, 19, 10, 0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Offline — Showing saved data'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.textContaining('Last synced:'), findsOneWidget);
    });

    testWidgets('StaleDataBanner renders warning and refresh button', (tester) async {
      bool refreshed = false;
      await tester.pumpWidget(wrapWithTheme(
        StaleDataBanner(
          onRefresh: () => refreshed = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Schedule may be outdated'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      expect(refreshed, isTrue);
    });

    testWidgets('PendingWritesBanner renders pending count and sync action', (tester) async {
      bool syncTriggered = false;
      await tester.pumpWidget(wrapWithTheme(
        PendingWritesBanner(
          pendingCount: 3,
          onSyncNow: () => syncTriggered = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('3 pending writes'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);

      await tester.tap(find.text('Sync now'));
      expect(syncTriggered, isTrue);
    });

    testWidgets('FailedSyncBanner renders retry button and error details', (tester) async {
      bool retried = false;
      await tester.pumpWidget(wrapWithTheme(
        FailedSyncBanner(
          errorMessage: 'Server timeout (504)',
          onRetry: () => retried = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sync failed — Retry'), findsOneWidget);
      expect(find.text('Server timeout (504)'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('EntitySyncBadge renders pending and confirmed badges distinctly', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const Column(
          children: [
            EntitySyncBadge(status: WriteSyncStatus.pending),
            EntitySyncBadge(status: WriteSyncStatus.confirmed),
            EntitySyncBadge(status: WriteSyncStatus.failed),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pending sync'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
      expect(find.textContaining('Sync failed'), findsOneWidget);
    });

    testWidgets('SyncStatusCard renders full synchronization telemetry overview', (tester) async {
      syncService.setConnectivity(ConnectivityState.online);
      syncService.recordSyncSuccess(DateTime.now());

      await tester.pumpWidget(wrapWithTheme(const SyncStatusCard()));
      await tester.pumpAndSettle();

      expect(find.text('Synchronization Status'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('Last Synced'), findsOneWidget);
    });

    testWidgets('OfflineEmptyScheduleView communicates offline state without crashing', (tester) async {
      await tester.pumpWidget(wrapWithTheme(
        const OfflineEmptyScheduleView(
          message: 'No cached schedule found for this production.',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Offline — Showing saved data'), findsOneWidget);
      expect(find.text('No cached schedule found for this production.'), findsOneWidget);
    });
  });
}
