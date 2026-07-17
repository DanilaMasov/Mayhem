import { createHash } from "node:crypto";

export const r2ProbeNames = Object.freeze([
  "migrations_from_zero",
  "authentication_and_session_refresh",
  "installation_ownership_and_rls",
  "direct_write_and_grant_security",
  "exact_duplicate_partial_ack_and_auth_recovery",
  "season_join_day_and_window_rules",
  "concurrent_boss_artifact_and_social_proof",
  "flutter_client_contract",
  "delete_everywhere_and_cross_user_survival"
]);

export class LiveProbeRecorder {
  constructor({ names = r2ProbeNames, clock = Date.now } = {}) {
    this.names = [...names];
    this.clock = clock;
    this.startedAtMs = clock();
    this.probes = [];
  }

  async run(name, action) {
    if (!this.names.includes(name) || this.probes.some((probe) => probe.name === name)) {
      throw new Error(`R2 probe name is invalid or duplicated: ${name}`);
    }
    const startedAtMs = this.clock();
    try {
      const value = await action();
      this.probes.push(probeResult(name, "passed", startedAtMs, this.clock()));
      return value;
    } catch (error) {
      this.probes.push(probeResult(name, "failed", startedAtMs, this.clock()));
      const failure = new Error(
        `R2 probe failed: ${name} (${error?.name ?? "Error"})`
      );
      failure.cause = error;
      throw failure;
    }
  }

  report({ environment, migrationVersions, result }) {
    const completedAtMs = this.clock();
    const completed = new Set(this.probes.map((probe) => probe.name));
    return Object.freeze({
      environment,
      migrationVersions: [...migrationVersions],
      startedAt: new Date(this.startedAtMs).toISOString(),
      completedAt: new Date(completedAtMs).toISOString(),
      durationMs: Math.max(0, completedAtMs - this.startedAtMs),
      probes: this.probes.map((probe) => Object.freeze({ ...probe })),
      passed: this.probes
        .filter((probe) => probe.status === "passed")
        .map((probe) => probe.name),
      failed: this.probes
        .filter((probe) => probe.status === "failed")
        .map((probe) => probe.name),
      blocked: [],
      notRun: this.names.filter((name) => !completed.has(name)),
      result
    });
  }
}

function probeResult(name, status, startedAtMs, completedAtMs) {
  return {
    name,
    status,
    durationMs: Math.max(0, completedAtMs - startedAtMs)
  };
}

export const r2Fixture = Object.freeze({
  seasonId: "r2-live-season",
  closedSeasonId: "r2-closed-season",
  bossEventId: "r2-live-boss",
  futureBossEventId: "r2-future-boss",
  contentId: "r2-live-boss-content",
  contentRevision: 1,
  artifactId: "r2-live-founder",
  socialKey: "r2-live-social-proof",
  socialThreshold: 20,
  manifestId: "70000000-0000-4000-8000-000000000001"
});

const contentSafety = Object.freeze({
  safetyReviewed: true,
  safetyRevision: 1,
  requiresContextWarning: false,
  disallowedContexts: [],
  lowPressureRoute: "Use the lower-pressure route.",
  exitCopy: "Stop whenever you need.",
  advancedRouteSafetyApproved: false
});

const r2ContentItems = Object.freeze(
  Array.from({ length: 20 }, (_, index) => {
    const contentId =
      index === 0
        ? r2Fixture.contentId
        : `r2-live-feed-${String(index + 1).padStart(2, "0")}`;
    const payload = Object.freeze({
      title: `R2 live challenge ${index + 1}`,
      primaryTrait: "presence",
      intensity: 3,
      baseXp: 100,
      momentumEligible: true
    });
    const checksum = createHash("sha256")
      .update(
        canonicalJson({
          contentId,
          revision: r2Fixture.contentRevision,
          locale: "ru",
          type: "challenge",
          payload,
          safety: contentSafety,
          media: null
        })
      )
      .digest("hex");
    return Object.freeze({ contentId, payload, checksum });
  })
);

export const r2ContentChecksum = r2ContentItems[0].checksum;

