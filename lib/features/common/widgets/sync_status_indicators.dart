import 'package:flutter/material.dart';
import '../../../core/constants/revo_colors.dart';
import '../../../core/constants/revo_spacing.dart';
import '../../../core/constants/revo_typography.dart';
import '../../../core/enums/revo_enums.dart';
import '../../../services/sync/sync_timestamp_formatter.dart';
import '../../../services/sync_status_service.dart';

// ── 1. Comprehensive Smart Sync Banner ────────────────────────────────────────

/// Smart banner that observes [SyncStatusService] and displays appropriate
/// indicators for offline, stale data, pending writes, and failed sync (FR-12, FR-13).
class ComprehensiveSyncBanner extends StatelessWidget {
  final SyncStatusService? service;
  final VoidCallback? onRefresh;

  const ComprehensiveSyncBanner({
    super.key,
    this.service,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final syncService = service ?? SyncStatusService.instance;

    return StreamBuilder<SyncStatusSnapshot>(
      stream: syncService.watchSnapshot(),
      builder: (context, snapshot) {
        final snap = snapshot.data ?? syncService.currentSnapshot;

        // Priority 1: Offline state
        if (snap.isOffline) {
          return OfflineIndicatorBanner(
            lastSyncedAt: snap.lastSyncedAt,
          );
        }

        // Priority 2: Failed writes / sync error
        if (snap.hasError || snap.pendingCount > 0 && snap.legacySyncState == SyncState.stale) {
          return FailedSyncBanner(
            onRetry: () => syncService.reconcilePending(),
          );
        }

        // Priority 3: Pending writes awaiting server confirmation
        if (snap.hasPendingWrites) {
          return PendingWritesBanner(
            pendingCount: snap.pendingCount,
            onSyncNow: () => syncService.reconcilePending(),
          );
        }

        // Priority 4: Stale schedule data warning
        if (snap.isStale) {
          return StaleDataBanner(
            onRefresh: onRefresh ?? () => syncService.reconcilePending(),
          );
        }

        // Online, fresh, and confirmed: Minimal or hidden
        return const SizedBox.shrink();
      },
    );
  }
}

// ── 2. Offline Indicator Banner (FR-12) ────────────────────────────────────────

/// Compact status banner shown when the application is offline.
/// Clearly communicates that the user is viewing locally saved cached data and shows the last sync timestamp.
class OfflineIndicatorBanner extends StatelessWidget {
  final DateTime? lastSyncedAt;
  final VoidCallback? onRetry;

