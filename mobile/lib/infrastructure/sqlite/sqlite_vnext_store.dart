import '../../content/data/sqlite_content_repository.dart';
import '../../features/challenge/data/sqlite_challenge_repository.dart';
import '../../features/feed/data/sqlite_feed_repository.dart';
import '../../features/progress/data/sqlite_progress_repository.dart';
import '../../features/reflection/data/sqlite_reflection_repository.dart';
import '../../features/streak/data/sqlite_momentum_repository.dart';
import 'sqlite_local_identity_repository.dart';
import 'sqlite_local_metadata_repository.dart';
import 'sqlite_event_sync_store_v2.dart';
import 'sqlite_projection_reconciliation_store.dart';
import 'sqlite_remote_feature_flag_cache.dart';
import 'sqlite_season_package_store.dart';
import 'sqlite_season_participation_repository.dart';
import 'sqlite_vnext_context.dart';
import 'vnext_database.dart';

/// Composition root for feature-scoped vNext SQLite adapters.
class SqliteVNextStore {
  SqliteVNextStore(VNextDatabase database, {DateTime Function()? clock})
    : context = SqliteVNextContext(database, clock: clock) {
    identity = SqliteLocalIdentityRepository(context);
    metadata = SqliteLocalMetadataRepository(context);
    content = SqliteContentRepository(context);
    feed = SqliteFeedRepository(context);
    challenge = SqliteChallengeRepository(context);
    progress = SqliteProgressRepository(context);
    momentum = SqliteMomentumRepository(context);
    reflection = SqliteReflectionRepository(context);
    eventSync = SqliteEventSyncStoreV2(context);
    reconciliation = SqliteProjectionReconciliationStore(context);
    remoteFlags = SqliteRemoteFeatureFlagCache(context);
    season = SqliteSeasonPackageStore(context);
    seasonParticipation = SqliteSeasonParticipationRepository(context);
  }

  final SqliteVNextContext context;
  late final SqliteLocalIdentityRepository identity;
  late final SqliteLocalMetadataRepository metadata;
  late final SqliteContentRepository content;
  late final SqliteFeedRepository feed;
  late final SqliteChallengeRepository challenge;
  late final SqliteProgressRepository progress;
  late final SqliteMomentumRepository momentum;
  late final SqliteReflectionRepository reflection;
  late final SqliteEventSyncStoreV2 eventSync;
  late final SqliteProjectionReconciliationStore reconciliation;
  late final SqliteRemoteFeatureFlagCache remoteFlags;
  late final SqliteSeasonPackageStore season;
  late final SqliteSeasonParticipationRepository seasonParticipation;
}
