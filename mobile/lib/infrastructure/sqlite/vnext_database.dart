import 'package:sqflite/sqflite.dart';

typedef VNextDatabaseOperation<T> = Future<T> Function(DatabaseExecutor db);

abstract interface class VNextDatabase {
  Future<T> read<T>(VNextDatabaseOperation<T> operation);

  Future<T> transaction<T>(VNextDatabaseOperation<T> operation);
}

class SqfliteVNextDatabase implements VNextDatabase {
  const SqfliteVNextDatabase(this.database);

  final Database database;

  @override
  Future<T> read<T>(VNextDatabaseOperation<T> operation) => operation(database);

  @override
  Future<T> transaction<T>(VNextDatabaseOperation<T> operation) {
    return database.transaction(operation);
  }
}
