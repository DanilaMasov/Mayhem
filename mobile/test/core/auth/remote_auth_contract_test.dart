import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/auth/account_link_coordinator.dart';
import 'package:mayhem_mobile/core/auth/anonymous_session_coordinator.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_gateway.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/core/auth/secure_session_store.dart';
import 'package:mayhem_mobile/core/identity/local_identity_repository.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_coordinator.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';

void main() {
  test('session validation and diagnostics never expose tokens', () {
    final session = _session();

    expect(session.toString(), contains('<redacted>'));
    expect(session.toString(), isNot(contains('access-secret')));
    expect(session.toString(), isNot(contains('refresh-secret')));
    expect(session.isUsableAt(DateTime.utc(2026, 7, 13, 11)), isTrue);
    expect(session.isUsableAt(DateTime.utc(2026, 7, 13, 11, 59, 30)), isFalse);
  });

  test(
    'anonymous session is created once and refreshed without identity drift',
    () async {
      final store = _SessionStore();
      final gateway = _AuthGateway(created: _session());
      final coordinator = AnonymousSessionCoordinator(
        gateway: gateway,
        store: store,
      );

      final first = await coordinator.ensureSession(
        DateTime.utc(2026, 7, 13, 10),
      );
      final second = await coordinator.ensureSession(
        DateTime.utc(2026, 7, 13, 10, 30),
      );

      expect(first.remoteUserId, second.remoteUserId);
      expect(gateway.signInCount, 1);
      expect(gateway.refreshCount, 0);
      expect(store.writeCount, 1);
    },
  );

  test(
    'account linking preserves remote identity before binding local identity',
    () async {
      final store = _SessionStore()..value = _session();
      final gateway = _AuthGateway(
        created: _session(),
        linked: _session(isAnonymous: false),
      );
      final binding = _IdentityBinding();
      final coordinator = AccountLinkCoordinator(
        gateway: gateway,
        sessions: store,
        identityBinding: binding,
        clock: () => DateTime.utc(2026, 7, 13, 12),
      );

      await coordinator.link(ExternalIdentityProvider.apple);

      expect(store.value?.isAnonymous, isFalse);
      expect(binding.remoteUserId, 'remote-user');
    },
  );

  test('identity drift aborts account linking before local binding', () async {
    final store = _SessionStore()..value = _session();
    final gateway = _AuthGateway(
      created: _session(),
      linked: _session(remoteUserId: 'different-user', isAnonymous: false),
    );
    final binding = _IdentityBinding();
    final coordinator = AccountLinkCoordinator(
      gateway: gateway,
      sessions: store,
      identityBinding: binding,
      clock: DateTime.now,
    );

    await expectLater(
      () => coordinator.link(ExternalIdentityProvider.google),
      throwsStateError,
    );
    expect(binding.remoteUserId, isNull);
    expect(store.value?.remoteUserId, 'remote-user');
  });

  test(
    'Delete Everywhere clears session and local data only after receipt',
    () async {
      final order = <String>[];
      final sessions = _SessionStore(order: order)..value = _session();
      final backend = _DeletionBackend(order: order);
      final coordinator = DeleteEverywhereCoordinator(
        backend: backend,
        sessions: sessions,
        clearLocalData: () async => order.add('local'),
      );

      final receipt = await coordinator.delete();

      expect(receipt.authIdentityDeleted, isTrue);
      expect(order, ['remote', 'session', 'local']);
      expect(sessions.value, isNull);
    },
  );

  test(
    'failed cloud deletion preserves secure session and local data',
    () async {
      final order = <String>[];
      final sessions = _SessionStore(order: order)..value = _session();
      final coordinator = DeleteEverywhereCoordinator(
        backend: _DeletionBackend(order: order, failure: StateError('offline')),
        sessions: sessions,
        clearLocalData: () async => order.add('local'),
      );

      await expectLater(coordinator.delete, throwsStateError);

      expect(order, ['remote']);
      expect(sessions.value, isNotNull);
    },
  );
}

RemoteAuthSession _session({
  String remoteUserId = 'remote-user',
  bool isAnonymous = true,
}) => RemoteAuthSession(
  remoteUserId: remoteUserId,
  accessToken: 'access-secret',
  refreshToken: 'refresh-secret',
  expiresAt: DateTime.utc(2026, 7, 13, 12),
  isAnonymous: isAnonymous,
);

class _SessionStore implements SecureSessionStore {
  _SessionStore({this.order});

  final List<String>? order;
  RemoteAuthSession? value;
  int writeCount = 0;

  @override
  Future<void> clear() async {
    order?.add('session');
    value = null;
  }

  @override
  Future<RemoteAuthSession?> read() async => value;

  @override
  Future<void> write(RemoteAuthSession session) async {
    writeCount += 1;
    value = session;
  }
}

class _AuthGateway implements RemoteAuthGateway {
  _AuthGateway({required this.created, RemoteAuthSession? linked})
    : linked = linked ?? created;

  final RemoteAuthSession created;
  final RemoteAuthSession linked;
  int signInCount = 0;
  int refreshCount = 0;

  @override
  Future<RemoteAuthSession> linkIdentity(
    RemoteAuthSession current,
    ExternalIdentityProvider provider,
  ) async => linked;

  @override
  Future<RemoteAuthSession> refresh(RemoteAuthSession current) async {
    refreshCount += 1;
    return created;
  }

  @override
  Future<RemoteAuthSession> signInAnonymously() async {
    signInCount += 1;
    return created;
  }
}

class _IdentityBinding implements RemoteIdentityBindingRepository {
  String? remoteUserId;

  @override
  Future<void> bindRemoteUser(String remoteUserId, DateTime linkedAt) async {
    this.remoteUserId = remoteUserId;
  }
}

class _DeletionBackend implements VNextBackendGateway {
  _DeletionBackend({required this.order, this.failure});

  final List<String> order;
  final Object? failure;

  @override
  Future<DataDeletionReceipt> deleteMyData() async {
    order.add('remote');
    if (failure != null) throw failure!;
    return DataDeletionReceipt(
      receiptId: 'receipt-id',
      remoteUserId: 'remote-user',
      deletedAt: DateTime.utc(2026, 7, 13),
      authIdentityDeleted: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
