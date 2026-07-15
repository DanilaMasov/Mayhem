import 'dart:convert';

import '../../domain/models/quest.dart';
import '../../domain/models/quest_catalog.dart';
import '../../domain/models/quest_guide.dart';
import '../../domain/models/npc_dialog.dart';
import '../../features/challenge/domain/challenge_preparation.dart';
import '../../features/challenge/domain/challenge_models.dart';
import '../../features/progress/domain/progress_models.dart';
import '../domain/content_item_revision.dart';

class BundledVNextContent {
  BundledVNextContent({
    required List<ContentItemRevision> revisions,
    required Map<String, ChallengeDefinition> challenges,
    required Map<String, ChallengePreparation> preparations,
  }) : revisions = List.unmodifiable(revisions),
       challenges = Map.unmodifiable(challenges),
       preparations = Map.unmodifiable(preparations) {
    if (!challenges.keys.toSet().containsAll(preparations.keys) ||
        preparations.entries.any(
          (entry) => entry.value.challengeId != entry.key,
        )) {
      throw const FormatException('Preparation references unknown challenge');
    }
  }

  final List<ContentItemRevision> revisions;
  final Map<String, ChallengeDefinition> challenges;
  final Map<String, ChallengePreparation> preparations;

  ChallengeDefinition challenge(String contentId) {
    final definition = challenges[contentId];
    if (definition == null) {
      throw StateError('Challenge definition not found: $contentId');
    }
    return definition;
  }
}

class BundledVNextContentAdapter {
  const BundledVNextContentAdapter();

  static const locale = 'ru-RU';
  static const challengeCount = 11;

  BundledVNextContent adapt(
    QuestCatalog catalog, {
    required DateTime publishedAt,
    GuideCatalog? guides,
    DialogCatalog? dialogs,
  }) {
    if (dialogs != null && guides == null) {
      throw const FormatException('Dialogs require bundled guides');
    }
    final safePublishedAt = publishedAt.toUtc();
    final candidates = _selectLaunchChallenges(
      catalog.quests.where((quest) => !quest.isShadow && !quest.isBoss),
    );
    if (candidates.length < challengeCount) {
      throw const FormatException(
        'Bundled vNext requires at least eleven safe challenges',
      );
    }

    final revisions = <ContentItemRevision>[];
    final definitions = <String, ChallengeDefinition>{};
    final preparations = <String, ChallengePreparation>{};
    for (final quest in candidates) {
      final definition = _challengeDefinition(quest);
      definitions[quest.id] = definition;
      revisions.add(
        _revision(
          contentId: quest.id,
          type: ContentItemType.challenge,
          payload: _challengePayload(definition, quest.category),
          lowPressureRoute: quest.alternateRoute,
          publishedAt: safePublishedAt,
        ),
      );
      if (guides != null) {
        final guide = guides.forQuest(quest.id);
        final dialog = dialogs?.hasDialog(quest.id) == true
            ? dialogs!.forQuest(quest.id)
            : null;
        preparations[quest.id] = _preparation(definition, guide, dialog);
      }
    }

    for (final fixture in _microTrainings) {
      revisions.add(
        _revision(
          contentId: fixture.id,
          type: ContentItemType.microTraining,
          payload: {
            'title': fixture.title,
            'supportingCopy': fixture.supportingCopy,
            'instruction': fixture.instruction,
            'durationSeconds': fixture.durationSeconds,
            'primaryTrait': fixture.primaryTrait.name,
            'momentumEligible': false,
          },
          lowPressureRoute: fixture.lowPressureRoute,
          publishedAt: safePublishedAt,
        ),
      );
    }

    for (final fixture in _scenarios) {
      revisions.add(
        _revision(
          contentId: fixture.id,
          type: ContentItemType.scenarioPoll,
          payload: {
            'title': fixture.title,
            'supportingCopy': fixture.supportingCopy,
            'primaryTrait': fixture.primaryTrait.name,
            'options': fixture.options,
          },
          lowPressureRoute: 'Можно пропустить сценарий без оценки.',
          publishedAt: safePublishedAt,
        ),
      );
    }

    for (final fixture in _seasonFixtures) {
      revisions.add(
        _revision(
          contentId: fixture.id,
          type: ContentItemType.seasonUpdate,
          payload: {
            'title': fixture.title,
            'supportingCopy': fixture.supportingCopy,
            'day': fixture.day,
            'totalDays': 7,
            'fixture': true,
          },
          lowPressureRoute: 'Season participation is optional.',
          publishedAt: safePublishedAt,
        ),
      );
    }

    return BundledVNextContent(
      revisions: revisions,
      challenges: definitions,
      preparations: preparations,
    );
  }

