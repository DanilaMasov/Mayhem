import 'progress_models.dart';

abstract interface class ProgressRepository {
  Future<ProgressProjection?> loadProjection();

  Future<void> saveProjection(ProgressProjection projection);
}
