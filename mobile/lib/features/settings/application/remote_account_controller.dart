import 'package:flutter/foundation.dart';

import '../../../core/auth/secure_session_store.dart';
import '../../sync/application/vnext_sync_coordinator.dart';
import 'delete_everywhere_coordinator.dart';

enum RemoteAccountStatus { unavailable, ready, syncing, deleting, failed }

class RemoteAccountController extends ChangeNotifier {
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

  RemoteAccountStatus get status => _status;
  String? get errorCode => _errorCode;
  bool get sessionAvailable => _sessionAvailable;
  bool get busy =>
      _status == RemoteAccountStatus.syncing ||
      _status == RemoteAccountStatus.deleting;
  bool get canDeleteEverywhere => _sessionAvailable && !busy;

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
      await synchronize(SyncTrigger.manual);
      await deletion.delete();
      _sessionAvailable = false;
      _setStatus(RemoteAccountStatus.unavailable);
      return true;
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