  List<Quest> _selectLaunchChallenges(Iterable<Quest> source) {
    final pool = source.toList(growable: false);
    final selected = <Quest>[];
    const targets = {1: 6, 2: 4, 3: 1};
    for (final target in targets.entries) {
      final byTrait = {
        for (final trait in Trait.values)
          trait: pool
              .where(
                (quest) =>
                    quest.level == target.key && _primaryTrait(quest) == trait,
              )
              .toList(growable: false),
      };
      final cursors = {for (final trait in Trait.values) trait: 0};
      final levelSelection = <Quest>[];
      while (levelSelection.length < target.value) {
        var added = false;
        for (final trait in Trait.values) {
          final cursor = cursors[trait]!;
          final candidates = byTrait[trait]!;
          if (cursor >= candidates.length) continue;
          levelSelection.add(candidates[cursor]);
          cursors[trait] = cursor + 1;
          added = true;
          if (levelSelection.length == target.value) break;
        }
        if (!added) {
          throw FormatException(
            'Bundled vNext lacks level ${target.key} launch diversity',
          );
        }
      }
      selected.addAll(levelSelection);
    }
    return selected;
  }

  ChallengePreparation _preparation(
    ChallengeDefinition definition,
    QuestGuide guide,
    NpcDialog? dialog,
  ) {
    final expectedIds = definition.preparationContentIds.toSet();
    final actualIds = {guide.id, if (dialog != null) dialog.id};
    if (expectedIds.length != actualIds.length ||
        !expectedIds.containsAll(actualIds)) {
      throw const FormatException('Preparation content IDs do not match');
    }
    return ChallengePreparation(
      challengeId: guide.questId,
      guideId: guide.id,
      steps: guide.steps,
      phrases: guide.phrases,
      exitScript: guide.exitScript,
      alternateRoute: guide.alternateRoute,
      advancedRoute: guide.advancedRoute,
      rehearsal: dialog == null
          ? null
          : ChallengeRehearsal(
              rehearsalId: dialog.id,
              startNodeId: dialog.startNodeId,
              nodes: [
                for (final node in dialog.nodes)
                  RehearsalNode(
                    nodeId: node.id,
                    speaker: node.speaker == DialogSpeaker.coach
                        ? RehearsalSpeaker.coach
                        : RehearsalSpeaker.partner,
                    text: node.text,
                    options: [
                      for (final option in node.options)
                        RehearsalOption(
                          label: option.label,
                          nextNodeId: option.nextNodeId,
                        ),
                    ],
                    success: node.success,
                  ),
              ],
            ),
    );
  }

  ChallengeDefinition _challengeDefinition(Quest quest) {
    final primaryTrait = _primaryTrait(quest);
    final secondary = switch (primaryTrait) {
      Trait.expression => const {Trait.presence: 0.35},
      Trait.initiation => const {Trait.presence: 0.30},
      Trait.connection => const {Trait.initiation: 0.25},
      Trait.presence => const {Trait.expression: 0.35},
    };
    return ChallengeDefinition(
      contentId: quest.id,
      revision: 1,
      title: quest.text,
      supportingCopy: quest.category,
      primaryTrait: primaryTrait,
      secondaryTraitWeights: secondary,
      intensity: quest.level,
      baseXp: switch (quest.level) {
        1 => 40,
        2 => 75,
        _ => 140,
      },
      estimatedDuration: Duration(
        minutes: switch (quest.level) {
          1 => 2,
          2 => 5,
          _ => 10,
        },
      ),
      contextTags: {quest.category.toLowerCase(), quest.statType.name},
      completionCriteria:
          'Сделай описанное действие один раз, сохраняя свои и чужие границы.',
      normalRoute: ChallengeRoute(copy: quest.text),
      lowPressureRoute: ChallengeRoute(copy: quest.alternateRoute),
      advancedRoute: ChallengeRoute(copy: quest.advancedRoute),
      advancedRouteSafetyApproved: true,
      preparationContentIds: [
        'guide_${quest.id}',
        if (quest.level >= 2) 'dialog_${quest.id}',
      ],
      momentumEligible: true,
      repeatable: true,
    );
  }

