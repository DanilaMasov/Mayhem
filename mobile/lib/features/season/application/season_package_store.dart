import '../../sync/domain/backend_models.dart';
import '../domain/season_models.dart';

abstract interface class SeasonPackageStore {
  Future<SeasonPackage?> loadCachedPackage();

  Future<SeasonPackage?> loadActivePackage(DateTime atUtc);

  Future<void> saveValidatedSnapshot(RemoteSeasonSnapshot snapshot);

  Future<void> clear();
}
