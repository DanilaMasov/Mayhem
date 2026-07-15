import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayhem_mobile/core/auth/remote_auth_session.dart';
import 'package:mayhem_mobile/core/sync/event_envelope_v2.dart';
import 'package:mayhem_mobile/domain/models/game_event.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_event_sync_transport.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_anonymous_auth_gateway.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_runtime_config.dart';
import 'package:mayhem_mobile/infrastructure/supabase/supabase_vnext_backend_gateway.dart';
import 'package:mayhem_mobile/features/sync/domain/backend_models.dart';
import 'package:mayhem_mobile/features/sync/domain/remote_content_checksum.dart';
import 'package:mayhem_mobile/content/domain/content_item_revision.dart';

import '../support/fakes.dart';

void main() {
  const config = SupabaseRuntimeConfig(
    projectUrl: 'https://project.supabase.co',
    anonKey: 'public-anon-key',
  );

  test('transport sends the canonical authenticated RPC request', () async {
    final http = FakeJsonHttpExecutor(
      response: const JsonHttpResponse(
        statusCode: 200,
        body:
            '{"acceptedIds":["event-id"],"rejectedById":{},"stats":{"energy":90}}',
      ),
    );
    final rpc = SupabaseRpcClient(
      config: config,
      accessTokenProvider: () async => 'access-token',
      http: http,
    );
    final transport = SupabaseEventSyncTransport(
      rpc: rpc,
      installationId: '11111111-1111-4111-8111-111111111111',
    );
    final event = GameEvent(
      id: 'event-id',
      type: GameEventType.guideOpened,
      questId: 'q_c_001',
      createdAt: DateTime.utc(2026, 7, 12, 12),
      payload: const {'guideId': 'guide_q_c_001'},
    );

    final ack = await transport.pushEvents([event]);
    expect(ack.acceptedIds, {'event-id'});
    expect(
      http.uri.toString(),
      '${config.projectUrl}/rest/v1/rpc/ingest_quest_events',
    );
    expect(http.headers?['apikey'], config.anonKey);
    expect(http.headers?['authorization'], 'Bearer access-token');
    final body = jsonDecode(http.body!) as Map<String, dynamic>;
    expect(body['p_installation_id'], '11111111-1111-4111-8111-111111111111');
    expect(
      (body['p_events'] as List<dynamic>).single['eventType'],
      'guide_opened',
    );
  });

  test('missing auth session fails before any HTTP request', () async {
    final http = FakeJsonHttpExecutor(
      response: const JsonHttpResponse(statusCode: 200, body: '{}'),
    );
    final rpc = SupabaseRpcClient(
      config: config,
      accessTokenProvider: () async => null,
      http: http,
    );

    await expectLater(
      () => rpc.invoke('ingest_quest_events', const {}),
      throwsA(
        isA<SupabaseRpcException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(http.calls, 0);
  });

  test('RPC errors expose bounded server detail and never the token', () async {
    final longMessage = 'private-access-token${'x' * 400}';
    final http = FakeJsonHttpExecutor(
      response: JsonHttpResponse(
        statusCode: 422,
        body: jsonEncode({'message': longMessage}),
      ),
    );
    final rpc = SupabaseRpcClient(
      config: config,
      accessTokenProvider: () async => 'private-access-token',
      http: http,
    );

    try {
      await rpc.invoke('ingest_quest_events', const {});
      fail('RPC error expected');
    } on SupabaseRpcException catch (error) {
      expect(error.statusCode, 422);
      expect(error.message.length, 240);
      expect(error.toString(), isNot(contains('private-access-token')));
    }
  });

  test('installation identity is stable until local data deletion', () async {
    final store = MemoryGameStore();
    var generated = 0;
    String generator() => 'installation_${generated++}';

    expect(await store.getOrCreateInstallationId(generator), 'installation_0');
    expect(await store.getOrCreateInstallationId(generator), 'installation_0');
    expect(generated, 1);
    await store.clear();
    expect(await store.getOrCreateInstallationId(generator), 'installation_1');
  });

  test(
    'vNext gateway accepts typed array responses for immutable content',
    () async {
      final item = <String, dynamic>{
        'contentId': 'challenge_remote',
        'revision': 2,
        'locale': 'ru',
        'type': 'challenge',
        'payload': {
          'title': 'Remote challenge',
          'primaryTrait': 'presence',
          'intensity': 3,
        },
        'safety': {
          'safetyReviewed': true,
          'safetyRevision': 1,
          'requiresContextWarning': false,
          'disallowedContexts': <String>[],
          'lowPressureRoute': 'Lower pressure',
          'exitCopy': 'Stop safely',
        },
        'media': null,
        'active': true,
        'publishedAt': '2026-07-13T12:00:00.000Z',
        'startsAt': null,
        'endsAt': null,
      };
      item['checksum'] = RemoteContentChecksum.compute(item);
      final http = FakeJsonHttpExecutor(
        response: JsonHttpResponse(statusCode: 200, body: jsonEncode([item])),
      );
      final gateway = SupabaseVNextBackendGateway(
        SupabaseRpcClient(
          config: config,
          accessTokenProvider: () async => 'access-token',
          http: http,
        ),
      );

      final revisions = await gateway.getContentRevisions([
        ContentManifestReference(
          contentId: 'challenge_remote',
          revision: 2,
          locale: 'ru',
          type: ContentItemType.challenge,
          checksum: item['checksum'] as String,
        ),
      ]);

      expect(revisions.single.revision.revision, 2);
      expect(
        http.uri.toString(),
        '${config.projectUrl}/rest/v1/rpc/get_content_revisions',
      );
      expect(
        (jsonDecode(http.body!) as Map<String, dynamic>)['p_requests'],
        hasLength(1),
      );
    },
  );

  test('anonymous auth adapter creates a typed expiring session', () async {
    final http = FakeJsonHttpExecutor(
      response: const JsonHttpResponse(
        statusCode: 200,
        body:
            '{"access_token":"access-secret","refresh_token":"refresh-secret",'
            '"expires_in":3600,"user":{"id":"remote-user","is_anonymous":true}}',
      ),
    );
    final auth = SupabaseAnonymousAuthGateway(
      config: config,
      http: http,
      clock: () => DateTime.utc(2026, 7, 13, 12),
    );

    final session = await auth.signInAnonymously();

    expect(session.remoteUserId, 'remote-user');
    expect(session.expiresAt, DateTime.utc(2026, 7, 13, 13));
    expect(http.uri.toString(), '${config.projectUrl}/auth/v1/signup');
    expect(http.headers?['apikey'], config.anonKey);
    expect(jsonDecode(http.body!), isEmpty);
  });

  test('auth refresh errors redact refresh tokens', () async {
    final http = FakeJsonHttpExecutor(
      response: const JsonHttpResponse(
        statusCode: 401,
        body: '{"message":"invalid refresh-secret"}',
      ),
    );
    final auth = SupabaseAnonymousAuthGateway(
      config: config,
      http: http,
      clock: () => DateTime.utc(2026, 7, 13, 12),
    );
    final current = RemoteAuthSession(
      remoteUserId: 'remote-user',
      accessToken: 'access-secret',
      refreshToken: 'refresh-secret',
      expiresAt: DateTime.utc(2026, 7, 13, 11),
      isAnonymous: true,
    );

    try {
      await auth.refresh(current);
      fail('Auth error expected');
    } on SupabaseAuthException catch (error) {
      expect(error.toString(), isNot(contains('refresh-secret')));
      expect(error.toString(), contains('<redacted>'));
    }
  });

  test(
    'vNext ingestion rejects an acknowledgement for another batch',
    () async {
      final response = <String, dynamic>{
        'results': [
          {
            'eventId': 'other-event',
            'accepted': true,
            'disposition': 'accepted',
          },
        ],
        'projection': _projectionJson(),
        'serverTime': '2026-07-13T12:00:00.000Z',
      };
      final gateway = SupabaseVNextBackendGateway(
        SupabaseRpcClient(
          config: config,
          accessTokenProvider: () async => 'access-token',
          http: FakeJsonHttpExecutor(
            response: JsonHttpResponse(
              statusCode: 200,
              body: jsonEncode(response),
            ),
          ),
        ),
      );

      await expectLater(
        () => gateway.ingestEvents(
          installationId: '11111111-1111-4111-8111-111111111111',
          events: [_v2Event()],
        ),
        throwsFormatException,
      );
    },
  );

  test('vNext projection exposes server-issued artifact ownership', () async {
    final projection = _projectionJson();
    projection['ownedArtifacts'] = [
      {
        'artifactId': 'founder_social_reset',
        'seasonId': 'season_social_reset_0',
        'seasonRevision': 1,
        'bossEventId': 'boss_social_reset',
        'unlockedAt': '2026-07-13T12:00:00.000Z',
      },
    ];
    final response = <String, dynamic>{
      'results': [
        {'eventId': 'event-1', 'accepted': true, 'disposition': 'accepted'},
      ],
      'projection': projection,
      'serverTime': '2026-07-13T12:00:00.000Z',
    };
    final gateway = SupabaseVNextBackendGateway(
      SupabaseRpcClient(
        config: config,
        accessTokenProvider: () async => 'access-token',
        http: FakeJsonHttpExecutor(
          response: JsonHttpResponse(
            statusCode: 200,
            body: jsonEncode(response),
          ),
        ),
      ),
    );

    final ack = await gateway.ingestEvents(
      installationId: '11111111-1111-4111-8111-111111111111',
      events: [_v2Event()],
    );

    expect(
      ack.projection.ownedArtifacts.single.artifactId,
      'founder_social_reset',
    );
    expect(
      ack.projection.ownedArtifacts.single.bossEventId,
      'boss_social_reset',
    );
  });

  test('vNext gateway exposes the active season as a typed snapshot', () async {
    final gateway = SupabaseVNextBackendGateway(
      SupabaseRpcClient(
        config: config,
        accessTokenProvider: () async => 'access-token',
        http: FakeJsonHttpExecutor(
          response: const JsonHttpResponse(
            statusCode: 200,
            body:
                '{"seasonId":"season-1","revision":2,"title":"Reset",'
                '"startsAt":"2026-07-01T00:00:00.000Z",'
                '"endsAt":"2026-08-01T00:00:00.000Z","payload":{}}',
          ),
        ),
      ),
    );

    final season = await gateway.getActiveSeason();

    expect(season?.seasonId, 'season-1');
    expect(season?.revision, 2);
  });
}

EventEnvelopeV2 _v2Event() => EventEnvelopeV2(
  eventId: 'event-1',
  eventType: CanonicalEventTypeV2.feedItemOpened,
  localUserId: 'local-user',
  remoteUserId: 'remote-user',
  installationId: '11111111-1111-4111-8111-111111111111',
  clientSequence: 1,
  occurredAtUtc: DateTime.utc(2026, 7, 13, 12),
  timezoneId: 'Europe/Moscow',
  timezoneOffsetMinutes: 180,
  assignmentId: 'assignment-1',
  attemptId: null,
  contentId: 'challenge-1',
  contentRevision: 1,
  payload: const {},
);

Map<String, Object?> _projectionJson() => {
  'totalXp': 0,
  'traitXp': const {
    'initiation': 0,
    'expression': 0,
    'connection': 0,
    'presence': 0,
  },
  'rank': const {
    'family': 'spark',
    'tier': 1,
    'configRevision': 'rank_config_dev_v1',
  },
  'difficulty': const {},
  'completedCount': 0,
  'attemptedCount': 0,
  'updatedAt': '2026-07-13T12:00:00.000Z',
  'rewardPolicyRevision': 'reward_policy_dev_v1',
  'projectionRevision': 0,
  'momentum': const {
    'currentDays': 0,
    'longestDays': 0,
    'shieldsAvailable': 0,
    'lastEarnedLocalDate': null,
    'lastEarnedAtUtc': null,
    'lastEarnedTimezoneId': null,
    'protectedLocalDates': <String>[],
    'pendingLocalDate': null,
    'pendingEarnedAtUtc': null,
    'pendingTimezoneId': null,
    'policyRevision': 'momentum_policy_dev_v1',
    'projectionRevision': 0,
  },
};

class FakeJsonHttpExecutor implements JsonHttpExecutor {
  FakeJsonHttpExecutor({required this.response});

  final JsonHttpResponse response;
  int calls = 0;
  Uri? uri;
  Map<String, String>? headers;
  String? body;

  @override
  Future<JsonHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    calls += 1;
    this.uri = uri;
    this.headers = Map.unmodifiable(headers);
    this.body = body;
    return response;
  }
}