  Map<String, Object?> _challengePayload(
    ChallengeDefinition definition,
    String category,
  ) {
    return {
      'title': definition.title,
      'supportingCopy': definition.supportingCopy,
      'category': category,
      'primaryTrait': definition.primaryTrait.name,
      'secondaryTraitWeights': {
        for (final entry in definition.secondaryTraitWeights.entries)
          entry.key.name: entry.value,
      },
      'intensity': definition.intensity,
      'baseXp': definition.baseXp,
      'estimatedDurationSeconds': definition.estimatedDuration?.inSeconds,
      'completionCriteria': definition.completionCriteria,
      'normalRoute': definition.normalRoute.copy,
      'lowPressureRoute': definition.lowPressureRoute.copy,
      'advancedRoute': definition.advancedRoute?.copy,
      'advancedRouteSafetyApproved': definition.advancedRouteSafetyApproved,
      'preparationContentIds': definition.preparationContentIds,
      'momentumEligible': definition.momentumEligible,
      'repeatable': definition.repeatable,
    };
  }

  ContentItemRevision _revision({
    required String contentId,
    required ContentItemType type,
    required Map<String, Object?> payload,
    required String lowPressureRoute,
    required DateTime publishedAt,
  }) {
    final safety = {
      'safetyReviewed': true,
      'safetyRevision': 1,
      'requiresContextWarning': false,
      'disallowedContexts': const [
        'explicit_refusal',
        'power_imbalance_pressure',
        'unsafe_environment',
      ],
      'lowPressureRoute': lowPressureRoute,
      'exitCopy': 'Можно остановиться в любой момент без штрафа.',
    };
    final checksumSource = jsonEncode({
      'contentId': contentId,
      'revision': 1,
      'locale': locale,
      'type': type.name,
      'payload': payload,
      'publishedAt': publishedAt.toUtc().toIso8601String(),
      'safety': safety,
    });
    return ContentItemRevision(
      contentId: contentId,
      revision: 1,
      type: type,
      locale: locale,
      publishedAt: publishedAt,
      payload: payload,
      safety: SafetyMetadata(
        safetyReviewed: safety['safetyReviewed']! as bool,
        safetyRevision: safety['safetyRevision']! as int,
        requiresContextWarning: safety['requiresContextWarning']! as bool,
        disallowedContexts: Set<String>.from(
          safety['disallowedContexts']! as List<String>,
        ),
        lowPressureRoute: lowPressureRoute,
        exitCopy: safety['exitCopy']! as String,
      ),
      active: true,
      source: ContentRevisionSource.bundled,
      checksum: 'fnv1a32:${_fnv1a32(checksumSource)}',
    );
  }

  Trait _primaryTrait(Quest quest) {
    final category = quest.category.toLowerCase();
    if (category.contains('small talk') ||
        category.contains('пауза') ||
        category.contains('присутств')) {
      return Trait.presence;
    }
    return switch (quest.statType) {
      StatType.charisma => Trait.expression,
      StatType.boldness => Trait.initiation,
      StatType.networking => Trait.connection,
    };
  }

