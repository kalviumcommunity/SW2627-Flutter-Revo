import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/rehearsal.dart';
import '../../services/firebase_schedule_service.dart';
import '../../services/schedule_service.dart';

/// FR-09: Personalized chronological schedule view for Cast Members.
/// FR-10: Real-time Firestore stream listener — UI updates instantly on any rehearsal change.
class MyScheduleScreen extends StatelessWidget {
  const MyScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleService = FirebaseScheduleService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule (FR-09, FR-10)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Personalized chronological schedule — live Firestore stream',
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<ScheduleSnapshot>(
        // FR-10: Real-time stream listener
        stream: scheduleService.watchMySchedule(),
        builder: (context, snapshot) {
          return _ScheduleBody(snapshot: snapshot);
        },
      ),
    );
  }
}

class _ScheduleBody extends StatelessWidget {
  final AsyncSnapshot<ScheduleSnapshot> snapshot;

  const _ScheduleBody({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load schedule',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${snapshot.error}',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final data = snapshot.data;
    if (data == null || data.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Upcoming Rehearsals',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your schedule is clear for now.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _SyncStatusBanner(snapshot: data),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                  Icons.live_tv,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Live Schedule · ${data.items.length} upcoming rehearsal${data.items.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList.builder(
            itemCount: data.items.length,
            itemBuilder: (context, index) {
              final rehearsal = data.items[index];
              return _RehearsalCard(rehearsal: rehearsal, index: index);
            },
          ),
        ),
      ],
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  final ScheduleSnapshot snapshot;

  const _SyncStatusBanner({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // FR-10: Visual sync state indicator
    if (snapshot.syncState == SyncState.offline) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF8EC),
          border: const Border(
            left: BorderSide(color: Color(0xFFF2B33D), width: 3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF2B33D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Viewing Cached Schedule',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7A5C00),
                    ),
                  ),
                  if (snapshot.lastSyncedAt != null)
                    Text(
                      'Last synced: ${_formatTime(snapshot.lastSyncedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A5C00),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.hasPendingWrites) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Syncing schedule changes…',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.lastSyncedAt != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Icon(Icons.wifi, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Live · Synced ${_formatTime(snapshot.lastSyncedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _RehearsalCard extends StatelessWidget {
  final Rehearsal rehearsal;
  final int index;

  const _RehearsalCard({required this.rehearsal, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = _isSameDay(rehearsal.startAt, now);
    final isTomorrow = _isSameDay(
        rehearsal.startAt, now.add(const Duration(days: 1)));
    final isPending = rehearsal.clientPending;

    final statusColor = rehearsal.status == RehearsalStatus.confirmed
        ? Colors.green.shade700
        : Colors.orange.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: isToday ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isToday
              ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date badge
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      _dayAbbrev(rehearsal.startAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${rehearsal.startAt.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _monthAbbrev(rehearsal.startAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TODAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        if (isTomorrow && !isToday)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TOMORROW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            'Production Rehearsal',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatTimeOfDay(rehearsal.startAt)} – ${_formatTimeOfDay(rehearsal.endAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rehearsal.venueId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rehearsal.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.sync,
                              size: 14,
                              color: theme.colorScheme.secondary),
                          const SizedBox(width: 2),
                          Text(
                            'Pending sync',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.people_outline,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${rehearsal.participantIds.length}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayAbbrev(DateTime dt) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];

  String _monthAbbrev(DateTime dt) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][dt.month - 1];

  String _formatTimeOfDay(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}
