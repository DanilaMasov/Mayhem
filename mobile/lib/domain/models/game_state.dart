import 'quest.dart';

const _unset = Object();

class ActiveQuest {
  const ActiveQuest({
    required this.questId,
    required this.startedAt,
    required this.variant,
    required this.npcTrained,
    this.modifierId,
  });

  factory ActiveQuest.fromJson(Map<String, dynamic> json) {
    return ActiveQuest(
      questId: json['questId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      variant: json['variant'] as String? ?? 'normal',
      npcTrained: json['npcTrained'] == true,
      modifierId: json['modifierId'] as String?,
    );
  }

  final String questId;
  final DateTime startedAt;
  final String variant;
  final bool npcTrained;
  final String? modifierId;

  Map<String, Object?> toJson() => {
    'questId': questId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'variant': variant,
    'npcTrained': npcTrained,
    'modifierId': modifierId,
  };
}

class ModifierDiceState {
  const ModifierDiceState({required this.date, required this.rollsUsed});

  factory ModifierDiceState.empty() =>
      const ModifierDiceState(date: '', rollsUsed: 0);

  factory ModifierDiceState.fromJson(Map<String, dynamic> json) {
    return ModifierDiceState(
      date: json['date'] as String? ?? '',
      rollsUsed: (json['rollsUsed'] as num?)?.toInt() ?? 0,
    );
  }

  final String date;
  final int rollsUsed;

  Map<String, Object?> toJson() => {'date': date, 'rollsUsed': rollsUsed};
}

class OnboardingState {
  const OnboardingState({required this.boundariesAcknowledged});

  factory OnboardingState.initial() =>
      const OnboardingState(boundariesAcknowledged: false);

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      boundariesAcknowledged: json['boundariesAcknowledged'] == true,
    );
  }

  final bool boundariesAcknowledged;

  Map<String, Object?> toJson() => {
    'boundariesAcknowledged': boundariesAcknowledged,
  };
}

class DailySelection {
  const DailySelection({
    required this.localDate,
    required this.localQuestIds,
    required this.bossDate,
    required this.bossId,
  });

  factory DailySelection.empty() => const DailySelection(
    localDate: '',
    localQuestIds: [],
    bossDate: '',
    bossId: '',
  );

  factory DailySelection.fromJson(Map<String, dynamic> json) {
    return DailySelection(
      localDate: json['localDate'] as String? ?? '',
      localQuestIds: (json['localQuestIds'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      bossDate: json['bossDate'] as String? ?? '',
      bossId: json['bossId'] as String? ?? '',
    );
  }

  final String localDate;
  final List<String> localQuestIds;
  final String bossDate;
  final String bossId;

  Map<String, Object?> toJson() => {
    'localDate': localDate,
    'localQuestIds': localQuestIds,
    'bossDate': bossDate,
    'bossId': bossId,
  };
}

class GameState {
  const GameState({
    required this.schemaVersion,
    required this.energy,
    required this.energyUpdatedAt,
    required this.xp,
    required this.daily,
    required this.completedCount,
    required this.completedByDate,
    required this.trainedQuestIds,
    required this.modifierDice,
    required this.preparedModifierIds,
    required this.onboarding,
    this.activeQuest,
  });

  factory GameState.initial(DateTime now) {
    return GameState(
      schemaVersion: 4,
      energy: 100,
      energyUpdatedAt: now.toUtc(),
      xp: const {
        StatType.charisma: 0,
        StatType.boldness: 0,
        StatType.networking: 0,
      },
      daily: DailySelection.empty(),
      completedCount: 0,
      completedByDate: const {},
      trainedQuestIds: const {},
      modifierDice: ModifierDiceState.empty(),
      preparedModifierIds: const {},
      onboarding: OnboardingState.initial(),
    );
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final xpJson = json['xp'] as Map<String, dynamic>? ?? const {};
    return GameState(
      schemaVersion: 4,
      energy: (json['energy'] as num?)?.toInt() ?? 100,
      energyUpdatedAt: DateTime.parse(json['energyUpdatedAt'] as String),
      xp: {
        for (final type in StatType.values)
          type: (xpJson[type.name] as num?)?.toInt() ?? 0,
      },
      daily: DailySelection.fromJson(
        json['daily'] as Map<String, dynamic>? ?? const {},
      ),
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      completedByDate: {
        for (final entry
            in (json['completedByDate'] as Map<String, dynamic>? ?? const {})
                .entries)
          entry.key: (entry.value as List<dynamic>)
              .map((item) => item as String)
              .toList(growable: false),
      },
      trainedQuestIds: (json['trainedQuestIds'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toSet(),
      modifierDice: ModifierDiceState.fromJson(
        json['modifierDice'] as Map<String, dynamic>? ?? const {},
      ),
      preparedModifierIds: {
        for (final entry
            in (json['preparedModifierIds'] as Map<String, dynamic>? ??
                    const {})
                .entries)
          entry.key: entry.value as String,
      },
      onboarding: OnboardingState.fromJson(
        json['onboarding'] as Map<String, dynamic>? ?? const {},
      ),
      activeQuest: json['activeQuest'] == null
          ? null
          : ActiveQuest.fromJson(json['activeQuest'] as Map<String, dynamic>),
    );
  }

  final int schemaVersion;
  final int energy;
  final DateTime energyUpdatedAt;
  final Map<StatType, int> xp;
  final DailySelection daily;
  final ActiveQuest? activeQuest;
  final int completedCount;
  final Map<String, List<String>> completedByDate;
  final Set<String> trainedQuestIds;
  final ModifierDiceState modifierDice;
  final Map<String, String> preparedModifierIds;
  final OnboardingState onboarding;

  bool get onboardingComplete => completedCount >= 3;

  int get totalXp => xp.values.fold(0, (sum, value) => sum + value);

  GameState copyWith({
    int? energy,
    DateTime? energyUpdatedAt,
    Map<StatType, int>? xp,
    DailySelection? daily,
    Object? activeQuest = _unset,
    int? completedCount,
    Map<String, List<String>>? completedByDate,
    Set<String>? trainedQuestIds,
    ModifierDiceState? modifierDice,
    Map<String, String>? preparedModifierIds,
    OnboardingState? onboarding,
  }) {
    return GameState(
      schemaVersion: schemaVersion,
      energy: energy ?? this.energy,
      energyUpdatedAt: energyUpdatedAt ?? this.energyUpdatedAt,
      xp: xp ?? this.xp,
      daily: daily ?? this.daily,
      activeQuest: identical(activeQuest, _unset)
          ? this.activeQuest
          : activeQuest as ActiveQuest?,
      completedCount: completedCount ?? this.completedCount,
      completedByDate: completedByDate ?? this.completedByDate,
      trainedQuestIds: trainedQuestIds ?? this.trainedQuestIds,
      modifierDice: modifierDice ?? this.modifierDice,
      preparedModifierIds: preparedModifierIds ?? this.preparedModifierIds,
      onboarding: onboarding ?? this.onboarding,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'energy': energy,
    'energyUpdatedAt': energyUpdatedAt.toUtc().toIso8601String(),
    'xp': {for (final entry in xp.entries) entry.key.name: entry.value},
    'daily': daily.toJson(),
    'activeQuest': activeQuest?.toJson(),
    'completedCount': completedCount,
    'completedByDate': completedByDate,
    'trainedQuestIds': trainedQuestIds.toList(growable: false),
    'modifierDice': modifierDice.toJson(),
    'preparedModifierIds': preparedModifierIds,
    'onboarding': onboarding.toJson(),
  };
}
