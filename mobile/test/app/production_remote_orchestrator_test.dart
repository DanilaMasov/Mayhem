import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/app/composition/app_remote_orchestrator.dart';
import 'package:mayhem_mobile/app/composition/production_app_remote_orchestrator.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/core/auth/secure_session_store.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_coordinator.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_recovery_store.dart';
import 'package:mayhem_mobile/features/settings/application/remote_account_controller.dart';
import 'package:mayhem_mobile/features/sync/application/vnext_sync_coordinator.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test(
    'bootstrap retries with bounded backoff and restores account state',
    () async {
      final sync = _Synchronizer([
        SyncRunStatus.failed,
        SyncRunStatus.failed,
        SyncRunStatus.synchronized,
      ]);
      final sessions = _Sessions()..value = _session();
      final delays = <Duration>[];
      final orchestrator = ProductionAppRemoteOrchestrator(
        sync: sync,
        account: _account(sync, sessions: sessions),
        delay: (duration) async => delays.add(duration),
      );

      await orchestrator.bootstrap(AppCancellationSignal());

      expect(sync.triggers, [
        SyncTrigger.coldStart,
        SyncTrigger.coldStart,
        SyncTrigger.coldStart,
      ]);
      expect(delays, hasLength(2));
      expect(
        delays.every((delay) => delay < const Duration(seconds: 1)),
        isTrue,
      );
      expect(orchestrator.account.sessionAvailable, isTrue);
    },
  );

  test('cancelled bootstrap performs no remote operation', () async {
    final sync = _Synchronizer([SyncRunStatus.synchronized]);
    final cancellation = AppCancellationSignal()..cancel();
    final orchestrator = ProductionAppRemoteOrchestrator(
      sync: sync,
      account: _account(sync),
    );

    await expectLater(
      () => orchestrator.bootstrap(cancellation),
      throwsA(isA<AppOperationCancelled>()),
    );
    expect(sync.triggers, isEmpty);
  });

  test('bootstrap completes pending local wipe before remote sync', () async {
    final order = <String>[];
    final sessions = _Sessions();
    final recovery = _RecoveryStore()
      ..value = DataDeletionRecoveryMarker(
        receiptId: 'receipt',
        remoteUserId: 'remote-user',
        deletedAt: DateTime.utc(2026, 7, 15),
        stage: DataDeletionStage.secureSessionCleared,
      );
    final backend = _DeletionBackend(order, null);
    final sync = _Synchronizer([
      SyncRunStatus.synchronized,
    ], onCall: () => order.add('sync'));
    final account = RemoteAccountController(
      sessions: sessions,
      deletion: DeleteEverywhereCoordinator(
        backend: backend,
        sessions: sessions,
        recovery: recovery,
        clearLocalData: () async => order.add('local'),
      ),
      synchronize: (trigger) => sync.synchronize(trigger: trigger),
      clock: () => DateTime.utc(2026, 7, 15),
    );
    final orchestrator = ProductionAppRemoteOrchestrator(
      sync: sync,
      account: account,
    );

    await orchestrator.bootstrap(AppCancellationSignal());

    expect(order, ['local', 'sync']);
    expect(backend.calls, 0);
    expect(recovery.value, isNull);
  });

  test(
    'Delete Everywhere attempts sync then clears only after receipt',
    () async {
      final order = <String>[];
      final sync = _Synchronizer([
        SyncRunStatus.synchronized,
      ], onCall: () => order.add('sync'));
      final sessions = _Sessions(order: order)..value = _session();
      final account = _account(sync, sessions: sessions, order: order);
      await account.refreshAvailability();

      expect(await account.deleteEverywhere(), isTrue);
      expect(order, ['sync', 'remote', 'session', 'local']);
      expect(sessions.value, isNull);
      expect(account.sessionAvailable, isFalse);
    },
  );

  test('failed cloud deletion preserves session and local data', () async {
    final order = <String>[];
    final sync = _Synchronizer([SyncRunStatus.synchronized]);
    final sessions = _Sessions(order: order)..value = _session();
    final account = _account(
      sync,
      sessions: sessions,
      order: order,
      deleteFailure: StateError('offline'),
    );
    await account.refreshAvailability();

    expect(await account.deleteEverywhere(), isFalse);
    expect(order, ['remote']);
    expect(sessions.value, isNotNull);
    expect(account.errorCode, 'server_deletion_failed');
    expect(account.deletionRecoveryPending, isFalse);
  });

  test(
    'receipt mismatch preserves session and creates no recovery marker',
    () async {
      final order = <String>[];
      final sessions = _Sessions()..value = _session();
      final recovery = _RecoveryStore();
      final coordinator = DeleteEverywhereCoordinator(
        backend: _DeletionBackend(
          order,
          null,
          receiptRemoteUserId: 'different-user',
        ),
        sessions: sessions,
        recovery: recovery,
        clearLocalData: () async => order.add('local'),
      );

      await expectLater(
        coordinator.delete,
        throwsA(
          isA<DeleteEverywhereFailure>()
              .having((error) => error.code, 'code', 'receipt_mismatch')
              .having(
                (error) => error.recoveryPending,
                'recoveryPending',
                isFalse,
              ),
        ),
      );
      expect(order, ['remote']);
      expect(sessions.value, isNotNull);
      expect(recovery.value, isNull);
    },
  );

  test(
    'secure-session clear failure resumes without server deletion',
    () async {
      final order = <String>[];
      final sessions = _Sessions(order: order)
        ..value = _session()
        ..clearFailure = StateError('keychain unavailable');
      final recovery = _RecoveryStore();
      final backend = _DeletionBackend(order, null);
      final coordinator = DeleteEverywhereCoordinator(
        backend: backend,
        sessions: sessions,
        recovery: recovery,
        clearLocalData: () async => order.add('local'),
      );

      await expectLater(
        coordinator.delete,
        throwsA(
          isA<DeleteEverywhereFailure>()
              .having(
                (error) => error.code,
                'code',
                'secure_session_clear_failed',
              )
              .having(
                (error) => error.recoveryPending,
                'recoveryPending',
                isTrue,
              ),
        ),
      );
      expect(recovery.value?.stage, DataDeletionStage.cloudConfirmed);
      expect(sessions.value, isNotNull);
      expect(backend.calls, 1);

      sessions.clearFailure = null;
      await coordinator.delete();
      expect(backend.calls, 1);
      expect(sessions.value, isNull);
      expect(recovery.value, isNull);
      expect(order.last, 'local');
    },
  );

  test('local clear failure leaves durable wipe marker for retry', () async {
    final order = <String>[];
    final sessions = _Sessions(order: order)..value = _session();
    final recovery = _RecoveryStore();
    final backend = _DeletionBackend(order, null);
    var localAttempts = 0;
    final coordinator = DeleteEverywhereCoordinator(
      backend: backend,
      sessions: sessions,
      recovery: recovery,
      clearLocalData: () async {
        localAttempts += 1;
        if (localAttempts == 1) throw StateError('sqlite unavailable');
        order.add('local');
      },
    );

    await expectLater(
      coordinator.delete,
      throwsA(
        isA<DeleteEverywhereFailure>().having(
          (error) => error.code,
          'code',
          'local_data_clear_failed',
        ),
      ),
    );
    expect(sessions.value, isNull);
    expect(recovery.value?.stage, DataDeletionStage.secureSessionCleared);
    expect(backend.calls, 1);

    await coordinator.recoverPendingLocalWipe();
    expect(localAttempts, 2);
    expect(backend.calls, 1);
    expect(recovery.value, isNull);
  });

  test('marker cleanup failure remains recoverable after local wipe', () async {
    final order = <String>[];
    final sessions = _Sessions()..value = _session();
    final recovery = _RecoveryStore()
      ..clearFailure = StateError('secure storage busy');
    final backend = _DeletionBackend(order, null);
    var localAttempts = 0;
    final coordinator = DeleteEverywhereCoordinator(
      backend: backend,
      sessions: sessions,
      recovery: recovery,
      clearLocalData: () async => localAttempts += 1,
    );

    await expectLater(
      coordinator.delete,
      throwsA(
        isA<DeleteEverywhereFailure>().having(
          (error) => error.code,
          'code',
          'recovery_marker_clear_failed',
        ),
      ),
    );
    expect(localAttempts, 1);
    expect(recovery.value?.stage, DataDeletionStage.secureSessionCleared);

    recovery.clearFailure = null;
    await coordinator.delete();
    expect(localAttempts, 2);
    expect(backend.calls, 1);
    expect(recovery.value, isNull);
  });
}

