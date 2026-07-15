import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/crypto/sha256.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/features/sync/application/remote_content_refresh_service.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/remote_content_checksum.dart';
import 'package:mayhem_mobile/infrastructure/sqlite/sqlite_vnext_context.dart';
import 'package:mayhem_mobile/content/data/sqlite_content_repository.dart';

import '../../support/memory_vnext_database.dart';

void main() {
  test('SHA-256 implementation matches the standard empty and abc vectors', () {
    expect(
      Sha256.hexOfString(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      Sha256.hexOfString('abc'),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('remote revision rejects payload tampering after checksum creation', () {
    final source = _revisionJson();
    source['checksum'] = RemoteContentChecksum.compute(source);
    final parsed = RemoteContentRevision.fromJson(source);
    expect(parsed.revision.contentId, 'remote_challenge');

    final tampered = Map<String, dynamic>.from(source)
      ..['payload'] = {'title': 'Changed after publishing'};
    expect(
      () => RemoteContentRevision.fromJson(tampered),
      throwsFormatException,
    );
  });

  test(
    'validated remote manifest activates atomically over bundled fallback',
    () async {
      final source = _revisionJson();
      final checksum = RemoteContentChecksum.compute(source);
      source['checksum'] = checksum;
      final revision = RemoteContentRevision.fromJson(source);
      final manifest = RemoteContentManifest(
        revision: 1,
        locale: 'ru',
        generatedAt: DateTime.utc(2026, 7, 13, 12),
        items: [
          ContentManifestReference(
            contentId: 'remote_challenge',
            revision: 1,
            locale: 'ru',
            type: revision.revision.type,
            checksum: checksum,
          ),
        ],
      );
      final database = MemoryVNextDatabase();
      final repository = SqliteContentRepository(SqliteVNextContext(database));
      final service = RemoteContentRefreshService(
        backend: _ContentBackend(manifest: manifest, revisions: [revision]),
        content: repository,
      );

      final result = await service.refresh();
      final active = await repository.activeRevisions(
        locale: 'ru',
        atUtc: DateTime.utc(2026, 7, 13, 13),
      );

      expect(result.downloadedCount, 1);
      expect(active.single.contentId, 'remote_challenge');
      expect(active.single.active, isTrue);
    },
  );

  test('incomplete download cannot activate a partial manifest', () async {
    final source = _revisionJson();
    final checksum = RemoteContentChecksum.compute(source);
    final manifest = RemoteContentManifest(
      revision: 1,
      locale: 'ru',
      generatedAt: DateTime.utc(2026, 7, 13, 12),
      items: [
        ContentManifestReference(
          contentId: 'remote_challenge',
          revision: 1,
          locale: 'ru',
          type: ContentItemType.challenge,
          checksum: checksum,
        ),
      ],
    );
    final database = MemoryVNextDatabase();
    final repository = SqliteContentRepository(SqliteVNextContext(database));
    final service = RemoteContentRefreshService(
      backend: _ContentBackend(manifest: manifest, revisions: const []),
      content: repository,
    );

    await expectLater(service.refresh, throwsFormatException);

    expect(database.executor.rows('content_item_revisions'), isEmpty);
  });
}

Map<String, dynamic> _revisionJson() => {
  'contentId': 'remote_challenge',
  'revision': 1,
  'locale': 'ru',
  'type': 'challenge',
  'payload': {
    'title': 'Remote challenge',
    'primaryTrait': 'presence',
    'intensity': 3,
    'baseXp': 100,
    'momentumEligible': true,
  },
  'safety': {
    'safetyReviewed': true,
    'safetyRevision': 1,
    'requiresContextWarning': false,
    'disallowedContexts': <String>[],
    'lowPressureRoute': 'Use the easier route.',
    'exitCopy': 'Stop whenever you need.',
    'advancedRouteSafetyApproved': false,
  },
  'media': null,
  'active': true,
  'publishedAt': '2026-07-13T10:00:00.000Z',
  'startsAt': null,
  'endsAt': null,
};

class _ContentBackend implements VNextBackendGateway {
  _ContentBackend({required this.manifest, required this.revisions});

  final RemoteContentManifest manifest;
  final List<RemoteContentRevision> revisions;

  @override
  Future<RemoteContentManifest> getContentManifest({
    String locale = 'ru',
  }) async => manifest;

  @override
  Future<List<RemoteContentRevision>> getContentRevisions(
    List<ContentManifestReference> revisions,
  ) async => this.revisions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
