import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/domain/models/quest.dart';
import 'package:mayhem_mobile/features/progress/domain/legacy_progress_mapper.dart';
import 'package:mayhem_mobile/features/progress/domain/progress_models.dart';

void main() {
  const mapper = LegacyProgressMapper();

  test('legacy stats map to four traits without losing total XP', () {
    final profile = mapper.map(const {
      StatType.charisma: 100,
      StatType.boldness: 100,
      StatType.networking: 100,
    });

    expect(profile.totalXp, 300);
    expect(profile.traitXp, {
      Trait.initiation: 95,
      Trait.expression: 65,
      Trait.connection: 75,
      Trait.presence: 65,
    });
  });

  test('largest-remainder rounding is deterministic for small totals', () {
    final first = mapper.map(const {
      StatType.charisma: 1,
      StatType.boldness: 1,
      StatType.networking: 1,
    });
    final second = mapper.map(const {
      StatType.charisma: 1,
      StatType.boldness: 1,
      StatType.networking: 1,
    });

    expect(first.traitXp, second.traitXp);
    expect(first.totalXp, 3);
    expect(first.traitXp[Trait.initiation], 1);
    expect(first.traitXp[Trait.connection], 1);
    expect(first.traitXp[Trait.expression], 1);
    expect(first.traitXp[Trait.presence], 0);
  });

  test('negative legacy XP is rejected instead of silently normalized', () {
    expect(
      () => mapper.map(const {StatType.boldness: -1}),
      throwsFormatException,
    );
  });
}