RemoteAccountController _account(
  RemoteSynchronizer sync, {
  _Sessions? sessions,
  List<String>? order,
  Object? deleteFailure,
}) {
  final store = sessions ?? (_Sessions()..value = _session());
  final recovery = _RecoveryStore();
  return RemoteAccountController(
    sessions: store,
    deletion: DeleteEverywhereCoordinator(
      backend: _DeletionBackend(order ?? <String>[], deleteFailure),
      sessions: store,
      recovery: recovery,
      clearLocalData: () async => order?.add('local'),
    ),
    synchronize: (trigger) => sync.synchronize(trigger: trigger),
    clock: () => DateTime.utc(2026, 7, 15),
  );
}

class _Synchronizer implements RemoteSynchronizer {
  _Synchronizer(this.results, {this.onCall});

  final List<SyncRunStatus> results;
  final void Function()? onCall;
  final List<SyncTrigger> triggers = [];
  int _index = 0;

  @override
  Future<SyncRunResult> synchronize({
    SyncTrigger trigger = SyncTrigger.manual,
  }) async {
    triggers.add(trigger);
    onCall?.call();
    final status = results[_index.clamp(0, results.length - 1)];
    _index += 1;
    return SyncRunResult(
      status: status,
      trigger: trigger,
      uploadedCount: 0,
      retriedCount: status == SyncRunStatus.failed ? 1 : 0,
    );
  }
}

