## Summary
Implements GitHub Issue #26 (FR-12: Offline and Cached Schedule, FR-13: Safe Pending Writes, FR-14: Reconnect Reconciliation).
Introduces a reliable synchronization-status system that independently communicates whether Revo is online or offline, whether displayed schedule data is fresh or stale, and whether changes are pending synchronization or confirmed by the authoritative data source. Surfaces a human-readable last successful sync timestamp across dashboards, production schedule screens, and rehearsal detail views.

Also incorporates essential defect fixes and full verification from the focused QA sprint:
- Detailed QA Sprint Report: `docs/REVO_QUICK_TEST_REPORT.md`
- BUG-001: Normalized Cast Member ID mappings (`cast_201` -> `usr_cast_201`) across mock services.
- BUG-002: Replaced unauthorized administrative conflict resolution on Cast Dashboard with read-only validation status (BR-09, BR-10).
- BUG-003: Removed unused imports in verification test file.

## Key Changes

### 1. Independent Synchronization State Model (`lib/core/enums/revo_enums.dart`)
- Separated synchronization concerns into 3 independent dimensions:
  - **Connectivity State**: `online`, `offline`, `unknown`
  - **Data Freshness State**: `fresh`, `stale`, `unknown`
  - **Write Sync Status**: `pending`, `confirmed`, `failed`
- Preserved backward-compatible `SyncState` mapping for legacy components.

### 2. Synchronization Status Service & Architecture (`lib/services/`)
- **`SyncStatusService` (`lib/services/sync_status_service.dart`)**:
  - Centralized single source of truth for synchronization status.
  - Exposes reactive broadcast streams (`watchConnectivity()`, `watchFreshness()`, `watchLastSyncedAt()`, `watchPendingOperations()`, `watchSnapshot()`, `watchEntityStatus()`).
  - Automatic reconnection reconciliation trigger (`reconcilePending()`).
  - Operation idempotency tracking via stable operation IDs (`op_<timestamp>_<entityId>`).
- **`SyncCacheStore` (`lib/services/sync/sync_cache_store.dart`)**:
  - Lightweight, persistent JSON file caching with automatic in-memory fallback.
  - **Restart Safety**: Restored pending operations strictly remain `pending` on restart and are never converted to confirmed without server acknowledgement.
- **`FreshnessCalculator` (`lib/services/sync/freshness_calculator.dart`)**:
  - Centralized configurable freshness policy with 5-minute default threshold.
  - Classifies offline connectivity as `stale` and distinguishes unverified data as `unknown`.
- **`SyncTimestampFormatter` (`lib/services/sync/sync_timestamp_formatter.dart`)**:
  - Formats human-readable timestamps per PRD: `"Last synced: Never"`, `"Last synced: Just now"`, `"Last synced: 5 min ago"`, `"Last synced: Today, 10:45 AM"`, `"Last synced: 19 Oct, 10:45 AM"`.
  - Timestamp updates **only** upon authoritative server persistence confirmation; failed sync preserves previous timestamp.

### 3. Reusable UI Indicator Widgets (`lib/features/common/widgets/sync_status_indicators.dart`)
- **`ComprehensiveSyncBanner`**: Ambient top-of-viewport banner prioritizing Offline > Failed Sync > Pending Writes > Stale Data.
- **`OfflineIndicatorBanner`**: Compact dark status bar displaying `"Offline — Showing saved data"` with the last sync timestamp.
- **`StaleDataBanner`**: Subtle banner indicating `"Schedule may be outdated"` with interactive refresh action.
- **`PendingWritesBanner`**: Displays pending write count with `"Sync now"` action.
- **`FailedSyncBanner`**: Error banner displaying `"Sync failed — Retry"` with failure details and retry callback.
- **`EntitySyncBadge`**: Entity-level badge (`Pending sync`, `Synced`, `Sync failed — Retry`) for individual rehearsal cards.
- **`SyncStatusCard`**: Operational dashboard widget displaying live telemetry (Connectivity pill, Data Freshness, Last Synced, and Pending Writes).
- **`OfflineEmptyScheduleView`**: Clean empty-state view when offline without cached schedule data, preventing network crash states.

### 4. Screen Integrations
- **`DirectorDashboard` & `AdminDashboard`**: Integrated `ComprehensiveSyncBanner` and `SyncStatusCard`.
- **`CastDashboard`**: Surfaces live synchronization card with formatted last-synced timestamp and freshness indicator. Safeguards conflict alerts with read-only badge.
- **`DirectorProductionScheduleScreen`**: Integrated `ComprehensiveSyncBanner`, formatted last-synced timestamp in the summary bar, and `EntitySyncBadge` on rehearsal cards.
- **`MyScheduleScreen` (Cast)**: Integrated `ComprehensiveSyncBanner`, `OfflineEmptyScheduleView`, and `EntitySyncBadge` on cards.
- **`RehearsalDetailScreen`**: Added pending/failed sync status banner with retry button, entity sync badge, and last-synced timestamp.
- **`RehearsalCreationScreen`**: Updated feedback messaging to clearly distinguish local pending writes from server confirmations.
- **`MockRehearsalRepository` & `FirebaseRehearsalRepository`**: Linked offline scheduling to `SyncStatusService.queuePendingWrite` with `clientPending: true`.

## Verification & Tests
- `flutter analyze`: **0 issues found** (clean)
- `flutter test`: **109 / 109 tests passed** (0 failures)
  - 28 sync indicators & cache safety tests in `test/sync_indicators_and_service_test.dart`
  - 16 conflict engine tests in `test/conflict_detection_test.dart`
  - 4 ID mapping & stream retests in `test/verification_audit_fixes_test.dart`
  - 61 unit, widget, and repository abstraction tests
- `flutter build web`: **Clean build** (exit code 0)
