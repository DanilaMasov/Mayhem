import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/features/settings/application/delete_everywhere_recovery_store.dart';
import 'package:mayhem_mobile/infrastructure/security/flutter_secure_session_store.dart';

void main() {
  test('round-trips one namespaced session payload', () async {
    final storage = _MemorySecureStore();
    final store = FlutterSecureSessionStore(
      storage: storage,
      environment: 'staging-eu',
    );
    final session = _session();

    await store.write(session);
    final restored = await store.read();

    expect(storage.values.keys, ['mayhem.staging-eu.remote_auth_session.v1']);
    expect(storage.writeCount, 1);
    expect(restored?.remoteUserId, session.remoteUserId);
    expect(restored?.accessToken, session.accessToken);
    expect(restored?.refreshToken, session.refreshToken);
    expect(restored?.expiresAt, session.expiresAt);
    expect(restored?.isAnonymous, isTrue);
  });

  test('environment namespaces cannot collide', () async {
    final storage = _MemorySecureStore();
    final development = FlutterSecureSessionStore(
      storage: storage,
      environment: 'development',
    );
    final production = FlutterSecureSessionStore(
      storage: storage,
      environment: 'production',
    );

    await development.write(_session(remoteUserId: 'development-user'));
    await production.write(_session(remoteUserId: 'production-user'));

    expect((await development.read())?.remoteUserId, 'development-user');
    expect((await production.read())?.remoteUserId, 'production-user');
  });

  test('deletion recovery marker survives session clear', () async {
    final storage = _MemorySecureStore();
    final sessions = FlutterSecureSessionStore(
      storage: storage,
      environment: 'production',
    );
    final recovery = SecureDeleteEverywhereRecoveryStore(
      storage: storage,
      environment: 'production',
    );
    await sessions.write(_session());
    await recovery.write(
      DataDeletionRecoveryMarker(
        receiptId: 'receipt-1',
        remoteUserId: 'remote-user',
        deletedAt: DateTime.utc(2026, 7, 16),
        stage: DataDeletionStage.secureSessionCleared,
      ),
    );

    await sessions.clear();

    expect(await sessions.read(), isNull);
    expect(
      (await recovery.read())?.stage,
      DataDeletionStage.secureSessionCleared,
    );
    expect(storage.values.keys, [
      'mayhem.production.delete_everywhere_recovery.v1',
    ]);
  });

  test('corrupted entry is deleted and treated as signed out', () async {
    final storage = _MemorySecureStore()
      ..values['mayhem.production.remote_auth_session.v1'] = '{not-json';
    final store = FlutterSecureSessionStore(
      storage: storage,
      environment: 'production',
    );

    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
    expect(storage.deleteCount, 1);
  });

  test('invalid session fields are recovered as corruption', () async {
    final storage = _MemorySecureStore()
      ..values['mayhem.production.remote_auth_session.v1'] = jsonEncode({
        'version': 1,
        'remoteUserId': 'remote-user',
        'accessToken': '',
        'refreshToken': 'refresh-secret',
        'expiresAt': '2026-07-16T12:00:00Z',
        'isAnonymous': true,
      });
    final store = FlutterSecureSessionStore(
      storage: storage,
      environment: 'production',
    );

    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  test(
    'platform read failures propagate without deleting the session',
    () async {
      final storage = _MemorySecureStore(readError: StateError('locked'));
      final store = FlutterSecureSessionStore(
        storage: storage,
        environment: 'production',
      );

      await expectLater(store.read, throwsStateError);
      expect(storage.deleteCount, 0);
    },
  );

  test('clear deletes only the environment session key', () async {
    final storage = _MemorySecureStore()
      ..values['mayhem.production.remote_auth_session.v1'] = 'session'
      ..values['unrelated'] = 'keep';
    final store = FlutterSecureSessionStore(
      storage: storage,
      environment: 'production',
    );

    await store.clear();

    expect(storage.values, {'unrelated': 'keep'});
  });

  test('invalid environment is rejected before platform access', () {
    expect(
      () => FlutterSecureSessionStore(
        storage: _MemorySecureStore(),
        environment: '../production',
      ),
      throwsFormatException,
    );
  });

  test('mobile platform projects declare secure-storage requirements', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidBuild = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final debugEntitlements = File(
      'ios/Runner/DebugProfile.entitlements',
    ).readAsStringSync();
    final releaseEntitlements = File(
      'ios/Runner/Release.entitlements',
    ).readAsStringSync();

    expect(androidManifest, contains('android:allowBackup="false"'));
    expect(androidBuild, contains('minSdk = 29'));
    expect(iosProject, contains('Runner/DebugProfile.entitlements'));
    expect(iosProject, contains('Runner/Release.entitlements'));
    expect(debugEntitlements, contains('keychain-access-groups'));
    expect(releaseEntitlements, contains('keychain-access-groups'));
  });
}

RemoteAuthSession _session({String remoteUserId = 'remote-user'}) =>
    RemoteAuthSession(
      remoteUserId: remoteUserId,
      accessToken: 'access-secret',
      refreshToken: 'refresh-secret',
      expiresAt: DateTime.utc(2026, 7, 16, 12),
      isAnonymous: true,
    );

class _MemorySecureStore implements SecureKeyValueStore {
  _MemorySecureStore({this.readError});

  final Object? readError;
  final Map<String, String> values = {};
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<void> delete({required String key}) async {
    deleteCount += 1;
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount += 1;
    values[key] = value;
  }
}
