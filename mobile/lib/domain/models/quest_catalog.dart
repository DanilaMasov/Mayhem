import 'quest.dart';

class QuestCatalog {
  static const expectedQuestCount = 50;
  static const expectedBossCount = 5;
  static const expectedShadowCount = 13;

  QuestCatalog({
    required this.schemaVersion,
    required this.quests,
    required this.bosses,
  }) {
    _validate();
    _byId = {
      for (final quest in [...quests, ...bosses]) quest.id: quest,
    };
  }

  final int schemaVersion;
  final List<Quest> quests;
  final List<Quest> bosses;
  late final Map<String, Quest> _byId;

  Quest byId(String id) {
    final quest = _byId[id];
    if (quest == null) throw StateError('Unknown quest: $id');
    return quest;
  }

  List<Quest> regularAtLevel(int level) {
    return quests
        .where((quest) => !quest.isShadow && quest.level == level)
        .toList(growable: false);
  }

  List<Quest> get shadowQuests =>
      quests.where((quest) => quest.isShadow).toList(growable: false);

  void validateBundledContract() {
    if (quests.length != expectedQuestCount ||
        bosses.length != expectedBossCount) {
      throw FormatException(
        'Schema v1 requires exactly $expectedQuestCount quests and '
        '$expectedBossCount bosses',
      );
    }
    if (shadowQuests.length != expectedShadowCount) {
      throw FormatException(
        'Schema v1 requires exactly $expectedShadowCount reset quests',
      );
    }
    _expectLevelCounts(const {1: 18, 2: 22, 3: 10});
    _expectStatCounts(const {
      StatType.charisma: 15,
      StatType.boldness: 12,
      StatType.networking: 10,
    });
  }

  void _validate() {
    if (schemaVersion != 1) {
      throw FormatException('Unsupported quest catalog schema: $schemaVersion');
    }
    if (quests.isEmpty || bosses.isEmpty) {
      throw const FormatException('Quest and boss pools must not be empty');
    }
    final ids = <String>{};
    for (final quest in quests) {
      if (quest.isBoss) {
        throw FormatException('Regular pool contains boss: ${quest.id}');
      }
      _validateQuest(quest);
      if (!ids.add(quest.id)) {
        throw FormatException('Duplicate quest id: ${quest.id}');
      }
    }
    for (final quest in bosses) {
      if (!quest.isBoss) {
        throw FormatException('Boss flag is missing for ${quest.id}');
      }
      _validateQuest(quest);
      if (!ids.add(quest.id)) {
        throw FormatException('Duplicate quest id: ${quest.id}');
      }
    }
  }

  void _validateQuest(Quest quest) {
    if (quest.level < 1 || quest.level > 3) {
      throw FormatException('Invalid level for ${quest.id}');
    }
    if (quest.isBoss && (quest.level != 3 || quest.energyCost != 50)) {
      throw FormatException('Invalid boss contract for ${quest.id}');
    }
    if (quest.isShadow && (quest.energyCost != 0 || quest.rewardEnergy <= 0)) {
      throw FormatException('Invalid reset quest contract for ${quest.id}');
    }
    if (!quest.isShadow && !quest.isBoss) {
      final expectedCost = switch (quest.level) {
        1 => 10,
        2 => 25,
        3 => 50,
        _ => 0,
      };
      if (quest.energyCost != expectedCost || quest.rewardEnergy != 0) {
        throw FormatException('Invalid energy contract for ${quest.id}');
      }
    }
  }

  void _expectLevelCounts(Map<int, int> expected) {
    for (final entry in expected.entries) {
      final actual = quests.where((quest) => quest.level == entry.key).length;
      if (actual != entry.value) {
        throw FormatException(
          'Schema v1 requires ${entry.value} level ${entry.key} quests, got $actual',
        );
      }
    }
  }

  void _expectStatCounts(Map<StatType, int> expected) {
    final regular = quests.where((quest) => !quest.isShadow);
    for (final entry in expected.entries) {
      final actual = regular
          .where((quest) => quest.statType == entry.key)
          .length;
      if (actual != entry.value) {
        throw FormatException(
          'Schema v1 requires ${entry.value} ${entry.key.name} quests, got $actual',
        );
      }
    }
  }
}
