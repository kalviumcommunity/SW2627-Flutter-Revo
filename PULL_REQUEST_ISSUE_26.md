# Pull Request: Implement Offline, Stale, Pending, and Confirmed State Indicators

**Target Branch:** `development`  
**Source Branch:** `feat/offline-stale-pending-confirmed-indicators-issue-26`  
**GitHub PR URL:** https://github.com/kalviumcommunity/SW2627-Flutter-Revo/pull/new/feat/offline-stale-pending-confirmed-indicators-issue-26  
**Related Issue:** Closes #26  
**Requirements Satisfied:** FR-12 (Offline and Cached Schedule), FR-13 (Safe Pending Writes)

---

## Summary
Implements GitHub Issue #26 (FR-12: Offline and Cached Schedule, FR-13: Safe Pending Writes).
Introduces a reliable synchronization-status system that independently communicates whether Revo is online or offline, whether displayed schedule data is fresh or stale, and whether changes are pending synchronization or confirmed by the authoritative data source. Surfaces a human-readable last successful sync timestamp across dashboards, production schedule screens, and rehearsal detail views.

---

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
  - Classifies offline connectivity as `stale` (Scenario B) and distinguishes unverified data as `unknown`.
- **`SyncTimestampFormatter` (`lib/services/sync/sync_timestamp_formatter.dart`)**:
  - Formats human-readable timestamps per PRD: `"Last synced: Never"`, `"Last synced: Just now"`, `"Last synced: 5 min ago"`, `"Last synced: Today, 10:45 AM"`, `"Last synced: 19 Oct, 10:45 AM"`.
  - Timestamp updates **only** upon authoritative server persistence confirmation.

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
- **`CastDashboard`**: Surfaces live synchronization card with formatted last-synced timestamp and freshness indicator.
- **`DirectorProductionScheduleScreen`**: Integrated `ComprehensiveSyncBanner`, formatted last-synced timestamp in the summary bar, and `EntitySyncBadge` on rehearsal cards.
- **`MyScheduleScreen` (Cast)**: Integrated `ComprehensiveSyncBanner`, `OfflineEmptyScheduleView`, and `EntitySyncBadge` on cards.
- **`RehearsalDetailScreen`**: Added pending/failed sync status banner with retry button, entity sync badge, and last-synced timestamp.
- **`RehearsalCreationScreen`**: Updated feedback messaging to clearly distinguish local pending writes (`"Rehearsal saved locally (Pending sync — awaiting connection)"`) from server confirmations.
- **`MockRehearsalRepository` & `FirebaseRehearsalRepository`**: Linked offline scheduling to `SyncStatusService.queuePendingWrite` with `clientPending: true`.

---

## State Transition Verification

- **Scenario A (Online & Synchronized)**: Connectivity is `online`, freshness is `fresh`, operations are `confirmed`, last-sync time is updated.
- **Scenario B (Online to Offline)**: Connectivity transitions to `offline`, cached schedule remains readable, freshness transitions to `stale`, last-sync time is preserved.
- **Scenario C (Offline Write)**: User creates/edits rehearsal offline, local optimistic update is retained, entity status marked `pending`, no false server confirmation is shown.
- **Scenario D (Reconnection)**: Connectivity transitions to `online`, triggers `reconcilePending()`, operations remain pending until server persistence succeeds.
- **Scenario E (Successful Sync)**: Operations transition to `confirmed`, removed from pending queue, last-sync timestamp updates.
- **Scenario F (Sync Failure)**: Operation marked `failed` with retry count incremented and error message preserved; last successful timestamp remains intact.
- **Scenario G (App Restart)**: Cache store restores cached schedule and pending ops; pending ops remain strictly `pending` (never confirmed).

---

## Verification & Tests

- **Static Analysis**: `flutter analyze` — **0 issues found** (clean).
- **Test Suite**: `flutter test` — **105/105 tests passed** (0 failures).
  - 77 original unit, widget, and conflict tests preserved and passing.
  - 28 new tests in `test/sync_indicators_and_service_test.dart` covering:
    - Initial state (`lastSyncedAt == null`, "Last synced: Never")
    - Online/offline transitions and stream emissions
    - Freshness calculations (fresh, stale, unknown, threshold compliance)
    - Relative and absolute timestamp formatting
    - Timestamp stability on sync failures and write queueing
    - Independent tracking of multiple pending writes
    - Idempotency preventing duplicate operation IDs
    - Recoverable failed writes and retry mechanics
    - Successful reconciliation and server acknowledgement
    - Persistent cache restart safety (pending writes remain pending)
    - Widget tests for all 8 indicator components
