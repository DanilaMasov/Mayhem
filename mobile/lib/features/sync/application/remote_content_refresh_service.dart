import '../../../content/domain/content_repository.dart';
import '../domain/backend_models.dart';

class RemoteContentRefreshResult {
  const RemoteContentRefreshResult({
    required this.manifestRevision,
    required this.downloadedCount,
    required this.activeCount,
  });

  final int manifestRevision;
  final int downloadedCount;
  final int activeCount;
}

abstract interface class RemoteContentRefresher {
  Future<RemoteContentRefreshResult> refresh({String locale = 'ru'});
}

class RemoteContentRefreshService implements RemoteContentRefresher {
  const RemoteContentRefreshService({
    required this.backend,
    required this.content,
  });

  final VNextBackendGateway backend;
  final ContentRepository content;

  @override
  Future<RemoteContentRefreshResult> refresh({String locale = 'ru'}) async {
    final manifest = await backend.getContentManifest(locale: locale);
    if (manifest.locale != locale) {
      throw const FormatException('Remote manifest locale mismatch');
    }
    final missing = <ContentManifestReference>[];
    for (final reference in manifest.items) {
      final local = await content.findRevision(
        contentId: reference.contentId,
        revision: reference.revision,
        locale: reference.locale,
      );
      if (local == null || local.checksum != reference.checksum) {
        missing.add(reference);
      }
    }

    final downloaded = missing.isEmpty
        ? const <RemoteContentRevision>[]
        : await backend.getContentRevisions(missing);
    final expected = {for (final item in missing) item.identity: item.checksum};
    final received = <String>{};
    for (final item in downloaded) {
      final revision = item.revision;
      final identity = revision.identity;
      if (expected[identity] != item.serverChecksum ||
          !received.add(identity)) {
        throw const FormatException('Remote content response is incomplete');
      }
    }
    if (received.length != expected.length) {
      throw const FormatException('Remote content response is incomplete');
    }

    await content.saveValidatedRevisions(
      downloaded.map((item) => item.revision),
    );
    await content.activateRemoteManifest(
      locale: locale,
      manifestRevision: manifest.revision,
      identities: {
        for (final item in manifest.items) '${item.contentId}@${item.revision}',
      },
    );
    return RemoteContentRefreshResult(
      manifestRevision: manifest.revision,
      downloadedCount: downloaded.length,
      activeCount: manifest.items.length,
    );
  }
}
