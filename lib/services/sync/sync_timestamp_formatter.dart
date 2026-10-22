/// Utility for formatting human-readable last-sync timestamps (FR-12).
class SyncTimestampFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Formats [dt] into human-readable relative or absolute date-time representation.
  /// If [dt] is null, returns "Never".
  static String format(DateTime? dt, {DateTime? now}) {
    if (dt == null) return 'Never';

    final current = now ?? DateTime.now();
    final localDt = dt.toLocal();
    final diff = current.difference(localDt);

    // If future or within last 60 seconds
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Just now';
    }

    // Within the last hour
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins min ago';
    }

    // Within same calendar day and less than 24 hours
    if (diff.inHours < 24 &&
        localDt.year == current.year &&
        localDt.month == current.month &&
        localDt.day == current.day) {
      return 'Today, ${_formatTime(localDt)}';
    }

    // Older timestamps (e.g., "19 Oct, 10:45 AM")
    final day = localDt.day;
    final month = _months[localDt.month - 1];
    return '$day $month, ${_formatTime(localDt)}';
  }

  /// Convenience method that prepends a prefix (default "Last synced: ").
  /// If [dt] is null, returns "Last synced: Never".
  static String formatWithPrefix(
    DateTime? dt, {
    DateTime? now,
    String prefix = 'Last synced: ',
  }) {
    return '$prefix${format(dt, now: now)}';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}
