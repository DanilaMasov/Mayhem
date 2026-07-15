import 'dart:developer' as developer;

import '../../../core/auth/secure_session_store.dart';
import '../../sync/domain/backend_models.dart';
import 'delete_everywhere_recovery_store.dart';

class DeleteEverywhereFailure implements Exception {
  const DeleteEverywhereFailure({
    required this.stage,
    required this.code,
    required this.recoveryPending,
  });

  final DataDeletionStage stage;
  final String code;
  final bool recoveryPending;

  @override
  String toString() => 'Delete Everywhere failed at ${stage.name}: $code';
}

class DeleteEverywhereCoordinator {
  DeleteEverywhereCoordinator({
    required this.backend,
    required this.sessions,
    required this.recovery,
    required this.clearLocalData,
  });

  final VNextBackendGateway backend;
  final SecureSessionStore sessions;
  final DeleteEverywhereRecoveryStore recovery;
  final Future<void> Function() clearLocalData;
  DataDeletionStage? _stage;
  DataDeletionRecoveryMarker? _volatileRecovery;

  DataDeletionStage? get stage => _stage;

  Future<DataDeletionReceipt> delete() async {
    final persisted = await recovery.read();
    final pending = persisted ?? _volatileRecovery;
    if (pending != null) {
      if (persisted == null) await _persistConfirmedMarker(pending);
      return _resume(pending);
    }
    final session = await sessions.read();
    if (session == null) throw StateError('Remote session is unavailable');
    _stage = DataDeletionStage.serverDeletion;
    late final DataDeletionReceipt receipt;
    try {
      receipt = await backend.deleteMyData();
    } catch (_) {
      throw const DeleteEverywhereFailure(
        stage: DataDeletionStage.serverDeletion,
        code: 'server_deletion_failed',
        recoveryPending: false,
      );
    }
    if (receipt.remoteUserId != session.remoteUserId ||
        !receipt.authIdentityDeleted) {
      throw const DeleteEverywhereFailure(
        stage: DataDeletionStage.serverDeletion,
        code: 'receipt_mismatch',
        recoveryPending: false,
      );
    }
    final marker = DataDeletionRecoveryMarker(
      receiptId: receipt.receiptId,
      remoteUserId: receipt.remoteUserId,
      deletedAt: receipt.deletedAt,
      stage: DataDeletionStage.cloudConfirmed,
    );
    _stage = marker.stage;
    _volatileRecovery = marker;
    await _persistConfirmedMarker(marker);
    return _resume(marker);
  }

  Future<DataDeletionReceipt?> recoverPendingLocalWipe() async {
    final persisted = await recovery.read();
    final marker = persisted ?? _volatileRecovery;
    if (marker == null) return null;
    if (persisted == null) await _persistConfirmedMarker(marker);
    return _resume(marker);
  }

  Future<DataDeletionReceipt> _resume(DataDeletionRecoveryMarker marker) async {
    var current = marker;
    if (current.stage == DataDeletionStage.cloudConfirmed) {
      _stage = current.stage;
      try {
        await sessions.clear();
      } catch (_) {
        throw const DeleteEverywhereFailure(
          stage: DataDeletionStage.cloudConfirmed,
          code: 'secure_session_clear_failed',
          recoveryPending: true,
        );
      }
      current = current.copyWith(stage: DataDeletionStage.secureSessionCleared);
      _stage = current.stage;
      _volatileRecovery = current;
      try {
        await recovery.write(current);
      } catch (_) {
        throw const DeleteEverywhereFailure(
          stage: DataDeletionStage.secureSessionCleared,
          code: 'recovery_marker_update_failed',
          recoveryPending: true,
        );
      }
    }
    try {
      await clearLocalData();
    } catch (_) {
      throw const DeleteEverywhereFailure(
        stage: DataDeletionStage.secureSessionCleared,
        code: 'local_data_clear_failed',
        recoveryPending: true,
      );
    }
    _stage = DataDeletionStage.localDataCleared;
    try {
      await recovery.clear();
    } catch (_) {
      throw const DeleteEverywhereFailure(
        stage: DataDeletionStage.localDataCleared,
        code: 'recovery_marker_clear_failed',
        recoveryPending: true,
      );
    }
    _volatileRecovery = null;
    developer.log(
      'Cloud deletion confirmed; secure session and local data cleared',
      name: 'mayhem.privacy',
    );
    return DataDeletionReceipt(
      receiptId: current.receiptId,
      remoteUserId: current.remoteUserId,
      deletedAt: current.deletedAt,
      authIdentityDeleted: true,
    );
  }

  Future<void> _persistConfirmedMarker(
    DataDeletionRecoveryMarker marker,
  ) async {
    try {
      await recovery.write(marker);
    } catch (_) {
      throw DeleteEverywhereFailure(
        stage: marker.stage,
        code: 'recovery_marker_write_failed',
        recoveryPending: true,
      );
    }
  }
}
