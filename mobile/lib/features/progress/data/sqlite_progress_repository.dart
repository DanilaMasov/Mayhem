import '../../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/progress_models.dart';
import '../domain/progress_repository.dart';

class SqliteProgressRepository implements ProgressRepository {
  const SqliteProgressRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<ProgressProjection?> loadProjection() {
    return context.database.read((db) async {
      final rows = await db.query(
        'projection_checkpoints',
        where: 'projection_name = ?',
        whereArgs: [SqliteVNextContext.progressProjection],
        limit: 1,
      );
      return rows.isEmpty
          ? null
          : SqliteProjectionMapper.progressFromRow(rows.single);
    });
  }

  @override
  Future<void> saveProjection(ProgressProjection projection) {
    return context.database.transaction(
      (db) => context.saveProgress(db, projection),
    );
  }
}
