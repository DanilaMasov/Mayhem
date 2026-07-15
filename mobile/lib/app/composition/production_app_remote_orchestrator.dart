import 'dart:math';

import '../../features/settings/application/remote_account_controller.dart';
import '../../features/sync/application/vnext_sync_coordinator.dart';
import 'app_remote_orchestrator.dart';

class RemoteSyncUnavailable implements Exception {
  const RemoteSyncUnavailable();
}

class ProductionAppRemoteOrchestrator implements AppRemoteOrchestrator {
  ProductionAppRemoteOrchestrator({
    required this.sync,
    required this.account,
    Random? random,
    Future<void> Function(Duration duration)? delay,
  }) : _random = random ?? Random.secure(),
       _delay = delay ?? Future<void>.delayed;

  final RemoteSynchronizer sync;
  final RemoteAccountController account;
  final Random _random;
  final Future<void> Function(Duration duration) _delay;

  @override
  bool get enabled => true;

  @override
  String? get disabledReason => null;

  @override
  Future<void> bootstrap(AppCancellationSignal cancellation) async {
    await account.recoverPendingDeletion();
    cancellation.throwIfCancelled();
    await _run(
      trigger: SyncTrigger.coldStart,
      maximumAttempts: 3,
      cancellation: cancellation,
    );
    cancellation.throwIfCancelled();
    await account.refreshAvailability();
  }

  @override
  Future<void> onForeground(AppCancellationSignal cancellation) async {
    await _run(
      trigger: SyncTrigger.foreground,
      maximumAttempts: 2,
      cancellation: cancellation,
    );
    cancellation.throwIfCancelled();
    await account.refreshAvailability();
  }

  Future<void> _run({
    required SyncTrigger trigger,
    required int maximumAttempts,
    required AppCancellationSignal cancellation,
  }) async {
    for (var attempt = 1; attempt <= maximumAttempts; attempt += 1) {
      cancellation.throwIfCancelled();
      final result = await sync.synchronize(trigger: trigger);
      cancellation.throwIfCancelled();
      if (result.status == SyncRunStatus.synchronized) return;
      if (attempt == maximumAttempts) throw const RemoteSyncUnavailable();
      final exponentialMilliseconds = 250 * (1 << (attempt - 1));
      final jitterMilliseconds = _random.nextInt(151);
      await _delay(
        Duration(milliseconds: exponentialMilliseconds + jitterMilliseconds),
      );
    }
  }

  @override
  Future<void> close() async {}
}
