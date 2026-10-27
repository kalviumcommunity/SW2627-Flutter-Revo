import 'dart:convert';
import 'dart:io';

import '../../core/enums/revo_enums.dart';
import '../../models/rehearsal.dart';
import 'pending_write_op.dart';

/// Lightweight, resilient persistent cache store for schedule data and sync metadata (FR-12, FR-13).
/// Uses file-backed JSON storage with automatic in-memory fallback.
class SyncCacheStore {
  final File? _storageFile;
  final bool _inMemoryOnly;

  DateTime? _lastSyncedAt;
  final List<Rehearsal> _cachedRehearsals = [];
  final Map<String, PendingWriteOp> _pendingOps = {};

  SyncCacheStore({File? customFile, this._inMemoryOnly = false})
    : _storageFile = customFile ?? _defaultStorageFile() {
    load();
  }

  static File? _defaultStorageFile() {
    try {
      final tempDir = Directory.systemTemp;
      return File('${tempDir.path}/revo_sync_cache.json');
    } catch (_) {
      return null;
    }
  }

  DateTime? get lastSyncedAt => _lastSyncedAt;
  List<Rehearsal> get cachedRehearsals => List.unmodifiable(_cachedRehearsals);
  List<PendingWriteOp> get pendingOps => List.unmodifiable(_pendingOps.values);

  /// Saves successful synchronization timestamp.
  void saveLastSyncedAt(DateTime timestamp) {
    _lastSyncedAt = timestamp;
    _persist();
  }

  /// Sets cached rehearsals and persists them locally.
  void saveRehearsals(List<Rehearsal> rehearsals) {
    _cachedRehearsals
      ..clear()
      ..addAll(rehearsals);
    _persist();
  }

  /// Adds or updates a pending write operation.
  void savePendingOp(PendingWriteOp op) {
    _pendingOps[op.operationId] = op;
    _persist();
  }

  /// Removes a confirmed or aborted operation.
  void removePendingOp(String operationId) {
    _pendingOps.remove(operationId);
    _persist();
  }

  /// Clears all pending operations.
  void clearPendingOps() {
    _pendingOps.clear();
    _persist();
  }

  /// Resets everything (used for test isolation).
  void reset() {
    _lastSyncedAt = null;
    _cachedRehearsals.clear();
    _pendingOps.clear();
    final file = _storageFile;
    if (!_inMemoryOnly && file != null && file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  /// Loads persisted cache from file.
  void load() {
    final file = _storageFile;
    if (_inMemoryOnly || file == null || !file.existsSync()) {
      return;
    }

    try {
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return;
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (data['lastSyncedAt'] != null) {
        _lastSyncedAt = DateTime.tryParse(data['lastSyncedAt'] as String);
      }

      if (data['rehearsals'] is List) {
        _cachedRehearsals.clear();
        for (final item in data['rehearsals'] as List) {
          if (item is Map<String, dynamic>) {
            final id =
                item['rehearsalId'] as String? ??
                'cached_${DateTime.now().millisecondsSinceEpoch}';
            _cachedRehearsals.add(Rehearsal.fromMap(item, id));
          }
        }
      }

      if (data['pendingOps'] is List) {
        _pendingOps.clear();
        for (final item in data['pendingOps'] as List) {
          if (item is Map<String, dynamic>) {
            final op = PendingWriteOp.fromMap(item);
            // CRITICAL: On restart, restored operations must remain pending and NEVER converted to confirmed!
            if (op.status == WriteSyncStatus.confirmed) {
              op.status = WriteSyncStatus.pending;
            }
            _pendingOps[op.operationId] = op;
          }
        }
      }
    } catch (_) {
      // In case of parsing error, retain empty/in-memory state safely
    }
  }

  void _persist() {
    final file = _storageFile;
    if (_inMemoryOnly || file == null) return;

    try {
      final payload = {
        'lastSyncedAt': _lastSyncedAt?.toIso8601String(),
        'rehearsals': _cachedRehearsals.map((r) {
          return {
            'rehearsalId': r.rehearsalId,
            'productionId': r.productionId,
            'venueId': r.venueId,
            'startAt': r.startAt.toIso8601String(),
            'endAt': r.endAt.toIso8601String(),
            'participantIds': r.participantIds,
            'status': r.status.name,
            'clientPending': r.clientPending,
            'createdBy': r.createdBy,
            'createdAt': r.createdAt.toIso8601String(),
            'updatedAt': r.updatedAt.toIso8601String(),
            if (r.title != null) 'title': r.title,
            if (r.notes != null) 'notes': r.notes,
          };
        }).toList(),
        'pendingOps': _pendingOps.values.map((op) => op.toMap()).toList(),
      };
      file.writeAsStringSync(jsonEncode(payload));
    } catch (_) {
      // In case of write error, fail quietly to in-memory behavior
    }
  }
}
