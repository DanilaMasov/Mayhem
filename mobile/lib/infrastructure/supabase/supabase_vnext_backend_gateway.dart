import '../../features/sync/domain/backend_models.dart';
import '../../core/sync/event_envelope_v2.dart';
import 'supabase_event_sync_transport.dart';

class SupabaseVNextBackendGateway implements VNextBackendGateway {
  const SupabaseVNextBackendGateway(this.rpc);

  final SupabaseRpcClient rpc;

  @override
  Future<InstallationRegistration> registerInstallation({
    required String installationId,
    required String localUserId,
    required String platform,
    required String appVersion,
    required CapabilityRevisionSet capabilities,
  }) async => InstallationRegistration.fromJson(
    await rpc.invoke('register_installation', {
      'p_installation_id': installationId,
      'p_local_user_id': localUserId,
      'p_platform': platform,
      'p_app_version': appVersion,
      'p_capabilities': capabilities.toJson(),
    }),
  );

  @override
  Future<BootstrapPayload> getBootstrapPayload({
    required String installationId,
    required String locale,
    String environment = 'production',
  }) async => BootstrapPayload.fromJson(
    await rpc.invoke('get_bootstrap_payload', {
      'p_installation_id': installationId,
      'p_environment': environment,
      'p_locale': locale,
    }),
  );

  @override
  Future<EventIngestAckV2> ingestEvents({
    required String installationId,
    required List<EventEnvelopeV2> events,
  }) async {
    if (events.length > 100) {
      throw const FormatException('Sync batch must not exceed 100 events');
    }
    final requestedIds = events.map((event) => event.eventId).toSet();
    if (requestedIds.length != events.length) {
      throw const FormatException('Sync batch event IDs must be unique');
    }
    final ack = EventIngestAckV2.fromJson(
      await rpc.invoke('ingest_events_v2', {
        'p_installation_id': installationId,
        'p_events': events.map((event) => event.toSyncJson()).toList(),
      }),
    );
    final resultIds = ack.results.map((result) => result.eventId).toSet();
    if (resultIds.length != requestedIds.length ||
        !resultIds.containsAll(requestedIds)) {
      throw const FormatException(
        'Sync acknowledgement does not match the submitted batch',
      );
    }
    return ack;
  }

  @override
  Future<RemoteContentManifest> getContentManifest({
    String locale = 'ru',
  }) async => RemoteContentManifest.fromJson(
    await rpc.invoke('get_content_manifest', {'p_locale': locale}),
  );

  @override
  Future<List<RemoteContentRevision>> getContentRevisions(
    List<ContentManifestReference> revisions,
  ) async {
    if (revisions.length > 100) {
      throw const FormatException(
        'Content request must not exceed 100 revisions',
      );
    }
    final value = await rpc.invokeValue('get_content_revisions', {
      'p_requests': revisions
          .map((revision) => revision.toRequestJson())
          .toList(growable: false),
    });
    if (value is! List) {
      throw const FormatException(
        'Content revisions response must be an array',
      );
    }
    return value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Content revision must be an object');
          }
          return RemoteContentRevision.fromJson(
            Map<String, dynamic>.from(item),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<RemoteFeedBatch> getFeedBatch({
    String locale = 'ru',
    int limit = 20,
  }) async => RemoteFeedBatch.fromJson(
    await rpc.invoke('get_feed_batch', {'p_locale': locale, 'p_limit': limit}),
  );

  @override
  Future<RemoteSeasonSnapshot?> getActiveSeason() async {
    final value = await rpc.invokeValue('get_active_season', const {});
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('Active season response must be an object');
    }
    return RemoteSeasonSnapshot.fromJson(Map<String, dynamic>.from(value));
  }

  @override
  Future<DataDeletionReceipt> deleteMyData() async =>
      DataDeletionReceipt.fromJson(
        await rpc.invoke('delete_my_data', const {}),
      );
}