export const r2FixtureSql = `
insert into public.content_item_revisions (
  content_id, revision, locale, content_type, payload, safety, media,
  checksum, active, published_at
) values
${r2ContentItems
  .map(
    (item) => `(
  '${item.contentId}', ${r2Fixture.contentRevision}, 'ru', 'challenge',
  '${JSON.stringify(item.payload)}'::jsonb,
  '${JSON.stringify(contentSafety)}'::jsonb,
  null, '${item.checksum}', true, now() - interval '1 day'
)`
  )
  .join(",\n")};

insert into public.content_manifests (
  manifest_id, locale, revision, checksum, generated_at, active
) values (
  '${r2Fixture.manifestId}'::uuid, 'ru', 1,
  '${r2ContentChecksum}', now() - interval '1 hour', true
);

insert into public.content_manifest_items (
  manifest_id, locale, position, content_id, content_revision
) values
${r2ContentItems
  .map(
    (item, index) => `(
  '${r2Fixture.manifestId}'::uuid, 'ru', ${index},
  '${item.contentId}', ${r2Fixture.contentRevision}
)`
  )
  .join(",\n")};

insert into public.seasons (
  season_id, revision, title, starts_at, ends_at, payload, active
) values (
  '${r2Fixture.seasonId}', 1, 'R2 Live Season',
  now() - interval '12 hours', now() + interval '36 hours',
  jsonb_build_object(
    'days', (
      select jsonb_agg(jsonb_build_object(
        'day', day,
        'title', 'R2 Day ' || day,
        'featuredContentIds', jsonb_build_array('${r2Fixture.contentId}')
      ) order by day)
      from generate_series(1, 7) day
    ),
    'artifacts', jsonb_build_array(jsonb_build_object(
      'artifactId', '${r2Fixture.artifactId}', 'title', 'R2 Live Founder'
    )),
    'boss', jsonb_build_object(
      'bossEventId', '${r2Fixture.bossEventId}',
      'contentId', '${r2Fixture.contentId}',
      'contentRevision', ${r2Fixture.contentRevision},
      'startsAt', now() - interval '12 hours',
      'endsAt', now() + interval '36 hours',
      'normalRoute', jsonb_build_object('copy', 'R2 normal route'),
      'lowPressureRoute', jsonb_build_object('copy', 'R2 lower-pressure route'),
      'advancedRouteSafetyApproved', false
    ),
    'socialProof', jsonb_build_object(
      'aggregateKey', '${r2Fixture.socialKey}',
      'threshold', ${r2Fixture.socialThreshold},
      'windowStartsAt', now() - interval '12 hours',
      'windowEndsAt', now() + interval '36 hours'
    )
  ), true
), (
  '${r2Fixture.closedSeasonId}', 1, 'R2 Closed Season',
  now() - interval '10 days', now() - interval '9 days',
  '{}'::jsonb, false
);

insert into public.boss_events (
  boss_event_id, season_id, content_id, content_revision, locale,
  starts_at, ends_at, payload
)
select '${r2Fixture.bossEventId}', season_id,
  '${r2Fixture.contentId}', ${r2Fixture.contentRevision}, 'ru',
  starts_at, ends_at,
  jsonb_build_object(
    'normalRoute', jsonb_build_object('copy', 'R2 normal route'),
    'lowPressureRoute', jsonb_build_object('copy', 'R2 lower-pressure route')
  )
from public.seasons where season_id = '${r2Fixture.seasonId}';

insert into public.boss_events (
  boss_event_id, season_id, content_id, content_revision, locale,
  starts_at, ends_at, payload
) values (
  '${r2Fixture.futureBossEventId}', '${r2Fixture.seasonId}',
  '${r2Fixture.contentId}', ${r2Fixture.contentRevision}, 'ru',
  now() + interval '1 hour', now() + interval '2 hours',
  jsonb_build_object('normalRoute', jsonb_build_object('title', 'Future'))
);
`;

export const seedBelowThresholdSql = `
insert into public.social_proof_aggregates (
  aggregate_key, season_id, season_revision, boss_event_id, value, threshold,
  window_starts_at, window_ends_at
)
select
  payload #>> '{socialProof,aggregateKey}', season_id, revision,
  payload #>> '{boss,bossEventId}', ${r2Fixture.socialThreshold - 2},
  (payload #>> '{socialProof,threshold}')::integer,
  (payload #>> '{socialProof,windowStartsAt}')::timestamptz,
  (payload #>> '{socialProof,windowEndsAt}')::timestamptz
from public.seasons where season_id = '${r2Fixture.seasonId}';
`;

