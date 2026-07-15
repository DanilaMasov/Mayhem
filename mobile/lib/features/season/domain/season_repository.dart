import 'season_models.dart';

abstract interface class SeasonRepository {
  Future<Season?> activeSeason(DateTime atUtc);

  Future<void> save(Season season);
}
