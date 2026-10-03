import '../core/enums/revo_enums.dart';
import '../models/rehearsal.dart';

class ScheduleSnapshot {
  final List<Rehearsal> items; // chronological, cancelled excluded
  final SyncState syncState;
  final DateTime? lastSyncedAt;
  final bool hasPendingWrites;

  ScheduleSnapshot({
    required this.items,
    required this.syncState,
    this.lastSyncedAt,
    required this.hasPendingWrites,
  });
}

abstract class ScheduleService {
  Stream<ScheduleSnapshot> watchMySchedule(); // Cast (and Director's own)
  Stream<ScheduleSnapshot> watchProductionSchedule(String productionId); // Director
}
