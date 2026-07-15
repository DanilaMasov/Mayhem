import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/content/data/bundled_vnext_content_adapter.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';
import 'package:mayhem_mobile/data/catalog/bundled_quest_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_guide_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_dialog_catalog.dart';
import 'package:mayhem_mobile/domain/models/npc_dialog.dart';
import 'package:mayhem_mobile/domain/models/quest_guide.dart';
import 'package:mayhem_mobile/domain/models/quest_catalog.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';

void main() {
  test('bundled vNext adapter creates reviewed typed launch content', () async {
    final source = await _legacyContent();
    final adapted = const BundledVNextContentAdapter().adapt(
      source.catalog,
      publishedAt: DateTime.utc(2026, 7, 13),
      guides: source.guides,
      dialogs: source.dialogs,
    );

    expect(adapted.revisions, hasLength(20));
    expect(adapted.challenges, hasLength(11));
    expect(adapted.preparations, hasLength(11));
    expect(adapted.preparations.values.first.steps, hasLength(3));
    expect(
      adapted.preparations.values.where((item) => item.rehearsal != null),
      isNotEmpty,
    );
    expect(
      adapted.revisions.where(
        (item) => item.type == ContentItemType.microTraining,
      ),
      hasLength(4),
    );
    expect(
      adapted.revisions.where(
        (item) => item.type == ContentItemType.scenarioPoll,
      ),
      hasLength(3),
    );
    expect(
      adapted.revisions.where(
        (item) => item.type == ContentItemType.seasonUpdate,
      ),
      hasLength(2),
    );
    expect(
      adapted.revisions.every(
        (item) =>
            item.safety.safetyReviewed &&
            item.safety.lowPressureRoute?.isNotEmpty == true &&
            item.checksum.startsWith('fnv1a32:'),
      ),
      isTrue,
    );
    expect(
      adapted.challenges.values.map((item) => item.primaryTrait).toSet(),
      containsAll(Trait.values),
    );
  });

  test('adapter output is deterministic for a catalog revision', () async {
    final source = await _legacyContent();
    const adapter = BundledVNextContentAdapter();
    final first = adapter.adapt(
      source.catalog,
      publishedAt: DateTime.utc(2026, 7, 13),
      guides: source.guides,
      dialogs: source.dialogs,
    );
    final second = adapter.adapt(
      source.catalog,
      publishedAt: DateTime.utc(2026, 7, 13),
      guides: source.guides,
      dialogs: source.dialogs,
    );

    expect(
      first.revisions.map((item) => item.identity),
      orderedEquals(second.revisions.map((item) => item.identity)),
    );
    expect(
      first.revisions.map((item) => item.checksum),
      orderedEquals(second.revisions.map((item) => item.checksum)),
    );
  });
}

Future<({QuestCatalog catalog, GuideCatalog guides, DialogCatalog dialogs})>
_legacyContent() async {
  final sources = await Future.wait([
    File('assets/content/quest_catalog.json').readAsString(),
    File('assets/content/guide_catalog.json').readAsString(),
    File('assets/content/dialog_catalog.json').readAsString(),
  ]);
  return (
    catalog: BundledQuestCatalog.fromJson(
      jsonDecode(sources[0]) as Map<String, dynamic>,
    ),
    guides: BundledGuideCatalog.fromJson(
      jsonDecode(sources[1]) as Map<String, dynamic>,
    ),
    dialogs: BundledDialogCatalog.fromJson(
      jsonDecode(sources[2]) as Map<String, dynamic>,
    ),
  );
}
