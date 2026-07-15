import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/data/catalog/bundled_dialog_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_guide_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_quest_catalog.dart';
import 'package:mayhem_mobile/data/catalog/bundled_modifier_catalog.dart';
import 'package:mayhem_mobile/domain/models/quest_catalog.dart';

void main() {
  test(
    'bundled mobile catalog parses and satisfies the domain contract',
    () async {
      final raw = await File(
        'assets/content/quest_catalog.json',
      ).readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final catalog = BundledQuestCatalog.fromJson(decoded);

      expect(catalog.schemaVersion, 1);
      expect(catalog.quests, hasLength(QuestCatalog.expectedQuestCount));
      expect(catalog.bosses, hasLength(QuestCatalog.expectedBossCount));
      expect(catalog.shadowQuests, hasLength(QuestCatalog.expectedShadowCount));
      expect(catalog.quests.where((quest) => quest.level == 1), hasLength(18));
      expect(catalog.quests.where((quest) => quest.level == 2), hasLength(22));
      expect(catalog.quests.where((quest) => quest.level == 3), hasLength(10));
    },
  );

  test('bundled guides parse and cover every mobile quest', () async {
    final questRaw = await File(
      'assets/content/quest_catalog.json',
    ).readAsString();
    final guideRaw = await File(
      'assets/content/guide_catalog.json',
    ).readAsString();
    final quests = BundledQuestCatalog.fromJson(
      jsonDecode(questRaw) as Map<String, dynamic>,
    );
    final guides = BundledGuideCatalog.fromJson(
      jsonDecode(guideRaw) as Map<String, dynamic>,
    );

    guides.validateCoverage([
      ...quests.quests.map((quest) => quest.id),
      ...quests.bosses.map((quest) => quest.id),
    ]);
    expect(guides.guides, hasLength(55));
    expect(guides.forQuest('boss_direct_invite').steps, hasLength(3));
    expect(guides.forQuest('q_c_001').phrases.first, contains('Спасибо'));
  });

  test('bundled dialog graphs parse and cover every eligible quest', () async {
    final questRaw = await File(
      'assets/content/quest_catalog.json',
    ).readAsString();
    final dialogRaw = await File(
      'assets/content/dialog_catalog.json',
    ).readAsString();
    final quests = BundledQuestCatalog.fromJson(
      jsonDecode(questRaw) as Map<String, dynamic>,
    );
    final dialogs = BundledDialogCatalog.fromJson(
      jsonDecode(dialogRaw) as Map<String, dynamic>,
    );

    final eligibleQuestIds = [
      ...quests.quests
          .where((quest) => !quest.isShadow && quest.level >= 2)
          .map((quest) => quest.id),
      ...quests.bosses.map((quest) => quest.id),
    ];
    dialogs.validateCoverage(eligibleQuestIds);
    expect(dialogs.dialogs, hasLength(eligibleQuestIds.length));
    expect(dialogs.forQuest('boss_group_entry').node('success').success, true);
  });

  test('bundled modifier catalog parses the five safe constraints', () async {
    final raw = await File(
      'assets/content/modifier_catalog.json',
    ).readAsString();
    final modifiers = BundledModifierCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );

    expect(modifiers.modifiers, hasLength(5));
    expect(modifiers.byId('capybara').title, 'Две минуты');
    expect(modifiers.byId('echo').text, contains('закончи контакт'));
  });
}
