import '../../../domain/models/quest.dart';
import 'progress_models.dart';

class LegacyTraitProfile {
  LegacyTraitProfile({required Map<Trait, int> traitXp})
    : traitXp = Map.unmodifiable(traitXp);

  final Map<Trait, int> traitXp;

  int get totalXp => traitXp.values.fold(0, (sum, value) => sum + value);
}

class LegacyProgressMapper {
  const LegacyProgressMapper();

  LegacyTraitProfile map(Map<StatType, int> legacyXp) {
    final charisma = _nonNegative(legacyXp[StatType.charisma] ?? 0);
    final boldness = _nonNegative(legacyXp[StatType.boldness] ?? 0);
    final networking = _nonNegative(legacyXp[StatType.networking] ?? 0);

    final weightedHundredths = <Trait, int>{
      Trait.initiation: boldness * 70 + networking * 25,
      Trait.expression: charisma * 65,
      Trait.connection: networking * 75,
      Trait.presence: charisma * 35 + boldness * 30,
    };
    final allocated = <Trait, int>{
      for (final entry in weightedHundredths.entries)
        entry.key: entry.value ~/ 100,
    };
    final target = charisma + boldness + networking;
    var remaining = target - allocated.values.fold(0, (a, b) => a + b);
    final remainderOrder = Trait.values.toList(growable: false)
      ..sort((left, right) {
        final byRemainder = (weightedHundredths[right]! % 100).compareTo(
          weightedHundredths[left]! % 100,
        );
        return byRemainder != 0
            ? byRemainder
            : Trait.values.indexOf(left).compareTo(Trait.values.indexOf(right));
      });
    for (final trait in remainderOrder) {
      if (remaining == 0) break;
      allocated[trait] = allocated[trait]! + 1;
      remaining -= 1;
    }
    return LegacyTraitProfile(traitXp: allocated);
  }

  int _nonNegative(int value) {
    if (value < 0) {
      throw const FormatException('Legacy XP must not be negative');
    }
    return value;
  }
}
