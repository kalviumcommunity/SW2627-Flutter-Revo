import 'package:flutter/material.dart';
import '../../core/enums/revo_enums.dart';
import '../../models/rehearsal.dart';
import '../../services/firebase_rehearsal_repository.dart';
import '../../services/firebase_schedule_service.dart';
import '../../services/rehearsal_repository.dart';
import '../../services/schedule_service.dart';

/// FR-09: Production-wide schedule view for Directors — full cast & venue overview.
/// FR-10: Real-time Firestore stream listener — all rehearsal changes propagate instantly.
class DirectorProductionScheduleScreen extends StatefulWidget {
  final String productionId;
  final String productionTitle;

  const DirectorProductionScheduleScreen({
    super.key,
    required this.productionId,
    required this.productionTitle,
  });

  @override
  State<DirectorProductionScheduleScreen> createState() =>
      _DirectorProductionScheduleScreenState();
}

class _DirectorProductionScheduleScreenState
    extends State<DirectorProductionScheduleScreen> {
  final FirebaseScheduleService _scheduleService = FirebaseScheduleService();
  final FirebaseRehearsalRepository _rehearsalRepo =
      FirebaseRehearsalRepository();

  bool _isCreating = false;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Production Schedule (FR-09, FR-10)',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              widget.productionTitle,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          // FR-10: Live badge
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              label: const Text('LIVE', style: TextStyle(fontSize: 11)),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMsg != null)
            MaterialBanner(
              content: Text(_errorMsg!),
              backgroundColor: theme.colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMsg = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<ScheduleSnapshot>(
              // FR-10: Real-time stream listener for production-wide schedule
              stream: _scheduleService
                  .watchProductionSchedule(widget.productionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null || data.items.isEmpty) {
                  return _EmptyProductionSchedule(
                    productionTitle: widget.productionTitle,
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ProductionSyncBanner(data: data),
                    ),
                    SliverToBoxAdapter(
                      child: _ScheduleSummaryBar(data: data),
                    ),
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList.builder(
                        itemCount: data.items.length,
                        itemBuilder: (context, index) {
                          final rehearsal = data.items[index];
                          return _DirectorRehearsalCard(
                            rehearsal: rehearsal,
                            onCancel: () =>
                                _handleCancel(rehearsal.rehearsalId),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreating ? null : _showAddRehearsalSheet,
        icon: _isCreating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: const Text('Schedule Rehearsal'),
      ),
    );
  }

  Future<void> _handleCancel(String rehearsalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Rehearsal?'),
        content: const Text(
            'This will cancel the rehearsal and remove it from all participant schedules. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Rehearsal'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _rehearsalRepo.cancelRehearsal(rehearsalId);
      } catch (e) {
        if (mounted) {
          setState(() => _errorMsg = e.toString());
        }
      }
    }
  }

  void _showAddRehearsalSheet() {
    final venueController = TextEditingController(text: 'Studio A - Main Stage');
    DateTime startAt = DateTime.now().add(const Duration(days: 1, hours: 10));
    DateTime endAt = DateTime.now().add(const Duration(days: 1, hours: 13));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 10),
                  Text(
                    'Schedule New Rehearsal',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Production: ${widget.productionTitle}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const Divider(height: 24),
              TextField(
                controller: venueController,
                decoration: const InputDecoration(
                  labelText: 'Venue',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Start Time'),
                subtitle: Text(_formatDateTime(startAt)),
                onTap: () async {
                  final picked = await showDateTimePicker(ctx, startAt);
                  if (picked != null) startAt = picked;
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('End Time'),
                subtitle: Text(_formatDateTime(endAt)),
                onTap: () async {
                  final picked = await showDateTimePicker(ctx, endAt);
                  if (picked != null) endAt = picked;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Create Rehearsal'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isCreating = true);
                    try {
                      await _rehearsalRepo.createRehearsal(
                        RehearsalInput(
                          productionId: widget.productionId,
                          venueId: venueController.text.trim(),
                          startAt: startAt,
                          endAt: endAt,
                          participantIds: [],
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        setState(() => _errorMsg = e.toString());
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isCreating = false);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${_dayAbbrev(dt)}, ${dt.day} ${_monthAbbrev(dt.month)} · '
        '${_padTime(dt.hour)}:${_padTime(dt.minute)}';
  }

  String _dayAbbrev(DateTime dt) =>
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
          [dt.weekday - 1];

  String _monthAbbrev(int month) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][month - 1];

  String _padTime(int v) => v.toString().padLeft(2, '0');

  Future<DateTime?> showDateTimePicker(
      BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

class _ProductionSyncBanner extends StatelessWidget {
  final ScheduleSnapshot data;

  const _ProductionSyncBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (data.syncState == SyncState.offline) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF8EC),
          border:
              const Border(left: BorderSide(color: Color(0xFFF2B33D), width: 3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFF2B33D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offline · Displaying cached production schedule. Last synced: ${_formatLastSync(data.lastSyncedAt)}',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF7A5C00)),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Icon(Icons.sensors, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Real-time stream active (FR-10)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime? dt) {
    if (dt == null) return 'unknown';
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ScheduleSummaryBar extends StatelessWidget {
  final ScheduleSnapshot data;

  const _ScheduleSummaryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirmed =
        data.items.where((r) => r.status == RehearsalStatus.confirmed).length;
    final proposed =
        data.items.where((r) => r.status == RehearsalStatus.proposed).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            icon: Icons.check_circle_outline,
            label: 'Confirmed',
            count: confirmed,
            color: Colors.green.shade700,
          ),
          Container(
              width: 1, height: 32, color: theme.colorScheme.outlineVariant),
          _SummaryItem(
            icon: Icons.pending_outlined,
            label: 'Proposed',
            count: proposed,
            color: Colors.orange.shade700,
          ),
          Container(
              width: 1, height: 32, color: theme.colorScheme.outlineVariant),
          _SummaryItem(
            icon: Icons.event_note_outlined,
            label: 'Total',
            count: data.items.length,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _DirectorRehearsalCard extends StatelessWidget {
  final Rehearsal rehearsal;
  final VoidCallback onCancel;

  const _DirectorRehearsalCard({
    required this.rehearsal,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfirmed = rehearsal.status == RehearsalStatus.confirmed;
    final statusColor =
        isConfirmed ? Colors.green.shade700 : Colors.orange.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: rehearsal.clientPending
            ? BorderSide(
                color: theme.colorScheme.secondary.withOpacity(0.6),
                width: 1,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rehearsal · ${_formatShortDate(rehearsal.startAt)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTimeOfDay(rehearsal.startAt)} – ${_formatTimeOfDay(rehearsal.endAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rehearsal.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    rehearsal.venueId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${rehearsal.participantIds.length} participant${rehearsal.participantIds.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (rehearsal.clientPending) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.sync,
                      size: 13, color: theme.colorScheme.secondary),
                  const SizedBox(width: 3),
                  Text(
                    'Pending sync',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: onCancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  String _formatTimeOfDay(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }
}

class _EmptyProductionSchedule extends StatelessWidget {
  final String productionTitle;

  const _EmptyProductionSchedule({required this.productionTitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined,
              size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No Rehearsals Scheduled',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            productionTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to schedule the first rehearsal.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
