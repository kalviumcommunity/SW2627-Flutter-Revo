import '../core/enums/revo_enums.dart';
import '../core/errors/revo_exception.dart';

abstract class SyncService {
  Stream<SyncState> watchSyncState();
  Stream<DateTime?> watchLastSyncedAt();
  Future<List<Conflict>> reconcilePending(); // called on reconnect
}
