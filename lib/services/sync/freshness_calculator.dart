import '../../core/enums/revo_enums.dart';

/// Centralized data freshness calculator and configurable policy for Revo (FR-12).
class FreshnessCalculator {
  /// Default data freshness threshold: 5 minutes.
  /// After 5 minutes without synchronization or when disconnected, schedule data
  /// is treated as potentially stale.
  static const Duration defaultFreshnessThreshold = Duration(minutes: 5);

  /// Evaluates data freshness according to connectivity, last sync timestamp, and elapsed time.
  static DataFreshness calculate({
    required ConnectivityState connectivity,
    required DateTime? lastSyncedAt,
    Duration threshold = defaultFreshnessThreshold,
    DateTime? now,
    bool hasSyncError = false,
  }) {
    // Offline data or failed syncs are always classified as stale (Scenario B).
    if (connectivity == ConnectivityState.offline || hasSyncError) {
      return DataFreshness.stale;
    }

    // If online but no authoritative sync has ever succeeded, freshness cannot be established.
    if (lastSyncedAt == null) {
      return DataFreshness.unknown;
    }

    // Connectivity unknown defaults to stale if unverified
    if (connectivity == ConnectivityState.unknown) {
      return DataFreshness.unknown;
    }

    final current = now ?? DateTime.now();
    final elapsed = current.difference(lastSyncedAt.toLocal());

    // If more than threshold has elapsed, data may be outdated
    if (elapsed > threshold) {
      return DataFreshness.stale;
    }

    return DataFreshness.fresh;
  }
}
