import 'package:sqflite/sqflite.dart';

import 'v6_feed_vertical_slice_sql.g.dart';

abstract final class V6FeedVerticalSliceMigration {
  static Future<void> apply(DatabaseExecutor db) async {
    for (final statement in v6FeedVerticalSliceStatements) {
      await db.execute(statement);
    }
  }
}
