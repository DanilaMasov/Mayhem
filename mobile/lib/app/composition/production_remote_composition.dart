import '../../core/auth/anonymous_session_coordinator.dart';
import '../../core/auth/secure_session_store.dart';
import '../../core/feature_flags/feature_flag_runtime.dart';
import '../../features/feed/application/remote_feed_refresh_service.dart';
import '../../features/season/application/season_bootstrap_activator.dart';
import '../../features/settings/application/delete_everywhere_coordinator.dart';
import '../../features/settings/application/delete_everywhere_recovery_store.dart';
import '../../features/settings/application/remote_account_controller.dart';
import '../../features/sync/application/remote_content_refresh_service.dart';
import '../../features/sync/application/vnext_sync_coordinator.dart';
import '../../infrastructure/sqlite/sqlite_vnext_store.dart';
import '../../infrastructure/supabase/dart_io_json_http_executor.dart';
import '../../infrastructure/supabase/supabase_anonymous_auth_gateway.dart';
import '../../infrastructure/supabase/supabase_event_sync_transport.dart';
import '../../infrastructure/supabase/supabase_runtime_config.dart';
import '../../infrastructure/supabase/supabase_vnext_backend_gateway.dart';
import 'production_app_remote_orchestrator.dart';

class ProductionRemoteComposition {
  ProductionRemoteComposition._({
    required this.orchestrator,
    required this.account,
    required this.sync,
  });

  factory ProductionRemoteComposition.build({
    required SupabaseRuntimeConfig config,
    required SecureSessionStore secureSessions,
    required DeleteEverywhereRecoveryStore deletionRecovery,
    required SqliteVNextStore store,
    required FeatureFlagRuntime featureFlags,
    required String platform,
    required String appVersion,
    required String environment,
    required DateTime Function() clock,
    required Future<void> Function() clearLocalData,
    Future<void> Function()? onProjectionCommitted,
    Future<void> Function()? onSeasonStateCommitted,
    Future<void> Function()? onRemoteFeedCommitted,
  }) {
    final http = const DartIoJsonHttpExecutor();
    final auth = SupabaseAnonymousAuthGateway(
      config: config,
      http: http,
      clock: clock,
    );
    final sessions = AnonymousSessionCoordinator(
      gateway: auth,
      store: secureSessions,
    );
    final rpc = SupabaseRpcClient(
      config: config,
      accessTokenProvider: () async =>
          (await secureSessions.read())?.accessToken,
      http: http,
      refreshSession: () async {
        await sessions.refreshSession();
      },
    );
    final backend = SupabaseVNextBackendGateway(rpc);
    final sync = VNextSyncCoordinator(
      remoteOperationsEnabled: true,
      sessions: sessions,
      backend: backend,
      identity: store.identity,
      identityBinding: store.identity,
      events: store.eventSync,
      progress: store.progress,
      reconciliationStore: store.reconciliation,
      content: store.content,
      contentRefresh: RemoteContentRefreshService(
        backend: backend,
        content: store.content,
      ),
      remoteFeed: RemoteFeedRefreshService(
        backend: backend,
        feed: store.feed,
        attempts: store.challenge,
        identity: store.identity,
        content: store.content,
        clock: clock,
      ),
      flagCache: store.remoteFlags,
      featureFlags: featureFlags,
      seasonActivation: SeasonBootstrapActivator(
        localActivationEnabled: true,
        store: store.season,
        participation: store.seasonParticipation,
        actions: store.seasonActions,
      ),
      platform: platform,
      appVersion: appVersion,
      environment: environment,
      clock: clock,
      onProjectionCommitted: onProjectionCommitted,
      onSeasonStateCommitted: onSeasonStateCommitted,
      onRemoteFeedCommitted: onRemoteFeedCommitted,
    );
    final deletion = DeleteEverywhereCoordinator(
      backend: backend,
      sessions: secureSessions,
      recovery: deletionRecovery,
      clearLocalData: clearLocalData,
    );
    final account = RemoteAccountController(
      sessions: secureSessions,
      deletion: deletion,
      synchronize: (trigger) => sync.synchronize(trigger: trigger),
      clock: clock,
    );
    return ProductionRemoteComposition._(
      orchestrator: ProductionAppRemoteOrchestrator(
        sync: sync,
        account: account,
      ),
      account: account,
      sync: sync,
    );
  }

  final ProductionAppRemoteOrchestrator orchestrator;
  final RemoteAccountController account;
  final VNextSyncCoordinator sync;
}
