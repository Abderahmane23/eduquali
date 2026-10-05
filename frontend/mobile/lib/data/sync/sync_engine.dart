// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_enums.dart';
import '../../core/network/network_status_service.dart';
import '../local/database/app_database.dart';
import '../remote/sync_api.dart';

/// État de la synchronisation, expose a l'interface.
class SyncState {
  const SyncState({
    this.running = false,
    this.pending = 0,
    this.conflicts = 0,
    this.failed = 0,
    this.lastSyncAt,
    this.lastError,
  });

  final bool running;
  final int pending;
  final int conflicts;
  final int failed;
  final DateTime? lastSyncAt;
  final String? lastError;

  bool get hasPendingWork => pending > 0 || failed > 0;

  SyncState copyWith({
    bool? running,
    int? pending,
    int? conflicts,
    int? failed,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearError = false,
  }) => SyncState(
    running: running ?? this.running,
    pending: pending ?? this.pending,
    conflicts: conflicts ?? this.conflicts,
    failed: failed ?? this.failed,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    lastError: clearError ? null : (lastError ?? this.lastError),
  );
}

/// File de synchronisation et moteur de push/pull (§43, §44).
///
/// Principe appliqué : « Local first → Sync later » (§41). Toute action
/// utilisateur est écrite en base locale puis empilee ici ; la
/// synchronisation n'a lieu que lorsque le serveur est reellement joignable
/// (§42).
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required NetworkStatusService network,
    required SyncApi api,
    required String deviceId,
  }) : _db = database,
       _network = network,
       _api = api,
       _deviceId = deviceId;

  final AppDatabase _db;
  final NetworkStatusService _network;
  final SyncApi _api;
  final String _deviceId;

  static const _cursorKey = 'sync_cursor';
  static const _lastSyncKey = 'sync_last_at';

  final _stateController = StreamController<SyncState>.broadcast();
  SyncState _state = const SyncState();
  Timer? _timer;
  StreamSubscription<NetworkState>? _networkSub;
  bool _busy = false;

  SyncState get state => _state;
  Stream<SyncState> get stream => _stateController.stream;

  Future<void> start() async {
    await _refreshCounters();
    _networkSub = _network.stream.listen((state) {
      // Une reprise de connexion declenche immediatement un cycle (§44).
      if (state.canSync) unawaited(synchronize());
    });
    _timer = Timer.periodic(
      AppConstants.syncInterval,
      (_) => unawaited(synchronize()),
    );
  }

  /// Empile une operation locale (§43).
  Future<void> enqueue({
    required String entity,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) async {
    await _db
        .into(_db.syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            entity: entity,
            entityId: entityId,
            operation: operation.code,
            payload: jsonEncode({
              ...payload,
              'deviceId': _deviceId,
              'clientUpdatedAt': DateTime.now().toIso8601String(),
            }),
          ),
        );
    await _refreshCounters();

    // Tentative opportuniste : sans serveur, l'operation reste en attente.
    if (_network.state.canSync) unawaited(synchronize());
  }

  /// Cycle complet : push des modifications locales puis pull serveur (§44).
  Future<void> synchronize() async {
    if (_busy) return;
    if (!_network.state.canSync) return;

    _busy = true;
    _emit(_state.copyWith(running: true, clearError: true));

    try {
      await _push();
      await _pull();
      final now = DateTime.now();
      await _db.writeMeta(_lastSyncKey, now.toIso8601String());
      _emit(_state.copyWith(running: false, lastSyncAt: now));
    } catch (error) {
      _emit(_state.copyWith(running: false, lastError: _describe(error)));
    } finally {
      _busy = false;
      await _refreshCounters();
    }
  }

  Future<void> _push() async {
    final batch =
        await (_db.select(_db.syncQueue)
              ..where(
                (t) =>
                    t.status.equals(SyncItemStatus.pending.code) |
                    t.status.equals(SyncItemStatus.failed.code),
              )
              ..where(
                (t) => t.retryCount.isSmallerThanValue(
                  AppConstants.syncMaxRetries,
                ),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(AppConstants.syncBatchSize))
            .get();

    if (batch.isEmpty) return;

    await _mark(batch.map((e) => e.id), SyncItemStatus.inFlight);

    final results = await _api.push([
      for (final item in batch)
        SyncPushItem(
          localId: item.id,
          entity: item.entity,
          entityId: item.entityId,
          operation: item.operation,
          payload: jsonDecode(item.payload) as Map<String, dynamic>,
        ),
    ]);

    for (final result in results) {
      switch (result.outcome) {
        case SyncOutcome.applied:
          await (_db.update(
            _db.syncQueue,
          )..where((t) => t.id.equals(result.localId))).write(
            SyncQueueCompanion(
              status: Value(SyncItemStatus.done.code),
              updatedAt: Value(DateTime.now()),
            ),
          );
          await _clearDirtyFlag(result.entity, result.entityId);

        case SyncOutcome.conflict:
          // Le MVP signale le conflit plutot que d'ecraser une modification
          // silencieusement (§45).
          await (_db.update(
            _db.syncQueue,
          )..where((t) => t.id.equals(result.localId))).write(
            SyncQueueCompanion(
              status: Value(SyncItemStatus.conflict.code),
              lastError: const Value('CONFLICT'),
              updatedAt: Value(DateTime.now()),
            ),
          );

        case SyncOutcome.failed:
          final row = batch.firstWhere((e) => e.id == result.localId);
          await (_db.update(
            _db.syncQueue,
          )..where((t) => t.id.equals(result.localId))).write(
            SyncQueueCompanion(
              status: Value(SyncItemStatus.failed.code),
              retryCount: Value(row.retryCount + 1),
              lastError: Value(result.message ?? 'Echec inconnu'),
              updatedAt: Value(DateTime.now()),
            ),
          );
      }
    }
  }

  /// Recuperation des changements serveur depuis le dernier curseur (§44).
  Future<void> _pull() async {
    final cursor = await _db.readMeta(_cursorKey);
    final response = await _api.pull(cursor);
    if (response.changes.isEmpty) {
      if (response.cursor != null) {
        await _db.writeMeta(_cursorKey, response.cursor!);
      }
      return;
    }

    // L'application des changements serveur est confiee aux depots concernes
    // lorsque l'API sera disponible ; le curseur n'avance qu'après succes.
    if (kDebugMode) {
      debugPrint('[sync] ${response.changes.length} changement(s) recu(s)');
    }
    if (response.cursor != null) {
      await _db.writeMeta(_cursorKey, response.cursor!);
    }
  }

  /// Retire le drapeau « modification locale non poussee ».
  Future<void> _clearDirtyFlag(String entity, String entityId) async {
    final statement = switch (entity) {
      'teacher' => 'UPDATE teachers SET dirty = 0 WHERE id = ?',
      'user' => 'UPDATE users SET dirty = 0 WHERE id = ?',
      'application' => 'UPDATE applications SET dirty = 0 WHERE id = ?',
      'test_session' => 'UPDATE test_sessions SET dirty = 0 WHERE id = ?',
      'document' => 'UPDATE teacher_documents SET dirty = 0 WHERE id = ?',
      'message' => 'UPDATE messages SET dirty = 0 WHERE id = ?',
      'job' => 'UPDATE jobs SET dirty = 0 WHERE id = ?',
      _ => null,
    };
    if (statement == null) return;
    await _db.customStatement(statement, [entityId]);
  }

  Future<void> _mark(Iterable<int> ids, SyncItemStatus status) async {
    for (final id in ids) {
      await (_db.update(_db.syncQueue)..where((t) => t.id.equals(id))).write(
        SyncQueueCompanion(
          status: Value(status.code),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<void> _refreshCounters() async {
    final rows = await _db
        .customSelect(
          'SELECT status, COUNT(*) AS total FROM sync_queue GROUP BY status',
        )
        .get();

    var pending = 0;
    var conflicts = 0;
    var failed = 0;
    for (final row in rows) {
      final status = row.read<String>('status');
      final total = row.read<int>('total');
      if (status == SyncItemStatus.pending.code ||
          status == SyncItemStatus.inFlight.code) {
        pending += total;
      } else if (status == SyncItemStatus.conflict.code) {
        conflicts += total;
      } else if (status == SyncItemStatus.failed.code) {
        failed += total;
      }
    }

    final lastRaw = await _db.readMeta(_lastSyncKey);
    _emit(
      _state.copyWith(
        pending: pending,
        conflicts: conflicts,
        failed: failed,
        lastSyncAt: lastRaw == null ? null : DateTime.tryParse(lastRaw),
      ),
    );
  }

  /// Remet en file les operations en echec — action manuelle de l'utilisateur.
  Future<void> retryFailed() async {
    await (_db.update(
      _db.syncQueue,
    )..where((t) => t.status.equals(SyncItemStatus.failed.code))).write(
      SyncQueueCompanion(
        status: Value(SyncItemStatus.pending.code),
        retryCount: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _refreshCounters();
    await synchronize();
  }

  void _emit(SyncState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  String _describe(Object error) =>
      error is SyncApiException ? error.message : 'Synchronisation impossible';

  Future<void> dispose() async {
    _timer?.cancel();
    await _networkSub?.cancel();
    await _stateController.close();
  }
}
