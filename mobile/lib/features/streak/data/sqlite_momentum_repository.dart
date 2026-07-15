import 'dart:convert';

import '../../../infrastructure/sqlite/sqlite_vnext_context.dart';
import '../../../infrastructure/sqlite/sqlite_vnext_mappers.dart';
import '../domain/momentum_repository.dart';
import '../domain/momentum_state.dart';

class SqliteMomentumRepository implements MomentumRepository {
  const SqliteMomentumRepository(this.context);

  final SqliteVNextContext context;

  @override
  Future<MomentumState> loadMomentum() {
    return context.database.read((db) async {
      final rows = await db.query(
        'projection_checkpoints',
        where: 'projection_name = ?',
        whereArgs: [SqliteVNextContext.momentumProjection],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return SqliteProjectionMapper.momentumFromJson(
          jsonDecode(rows.single['snapshot_json'] as String)
              as Map<String, dynamic>,
        );
      }
      final progressRows = await db.query(
        'projection_checkpoints',
        where: 'projection_name = ?',
        whereArgs: [SqliteVNextContext.progressProjection],
        limit: 1,
      );
      return progressRows.isEmpty
          ? MomentumState.empty()
          : SqliteProjectionMapper.progressFromRow(
              progressRows.single,
            ).momentum;
    });
  }

  @override
  Future<void> saveMomentum(MomentumState state) {
    return context.database.transaction(
      (db) => context.saveMomentum(db, state),
    );
  }
}
