import 'content_item_revision.dart';

abstract interface class ContentRepository {
  Future<ContentItemRevision?> findRevision({
    required String contentId,
    required int revision,
    required String locale,
  });

  Future<List<ContentItemRevision>> activeRevisions({
    required String locale,
    required DateTime atUtc,
  });

  Future<void> saveValidatedRevisions(Iterable<ContentItemRevision> revisions);

  Future<void> activateBundledCatalog(Iterable<ContentItemRevision> revisions);

  Future<void> activateRemoteManifest({
    required String locale,
    required int manifestRevision,
    required Set<String> identities,
  });
}