  int _fnv1a32(String value) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static const _microTrainings = [
    _TrainingFixture(
      id: 'training_presence_pause',
      title: 'Выдержи три секунды тишины.',
      supportingCopy: 'Не заполняй паузу оправданиями.',
      instruction: 'Вдохни, досчитай до трёх и только потом продолжи.',
      lowPressureRoute: 'Начни с одной спокойной секунды.',
      durationSeconds: 15,
      primaryTrait: Trait.presence,
    ),
    _TrainingFixture(
      id: 'training_expression_request',
      title: 'Скажи просьбу одним предложением.',
      supportingCopy: 'Без длинного вступления и самооправдания.',
      instruction: 'Назови действие, срок и оставь человеку право ответить.',
      lowPressureRoute: 'Запиши фразу и прочитай её про себя.',
      durationSeconds: 20,
      primaryTrait: Trait.expression,
    ),
    _TrainingFixture(
      id: 'training_connection_followup',
      title: 'Задай один конкретный дополнительный вопрос.',
      supportingCopy: 'Интерес важнее попытки казаться интересным.',
      instruction: 'Возьми одну деталь из ответа и уточни только её.',
      lowPressureRoute: 'Сформулируй вопрос без отправки.',
      durationSeconds: 20,
      primaryTrait: Trait.connection,
    ),
    _TrainingFixture(
      id: 'training_initiation_opening',
      title: 'Подготовь первую нейтральную фразу.',
      supportingCopy: 'Начало должно быть легче, чем идеальный разговор.',
      instruction: 'Назови общий контекст и остановись после одной фразы.',
      lowPressureRoute: 'Произнеси фразу наедине один раз.',
      durationSeconds: 15,
      primaryTrait: Trait.initiation,
    ),
  ];

  static const _scenarios = [
    _ScenarioFixture(
      id: 'scenario_event_arrival',
      title: 'Ты пришёл на встречу, где почти никого не знаешь.',
      supportingCopy: 'Какой первый шаг сейчас реалистичен?',
      primaryTrait: Trait.initiation,
      options: [
        'Подойти к одному человеку.',
        'Осмотреться и выбрать момент.',
        'Поздороваться с организатором.',
        'Пропустить без оценки.',
      ],
    ),
    _ScenarioFixture(
      id: 'scenario_disagreement',
      title: 'В разговоре прозвучало мнение, с которым ты не согласен.',
      supportingCopy: 'Как выразить позицию без атаки?',
      primaryTrait: Trait.expression,
      options: [
        'Коротко назвать свою точку зрения.',
        'Сначала задать уточняющий вопрос.',
        'Вернуться к теме позже.',
        'Не вступать в спор.',
      ],
    ),
    _ScenarioFixture(
      id: 'scenario_short_reply',
      title: 'Собеседник отвечает коротко и не задаёт встречных вопросов.',
      supportingCopy: 'Что лучше уважает границы?',
      primaryTrait: Trait.connection,
      options: [
        'Спокойно завершить разговор.',
        'Задать один лёгкий вопрос.',
        'Сменить тему один раз.',
        'Дать человеку пространство.',
      ],
    ),
  ];

  static const _seasonFixtures = [
    _SeasonFixture(
      id: 'season_zero_day_1_fixture',
      title: 'SOCIAL RESET · DAY 1',
      supportingCopy: 'Сегодня считается один честный первый шаг.',
      day: 1,
    ),
    _SeasonFixture(
      id: 'season_zero_day_2_fixture',
      title: 'SOCIAL RESET · DAY 2',
      supportingCopy: 'Попытка продолжает путь так же, как результат.',
      day: 2,
    ),
  ];
}

class _TrainingFixture {
  const _TrainingFixture({
    required this.id,
    required this.title,
    required this.supportingCopy,
    required this.instruction,
    required this.lowPressureRoute,
    required this.durationSeconds,
    required this.primaryTrait,
  });

  final String id;
  final String title;
  final String supportingCopy;
  final String instruction;
  final String lowPressureRoute;
  final int durationSeconds;
  final Trait primaryTrait;
}

class _ScenarioFixture {
  const _ScenarioFixture({
    required this.id,
    required this.title,
    required this.supportingCopy,
    required this.primaryTrait,
    required this.options,
  });

  final String id;
  final String title;
  final String supportingCopy;
  final Trait primaryTrait;
  final List<String> options;
}

class _SeasonFixture {
  const _SeasonFixture({
    required this.id,
    required this.title,
    required this.supportingCopy,
    required this.day,
  });

  final String id;
  final String title;
  final String supportingCopy;
  final int day;
}