class _Sessions implements SecureSessionStore {
  _Sessions({this.order});
  final List<String>? order;
  RemoteAuthSession? value;
  Object? clearFailure;

  @override
  Future<void> clear() async {
    order?.add('session');
    if (clearFailure != null) throw clearFailure!;
    value = null;
  }

  @override
  Future<RemoteAuthSession?> read() async => value;

  @override
  Future<void> write(RemoteAuthSession session) async => value = session;
}

class _DeletionBackend implements VNextBackendGateway {
  _DeletionBackend(
    this.order,
    this.failure, {
    this.receiptRemoteUserId = 'remote-user',
  });
  final List<String> order;
  final Object? failure;
  final String receiptRemoteUserId;
  int calls = 0;

  @override
  Future<DataDeletionReceipt> deleteMyData() async {
    calls += 1;
    order.add('remote');
    if (failure != null) throw failure!;
    return DataDeletionReceipt(
      receiptId: 'receipt',
      remoteUserId: receiptRemoteUserId,
      deletedAt: DateTime.utc(2026, 7, 15),
      authIdentityDeleted: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecoveryStore implements DeleteEverywhereRecoveryStore {
  DataDeletionRecoveryMarker? value;
  Object? clearFailure;

  @override
  Future<void> clear() async {
    if (clearFailure != null) throw clearFailure!;
    value = null;
  }

  @override
  Future<DataDeletionRecoveryMarker?> read() async => value;

  @override
  Future<void> write(DataDeletionRecoveryMarker marker) async => value = marker;
}

RemoteAuthSession _session() => RemoteAuthSession(
  remoteUserId: 'remote-user',
  accessToken: 'access-secret',
  refreshToken: 'refresh-secret',
  expiresAt: DateTime.utc(2027),
  isAnonymous: true,
);
