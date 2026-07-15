import 'backend_models.dart';

abstract interface class RemoteFlagCache {
  Future<void> save({
    required Iterable<RemoteFlagRecord> records,
    required DateTime fetchedAt,
    required DateTime expiresAt,
  });
}
