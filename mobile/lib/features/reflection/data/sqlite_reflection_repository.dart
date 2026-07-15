import '../../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/private_reflection.dart';
import '../domain/reflection_repository.dart';

class SqliteReflectionRepository implements ReflectionRepository {
  const SqliteReflectionRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<PrivateReflection?> findForAttempt(String attemptId) {
    return context.database.read((db) async {
      final rows = await db.query(
        'private_reflections',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      return rows.isEmpty ? null : SqliteReflectionMapper.fromRow(rows.single);
    });
  }

  @override
  Future<void> saveReflection(PrivateReflection reflection) {
    reflection.validate();
    return context.database.transaction(
      (db) => context.saveReflection(db, reflection),
    );
  }

  @override
  Future<void> deleteForAttempt(String attemptId) {
    return context.database.transaction((db) async {
      await db.delete(
        'private_reflections',
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
      );
    });
  }
}
