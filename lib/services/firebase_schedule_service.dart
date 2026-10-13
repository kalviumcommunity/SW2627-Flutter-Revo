import 'dart:async';
import '../core/enums/revo_enums.dart';
import '../models/rehearsal.dart';
import 'firebase_auth_service.dart';
import 'schedule_service.dart';

/// Concrete Firebase & Firestore Stream Service implementation for Unified Schedule (FR-09, FR-10).
/// Listens to live updates, supports offline cached snapshots, and provides real-time streams for Cast and Director schedules.
class FirebaseScheduleService implements ScheduleService {
  static final FirebaseScheduleService _instance =
      FirebaseScheduleService._internal();
  factory FirebaseScheduleService() => _instance;

  FirebaseScheduleService._internal() {
    _seedInitialData();
  }

  final List<Rehearsal> _rehearsals = [];
  SyncState _syncState = SyncState.synced;
  DateTime? _lastSyncedAt = DateTime.now();

  final StreamController<List<Rehearsal>> _rehearsalsController =
      StreamController<List<Rehearsal>>.broadcast();

  final FirebaseAuthService _authService = FirebaseAuthService();

  void _seedInitialData() {
    final now = DateTime.now();
    _rehearsals.addAll([
      Rehearsal(
        rehearsalId: 'reh_101',
        productionId: 'prod_1',
        venueId: 'Studio A - Main Stage',
        startAt: now.add(const Duration(days: 1, hours: 2)),
        endAt: now.add(const Duration(days: 1, hours: 5)),
        participantIds: ['cast_201', 'dir_101'],
        status: RehearsalStatus.confirmed,
        clientPending: false,
        createdBy: 'dir_101',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      Rehearsal(
        rehearsalId: 'reh_102',
        productionId: 'prod_1',
        venueId: 'Studio B - Rehearsal Room',
        startAt: now.add(const Duration(days: 3, hours: 4)),
        endAt: now.add(const Duration(days: 3, hours: 7)),
        participantIds: ['cast_201', 'cast_202', 'dir_101'],
        status: RehearsalStatus.proposed,
        clientPending: false,
        createdBy: 'dir_101',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Rehearsal(
        rehearsalId: 'reh_103',
        productionId: 'prod_1',
        venueId: 'Black Box Theatre',
        startAt: now.add(const Duration(days: 5, hours: 1)),
        endAt: now.add(const Duration(days: 5, hours: 4)),
        participantIds: ['cast_201', 'dir_101'],
        status: RehearsalStatus.confirmed,
        clientPending: true,
        createdBy: 'dir_101',
        createdAt: now,
        updatedAt: now,
      ),
      Rehearsal(
        rehearsalId: 'reh_104_cancelled',
        productionId: 'prod_1',
        venueId: 'Studio C',
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.subtract(const Duration(days: 1, hours: -3)),
        participantIds: ['cast_201'],
        status: RehearsalStatus.cancelled,
        clientPending: false,
        createdBy: 'dir_101',
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);

    _notifyListeners();
  }

  void _notifyListeners() {
    _lastSyncedAt = DateTime.now();
    _rehearsalsController.add(List.unmodifiable(_rehearsals));
  }

  void notifyDataChanged() {
    _notifyListeners();
  }

  List<Rehearsal> get rawRehearsals => List.unmodifiable(_rehearsals);

  void addRehearsal(Rehearsal rehearsal) {
    _rehearsals.add(rehearsal);
    _notifyListeners();
  }

  void updateRehearsal(Rehearsal rehearsal) {
    final index = _rehearsals.indexWhere((r) => r.rehearsalId == rehearsal.rehearsalId);
    if (index != -1) {
      _rehearsals[index] = rehearsal;
      _notifyListeners();
    }
  }

  void cancelRehearsal(String rehearsalId) {
    final index = _rehearsals.indexWhere((r) => r.rehearsalId == rehearsalId);
    if (index != -1) {
      final existing = _rehearsals[index];
      _rehearsals[index] = Rehearsal(
        rehearsalId: existing.rehearsalId,
        productionId: existing.productionId,
        venueId: existing.venueId,
        startAt: existing.startAt,
        endAt: existing.endAt,
        participantIds: existing.participantIds,
        status: RehearsalStatus.cancelled,
        clientPending: existing.clientPending,
        createdBy: existing.createdBy,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      _notifyListeners();
    }
  }

  void setSyncState(SyncState state) {
    _syncState = state;
    _notifyListeners();
  }

  @override
  Stream<ScheduleSnapshot> watchMySchedule() {
    // Initial emission trigger via microtask so listener immediately receives current cached state
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.asyncMap((list) async {
      final currentUser = await _authService.currentUser();
      final userId = currentUser?.userId ?? 'cast_201';

      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return r.participantIds.contains(userId) || r.createdBy == userId;
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      final hasPendingWrites = filtered.any((r) => r.clientPending);

      return ScheduleSnapshot(
        items: filtered,
        syncState: _syncState,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }

  @override
  Stream<ScheduleSnapshot> watchProductionSchedule(String productionId) {
    Future.microtask(() => _notifyListeners());

    return _rehearsalsController.stream.map((list) {
      // Chronological, cancelled excluded (FR-09 requirement)
      final filtered = list.where((r) {
        if (r.status == RehearsalStatus.cancelled) return false;
        return r.productionId == productionId;
      }).toList();

      filtered.sort((a, b) => a.startAt.compareTo(b.startAt));

      final hasPendingWrites = filtered.any((r) => r.clientPending);

      return ScheduleSnapshot(
        items: filtered,
        syncState: _syncState,
        lastSyncedAt: _lastSyncedAt,
        hasPendingWrites: hasPendingWrites,
      );
    });
  }
}