export const securityVerificationSql = `
select json_build_object(
  'unsafeSecurityDefiners', (
    select count(*)::integer
    from pg_proc function
    join pg_namespace namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public' and function.prosecdef
      and not exists (
        select 1 from unnest(coalesce(function.proconfig, '{}'::text[])) setting
        where setting like 'search_path=%'
          and split_part(setting, '=', 2) in ('', '""')
      )
  ),
  'anonExecutableSecurityDefiners', (
    select count(*)::integer
    from pg_proc function
    join pg_namespace namespace on namespace.oid = function.pronamespace
    where namespace.nspname = 'public' and function.prosecdef
      and has_function_privilege('anon', function.oid, 'execute')
  ),
  'authenticatedDeleteExecute', has_function_privilege(
    'authenticated', 'public.delete_my_data()', 'execute'
  ),
  'authenticatedIngestExecute', has_function_privilege(
    'authenticated', 'public.ingest_events_v2(uuid,jsonb)', 'execute'
  ),
  'authenticatedDirectEventInsert', has_table_privilege(
    'authenticated', 'public.user_events', 'insert'
  ),
  'anonArtifactSelect', has_table_privilege(
    'anon', 'public.user_artifacts', 'select'
  )
)::text;
`;

export const seasonVerificationSql = `
select json_build_object(
  'firstSeasonRows', (select count(*)::integer from public.season_participation
    where season_id = '${r2Fixture.seasonId}' and user_id = :'first_user_id'::uuid),
  'firstDayRows', (select count(*)::integer from public.season_day_completions
    where season_id = '${r2Fixture.seasonId}' and user_id = :'first_user_id'::uuid),
  'bossParticipationRows', (select count(*)::integer from public.boss_participation
    where boss_event_id = '${r2Fixture.bossEventId}'),
  'artifactRows', (select count(*)::integer from public.user_artifacts
    where artifact_id = '${r2Fixture.artifactId}'),
  'aggregateValue', (select value::integer from public.social_proof_aggregates
    where aggregate_key = '${r2Fixture.socialKey}')
)::text;
`;

export const deletionVerificationSql = `
select json_build_object(
  'deletedAuthUsers', (select count(*)::integer from auth.users where id = :'deleted_user_id'::uuid),
  'deletedInstallations', (select count(*)::integer from public.user_installations where user_id = :'deleted_user_id'::uuid),
  'deletedLegacyEvents', (select count(*)::integer from public.quest_events_cloud where user_id = :'deleted_user_id'::uuid),
  'deletedVnextEvents', (select count(*)::integer from public.user_events where user_id = :'deleted_user_id'::uuid),
  'deletedProgress', (select count(*)::integer from public.user_progress where user_id = :'deleted_user_id'::uuid),
  'deletedSeasonParticipation', (select count(*)::integer from public.season_participation where user_id = :'deleted_user_id'::uuid),
  'deletedSeasonDays', (select count(*)::integer from public.season_day_completions where user_id = :'deleted_user_id'::uuid),
  'deletedBossParticipation', (select count(*)::integer from public.boss_participation where user_id = :'deleted_user_id'::uuid),
  'deletedArtifacts', (select count(*)::integer from public.user_artifacts where user_id = :'deleted_user_id'::uuid),
  'deletionReceipts', (select count(*)::integer from public.data_deletion_receipts where user_id = :'deleted_user_id'::uuid),
  'socialValueAfterDeletion', (select value::integer from public.social_proof_aggregates where aggregate_key = '${r2Fixture.socialKey}'),
  'survivingAuthUsers', (select count(*)::integer from auth.users where id = :'surviving_user_id'::uuid),
  'survivingInstallations', (select count(*)::integer from public.user_installations where user_id = :'surviving_user_id'::uuid),
  'survivingBossParticipation', (select count(*)::integer from public.boss_participation where user_id = :'surviving_user_id'::uuid),
  'survivingArtifacts', (select count(*)::integer from public.user_artifacts where user_id = :'surviving_user_id'::uuid)
)::text;
`;

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}
