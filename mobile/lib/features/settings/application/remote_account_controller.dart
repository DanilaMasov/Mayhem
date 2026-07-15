import 'package:flutter/foundation.dart';

import '../../../core/auth/secure_session_store.dart';
import '../../sync/application/vnext_sync_coordinator.dart';
import 'delete_everywhere_coordinator.dart';
import 'delete_everywhere_recovery_store.dart';

enum RemoteAccountStatus {
  unavailable,
  ready,
  syncing,
  deleting,
  recoveryRequired,
  failed,
}

abstract interface class RemoteAccountDiagnostics implements Listenable {
  RemoteAccountStatus get status;

  String? get errorCode;

  bool get sessionAvailable;
}

class RemoteAccountController extends ChangeNotifier
    implements RemoteAccountDiagnostics {
  RemoteAccountController({
    required this.sessions,
    required this.deletion,
    required this.synchronize,
    required this.clock,
  });

  final SecureSessionStore sessions;
  final DeleteEverywhereCoordinator deletion;
  final Future<SyncRunResult> Function(SyncTrigger trigger) synchronize;
  final DateTime Function() clock;

  RemoteAccountStatus _status = RemoteAccountStatus.unavailable;
  String? _errorCode;
  bool _sessionAvailable = false;
  bool _deletionRecoveryPending = false;

  @override
  RemoteAccountStatus get status => _status;
  @override
  String? get errorCode => _errorCode;
  @override
  bool get sessionAvailable => _sessionAvailable;
  bool get deletionRecoveryPending => _deletionRecoveryPending;
  bool get busy =>
      _status == RemoteAccountStatus.syncing ||
      _status == RemoteAccountStatus.deleting;
  bool get canDeleteEverywhere =>
      (_sessionAvailable || _deletionRecoveryPending) && !busy;

  Future<void> recoverPendingDeletion() async {
    try {
      final receipt = await deletion.recoverPendingLocalWipe();
      if (receipt == null) return;
      _deletionRecoveryPending = false;
      _sessionAvailable = false;
      _setStatus(RemoteAccountStatus.unavailable);
    } on DeleteEverywhereFailure catch (error) {
      _deletionRecoveryPending = error.recoveryPending;
      _sessionAvailable =
          error.stage.index < DataDeletionStage.secureSessionCleared.index;
      _setStatus(RemoteAccountStatus.recoveryRequired, errorCode: error.code);
      rethrow;
    }
  }

  Future<void> refreshAvailability() async {
    try {
      _sessionAvailable =
          (await sessions.read())?.isUsableAt(clock().toUtc()) == true;
      _setStatus(
        _sessionAvailable
            ? RemoteAccountStatus.ready
            : RemoteAccountStatus.unavailable,
      );
    } catch (error) {
      _sessionAvailable = false;
      _setStatus(
        RemoteAccountStatus.failed,
        errorCode: 'session_read_${error.runtimeType}',
      );
      rethrow;
    }
  }

  Future<SyncRunResult> retrySync() async {
    if (busy) {
      return const SyncRunResult(
        status: SyncRunStatus.failed,
        trigger: SyncTrigger.manual,
        uploadedCount: 0,
        retriedCount: 0,
      );
    }
    _setStatus(RemoteAccountStatus.syncing);
    try {
      final result = await synchronize(SyncTrigger.manual);
      await refreshAvailability();
      if (result.status == SyncRunStatus.failed) {
        _setStatus(RemoteAccountStatus.failed, errorCode: 'manual_sync_failed');
      }
      return result;
    } catch (error) {
      _setStatus(
        RemoteAccountStatus.failed,
        errorCode: 'manual_sync_${error.runtimeType}',
      );
      return const SyncRunResult(
        status: SyncRunStatus.failed,
        trigger: SyncTrigger.manual,
        uploadedCount: 0,
        retriedCount: 0,
      );
    }
  }

  Future<bool> deleteEverywhere() async {
    if (!canDeleteEverywhere) return false;
    _setStatus(RemoteAccountStatus.deleting);
    try {
      if (!_deletionRecoveryPending) {
        await synchronize(SyncTrigger.manual);
      }
      await deletion.delete();
      _deletionRecoveryPending = false;
      _sessionAvailable = false;
      _setStatus(RemoteAccountStatus.unavailable);
      return true;
    } on DeleteEverywhereFailure catch (error) {
      _deletionRecoveryPending = error.recoveryPending;
      _sessionAvailable =
          error.stage.index < DataDeletionStage.secureSessionCleared.index;
      _setStatus(
        error.recoveryPending
            ? RemoteAccountStatus.recoveryRequired
            : RemoteAccountStatus.failed,
        errorCode: error.code,
      );
      return false;
    } catch (error) {
      _setStatus(
        RemoteAccountStatus.failed,
        errorCode: 'delete_everywhere_${error.runtimeType}',
      );
      return false;
    }
  }

  void _setStatus(RemoteAccountStatus status, {String? errorCode}) {
    if (_status == status && _errorCode == errorCode) return;
    _status = status;
    _errorCode = errorCode;
    notifyListeners();
  }
}
