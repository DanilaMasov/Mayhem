import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/content_item_revision.dart';
import '../domain/content_repository.dart';

class SqliteContentRepository implements ContentRepository {
  const SqliteContentRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<ContentItemRevision?> findRevision({
    required String contentId,
    required int revision,
    required String locale,
  }) {
    return context.database.read((db) async {
      final rows = await db.query(
        'content_item_revisions',
        where: 'content_id = ? AND revision = ? AND locale = ?',
        whereArgs: [contentId, revision, locale],
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteContentMapper.fromRow(rows.single);
    });
  }

  @override
  Future<List<ContentItemRevision>> activeRevisions({
    required String locale,
    required DateTime atUtc,
  }) {
    final time = atUtc.toUtc().toIso8601String();
    return context.database.read((db) async {
      final rows = await db.query(
        'content_item_revisions',
        where:
            'active = 1 AND locale = ? AND published_at <= ? '
            'AND (starts_at IS NULL OR starts_at <= ?) '
            'AND (ends_at IS NULL OR ends_at > ?)',
        whereArgs: [locale, time, time, time],
        orderBy: 'published_at DESC, content_id ASC, revision DESC',
      );
      final latestByContent = <String, ContentItemRevision>{};
      for (final row in rows) {
        final revision = SqliteContentMapper.fromRow(row);
        final existing = latestByContent[revision.contentId];
        if (existing == null || revision.revision > existing.revision) {
          latestByContent[revision.contentId] = revision;
        }
      }
      return latestByContent.values.toList(growable: false);
    });
  }

  @override
  Future<void> saveValidatedRevisions(Iterable<ContentItemRevision> revisions) {
    return context.database.transaction((db) async {
      for (final revision in revisions) {
        final existing = await db.query(
          'content_item_revisions',
          columns: ['checksum'],
          where: 'content_id = ? AND revision = ? AND locale = ?',
          whereArgs: [revision.contentId, revision.revision, revision.locale],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          if (existing.single['checksum'] != revision.checksum) {
            throw StateError(
              'Content revision ${revision.identity} is immutable',
            );
          }
          continue;
        }
        await db.insert(
          'content_item_revisions',
          SqliteContentMapper.toRow(revision),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    });
  }

  @override
  Future<void> activateBundledCatalog(Iterable<ContentItemRevision> revisions) {
    final catalog = revisions.toList(growable: false);
    if (catalog.isEmpty ||
        catalog.any(
          (revision) => revision.source != ContentRevisionSource.bundled,
        )) {
      throw const FormatException('Bundled catalog is invalid');
    }
    final locale = catalog.first.locale;
    final identities = <String>{};
    if (catalog.any(
          (revision) =>
              revision.locale != locale || !identities.add(revision.identity),
        ) ||
        identities.length != catalog.length) {
      throw const FormatException('Bundled catalog identity is invalid');
    }
    return context.database.transaction((db) async {
      await db.update(
        'content_item_revisions',
        {'active': 0},
        where: 'locale = ? AND source = ?',
        whereArgs: [locale, ContentRevisionSource.bundled.name],
      );
      for (final revision in catalog) {
        final changed = await db.update(
          'content_item_revisions',
          {'active': 1},
          where:
              'content_id = ? AND revision = ? AND locale = ? AND source = ?',
          whereArgs: [
            revision.contentId,
            revision.revision,
            revision.locale,
            ContentRevisionSource.bundled.name,
          ],
        );
        if (changed != 1) {
          throw StateError('Bundled content activation is incomplete');
        }
      }
    });
  }

  @override
  Future<void> activateRemoteManifest({
    required String locale,
    required int manifestRevision,
    required Set<String> identities,
  }) {
    if (locale.trim().isEmpty || manifestRevision < 0) {
      throw const FormatException('Remote manifest locale is required');
    }
    return context.database.transaction((db) async {
      await db.update(
        'content_item_revisions',
        {'active': 0},
        where: 'locale = ? AND source = ?',
        whereArgs: [locale, ContentRevisionSource.remote.name],
      );
      for (final identity in identities) {
        final parts = identity.split('@');
        if (parts.length != 2 || parts.first.isEmpty) {
          throw const FormatException('Remote content identity is invalid');
        }
        final revision = int.tryParse(parts.last);
        if (revision == null || revision < 1) {
          throw const FormatException('Remote content revision is invalid');
        }
        final staged = await db.query(
          'content_item_revisions',
          columns: ['source'],
          where: 'content_id = ? AND revision = ? AND locale = ?',
          whereArgs: [parts.first, revision, locale],
          limit: 1,
        );
        if (staged.isEmpty) {
          throw StateError('Remote manifest references unstaged content');
        }
        if (staged.single['source'] == ContentRevisionSource.remote.name) {
          await db.update(
            'content_item_revisions',
            {'active': 1},
            where:
                'content_id = ? AND revision = ? AND locale = ? AND source = ?',
            whereArgs: [
              parts.first,
              revision,
              locale,
              ContentRevisionSource.remote.name,
            ],
          );
        }
      }
      final activeIdentities = identities.toList()..sort();
      await db.insert('app_metadata', {
        'key': 'remote_content.active_manifest.$locale',
        'value': jsonEncode({
          'manifestRevision': manifestRevision,
          'identities': activeIdentities,
        }),
        'updated_at': context.clock().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
