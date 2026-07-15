import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/identity/local_identity_reset.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test(
    'full local reset creates a new anonymous local identity immediately',
    () async {
      final database = MemoryVNextDatabase(
        seed: {
          'app_metadata': [
            {
              'key': 'installation_id',
              'value': 'old-installation',
              'updated_at': '2026-07-12T00:00:00.000Z',
            },
          ],
          'user_identity': [
            {
              'local_user_id': 'old-user',
              'installation_id': 'old-installation',
              'remote_user_id': null,
            },
          ],
        },
      );
      var sequence = 0;

      final identity = await database.transaction((db) async {
        await db.delete('user_identity');
        await db.delete('app_metadata');
        return LocalIdentityReset.replace(
          db,
          idGenerator: () => 'new-${++sequence}',
          now: DateTime.utc(2026, 7, 13),
        );
      });

      expect(identity.installationId, 'new-1');
      expect(identity.localUserId, 'new-2');
      expect(identity.remoteUserId, isNull);
      expect(
        database.executor.rows('user_identity').single,
        containsPair('installation_id', 'new-1'),
      );
      expect(
        database.executor.rows('app_metadata'),
        contains(containsPair('key', 'client_sequence:new-1')),
      );
    },
  );

  test('identity reset rejects an empty generated ID atomically', () async {
    final database = MemoryVNextDatabase();

    await expectLater(
      database.transaction(
        (db) => LocalIdentityReset.replace(
          db,
          idGenerator: () => '',
          now: DateTime.utc(2026, 7, 13),
        ),
      ),
      throwsFormatException,
    );
    expect(database.executor.rows('app_metadata'), isEmpty);
    expect(database.executor.rows('user_identity'), isEmpty);
  });
}