  const OfflineIndicatorBanner({
    super.key,
    this.lastSyncedAt,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = SyncTimestampFormatter.format(lastSyncedAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF171B26), // High contrast dark banner
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  const TextSpan(
                    text: 'Offline — Showing saved data. ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  TextSpan(
                    text: 'Last synced: $formattedTime',
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'OFFLINE',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3. Stale Data Indicator Banner (FR-12) ────────────────────────────────────

/// Subtle warning shown when displayed schedule data may be outdated.
class StaleDataBanner extends StatelessWidget {
  final VoidCallback? onRefresh;

  const StaleDataBanner({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: RevoColors.surfaceContainerLow,
        border: const Border(
          bottom: BorderSide(color: RevoColors.surfaceDim, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_outlined,
            color: RevoColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Schedule may be outdated',
              style: TextStyle(
                fontSize: 12,
                color: RevoColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRefresh != null)
            GestureDetector(
              onTap: onRefresh,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: RevoColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: RevoColors.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── 4. Pending Writes Banner (FR-13) ──────────────────────────────────────────

/// Banner surfacing unconfirmed local write operations awaiting server synchronization.
class PendingWritesBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onSyncNow;

  const PendingWritesBanner({
    super.key,
    required this.pendingCount,
    this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: RevoColors.warningSurface,
        border: Border(
          bottom: BorderSide(color: RevoColors.warningAmber, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.upload_outlined,
            color: RevoColors.warningText,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: RevoColors.warningText,
                ),
                children: [
                  TextSpan(
                    text: '$pendingCount pending write${pendingCount != 1 ? 's' : ''} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: '— awaiting server confirmation'),
                ],
              ),
            ),
          ),
          if (onSyncNow != null)
            GestureDetector(
              onTap: onSyncNow,
              child: const Text(
                'Sync now',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RevoColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 5. Failed Synchronization Banner (FR-13) ──────────────────────────────────

/// Banner shown when a write or sync operation fails.
class FailedSyncBanner extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;
  final String? errorMessage;

  const FailedSyncBanner({
    super.key,
    this.onRetry,
    this.message,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMsg = errorMessage ?? message ?? 'Sync failed — Retry';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: RevoColors.errorSurface,
        border: Border(
          bottom: BorderSide(color: RevoColors.errorCrimson, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: RevoColors.errorCrimson,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sync failed — Retry',
                  style: TextStyle(
                    fontSize: 12,
                    color: RevoColors.errorCrimson,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (effectiveMsg != 'Sync failed — Retry')
                  Text(
                    effectiveMsg,
                    style: const TextStyle(
                      fontSize: 11,
                      color: RevoColors.errorCrimson,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RevoColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 6. Entity Sync Badge (FR-13) ──────────────────────────────────────────────

/// Small, reusable badge associated with a specific entity (e.g. rehearsal card)
/// to indicate if its write state is pending, failed, or confirmed.
class EntitySyncBadge extends StatelessWidget {
  final WriteSyncStatus status;
  final VoidCallback? onRetry;

  const EntitySyncBadge({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case WriteSyncStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: RevoColors.warningSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RevoColors.warningAmber.withValues(alpha: 0.6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty_rounded, size: 12, color: RevoColors.warningText),
              SizedBox(width: 4),
              Text(
                'Pending sync',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RevoColors.warningText,
                ),
              ),
            ],
          ),
        );

      case WriteSyncStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: RevoColors.errorSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RevoColors.errorCrimson.withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 12, color: RevoColors.errorCrimson),
                SizedBox(width: 4),
                Text(
                  'Sync failed — Retry',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: RevoColors.errorCrimson,
                  ),
                ),
              ],
            ),
          ),
        );

      case WriteSyncStatus.confirmed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: RevoColors.successSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: RevoColors.successGreen.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 12, color: RevoColors.successText),
              SizedBox(width: 4),
              Text(
                'Synced',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: RevoColors.successText,
                ),
              ),
            ],
          ),
        );
    }
  }
}

// ── 7. Dashboard Sync Status Card (FR-12, FR-13) ──────────────────────────────

/// Operational card for Dashboards showing Connectivity, Freshness, Last Synced timestamp,
/// and pending writes count.
class SyncStatusCard extends StatelessWidget {
  final SyncStatusService? service;
  final VoidCallback? onReconcile;

  const SyncStatusCard({
    super.key,
    this.service,
    this.onReconcile,
  });

  @override
  Widget build(BuildContext context) {
    final syncService = service ?? SyncStatusService.instance;

    return StreamBuilder<SyncStatusSnapshot>(
      stream: syncService.watchSnapshot(),
      builder: (context, snapshot) {
        final snap = snapshot.data ?? syncService.currentSnapshot;
        final lastSyncedLabel =
            SyncTimestampFormatter.formatWithPrefix(snap.lastSyncedAt);

        final isOnline = snap.connectivity == ConnectivityState.online;
        final connLabel = isOnline
            ? 'Online'
            : (snap.connectivity == ConnectivityState.offline
                ? 'Offline'
                : 'Unknown');
        final connColor = isOnline
            ? RevoColors.successGreen
            : (snap.isOffline ? RevoColors.textTertiary : RevoColors.warningAmber);

        final freshLabel = snap.freshness == DataFreshness.fresh
            ? 'Fresh'
            : (snap.freshness == DataFreshness.stale ? 'Stale' : 'Unknown');
        final freshColor = snap.freshness == DataFreshness.fresh
            ? RevoColors.successGreen
            : (snap.freshness == DataFreshness.stale
                ? RevoColors.warningAmber
                : RevoColors.textTertiary);

        return Container(
          padding: const EdgeInsets.all(RevoSpacing.lg),
          decoration: BoxDecoration(
            color: RevoColors.cardBackground,
            borderRadius: RevoSpacing.borderRadiusCard,
            border: Border.all(color: RevoColors.borderDefault),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF171B26).withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.sync_alt_rounded,
                    size: 18,
                    color: RevoColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Synchronization Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: RevoColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Connectivity pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: connColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: connColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: connColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          connLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: connColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: RevoColors.surfaceDim, height: 1),
              const SizedBox(height: 12),
              // Last Synced row
              _StatusItemRow(
                icon: Icons.access_time_rounded,
                label: 'Last Synced',
                value: lastSyncedLabel.replaceFirst('Last synced: ', ''),
              ),
              const SizedBox(height: 8),
              // Freshness row
              _StatusItemRow(
                icon: Icons.verified_outlined,
                label: 'Data Freshness',
                value: freshLabel,
                valueColor: freshColor,
              ),
              const SizedBox(height: 8),
              // Pending writes row
              _StatusItemRow(
                icon: Icons.upload_outlined,
                label: 'Pending Writes',
                value: snap.pendingCount > 0
                    ? '${snap.pendingCount} queued'
                    : 'All confirmed',
                valueColor: snap.pendingCount > 0
                    ? RevoColors.warningText
                    : RevoColors.successGreen,
              ),
              if (snap.isOffline || snap.pendingCount > 0 || snap.isStale) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: RevoColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      snap.isOffline ? 'Offline — Showing saved data' : 'Sync / Reconcile',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: snap.isOffline
                        ? null
                        : (onReconcile ?? () => syncService.reconcilePending()),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusItemRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: RevoColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: RevoColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? RevoColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── 8. Empty Offline Schedule View (FR-12) ────────────────────────────────────

/// Displayed when offline and no cached schedule data is available.
class OfflineEmptyScheduleView extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;

  const OfflineEmptyScheduleView({
    super.key,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RevoSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: RevoColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: RevoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Offline — Showing saved data',
              style: RevoTypography.title2.copyWith(
                fontWeight: FontWeight.w700,
                color: RevoColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message ??
                    'No schedule data is stored locally yet. Connect to a network to fetch and cache your rehearsals.',
                style: RevoTypography.bodyMedium.copyWith(
                  color: RevoColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Check Connection'),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
