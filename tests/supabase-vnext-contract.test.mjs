import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const migration = (name) => new URL(`../supabase/migrations/${name}`, import.meta.url);
const schemaPath = migration("202607130005_vnext_backend.sql");
const rpcPath = migration("202607130006_vnext_rpc.sql");
const eventPath = new URL("../mobile/lib/core/sync/event_envelope_v2.dart", import.meta.url);
const goldenPath = new URL("../contracts/v1/policy_golden.json", import.meta.url);

const targetTables = [
  "content_item_revisions",
  "content_manifests",
  "content_manifest_items",
  "feed_batches",
  "feed_assignments",
  "challenge_attempts",
  "user_events",
  "user_progress",
  "user_difficulty_profiles",
  "user_momentum",
  "seasons",
  "season_participation",
  "season_day_completions",
  "boss_events",
  "boss_participation",
  "user_artifacts",
  "social_proof_aggregates",
  "feature_flags",
  "data_deletion_receipts"
];

test("vNext schema is additive, RLS-scoped, and server-write-only", async () => {
  const sql = await readFile(schemaPath, "utf8");
  assert.match(sql, /alter table public\.user_installations/);
  for (const table of targetTables) {
    assert.match(sql, new RegExp(`create table public\\.${table}`), table);
    assert.match(
      sql,
      new RegExp(`alter table public\\.${table} enable row level security`),
      `${table} must enable RLS`
    );
  }
  for (const table of [
    "feed_batches",
    "feed_assignments",
    "challenge_attempts",
    "user_events",
    "user_progress",
    "user_difficulty_profiles",
    "user_momentum"
  ]) {
    assert.match(sql, new RegExp(`revoke all on public\\.${table} from anon, authenticated`));
  }
  assert.match(sql, /using \(user_id = auth\.uid\(\)\)/);
  assert.match(sql, /user_events_append_only/);
  assert.match(sql, /content_item_revisions_immutable/);
  assert.match(sql, /content_manifests_one_active_locale_idx/);
  assert.match(sql, /own_user_artifacts_read[\s\S]+?user_id = auth\.uid\(\)/);
  assert.match(sql, /threshold integer not null default 20 check \(threshold >= 20\)/);
  assert.match(sql, /revoke all on public\.user_artifacts from anon, authenticated/);
  assert.match(sql, /grant select on public\.user_artifacts to authenticated/);
  assert.doesNotMatch(sql, /grant select on public\.seasons to authenticated/);
  assert.doesNotMatch(sql, /grant select on public\.social_proof_aggregates to authenticated/);
  assert.doesNotMatch(sql, /drop table|truncate table/i);
});

test("vNext RPC accepts the exact canonical mobile event vocabulary", async () => {
  const [sql, dart] = await Promise.all([
    readFile(rpcPath, "utf8"),
    readFile(eventPath, "utf8")
  ]);
  const mobileEvents = [...dart.matchAll(/^  \w+\('([^']+)'\)[,;]/gm)].map(
    (match) => match[1]
  );
  assert.equal(mobileEvents.length, 26);
  for (const eventName of mobileEvents) {
    assert.match(sql, new RegExp(`'${eventName}'`), eventName);
  }
  for (const disposition of [
    "duplicate_event",
    "stale_content_but_valid_assignment",
    "invalid_transition",
    "unknown_assignment",
    "permanent_schema"
  ]) {
    assert.match(sql, new RegExp(`'${disposition}'`));
  }
  assert.match(sql, /jsonb_array_length\(p_events\) > 100/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /octet_length\(v_payload::text\) > 65536/);
  assert.match(sql, /mayhem_jsonb_has_private_note_key/);
  assert.match(sql, /lower\(replace\(item\.key, '_', ''\)\)/);
});

test("server algorithms expose every frozen local policy revision", async () => {
  const [sql, source] = await Promise.all([
    readFile(rpcPath, "utf8"),
    readFile(goldenPath, "utf8")
  ]);
  const golden = JSON.parse(source);
  for (const revision of Object.values(golden.revisions)) {
    assert.match(sql, new RegExp(`'${revision}'`));
  }
  for (const [label, totalXp, minimumTraitXp] of golden.rankThresholds) {
    const [family, roman] = label.split(" ");
    const tier = roman === "I" ? 1 : roman === "II" ? 2 : roman === "III" ? 3 : 1;
    assert.match(
      sql,
      new RegExp(`\\('${family.toLowerCase()}', ${tier}, ${totalXp}, ${minimumTraitXp}\\)`)
    );
  }
  assert.match(sql, /then 100 else 60 end/);
  assert.match(sql, /then 75/);
  assert.match(sql, /else 50/);
  assert.match(sql, /interval '20 hours'/);
});

test("bootstrap, content, Feed, and deletion contracts fail closed", async () => {
  const sql = await readFile(rpcPath, "utf8");
  for (const rpc of [
    "register_installation",
    "get_bootstrap_payload",
    "get_content_manifest",
    "get_content_revisions",
    "get_feed_batch",
    "get_progress_projection",
    "get_active_season",
    "ingest_events_v2",
    "delete_my_data"
  ]) {
    assert.match(sql, new RegExp(`function public\\.${rpc}`), rpc);
  }
  for (const field of [
    "identity",
    "flags",
    "projection",
    "activeSeason",
    "feed",
    "contentManifest"
  ]) {
    assert.match(sql, new RegExp(`'${field}'`));
  }
  assert.match(sql, /p_limit < 1 or p_limit > 20/);
  assert.match(sql, /v_position <> p_limit/);
  assert.match(sql, /from public\.content_manifests manifest/);
  assert.match(sql, /mayhem_apply_season_event_v1/);
  assert.match(sql, /'artifact_unlocked'[\s\S]+?'invalid_transition'/);
  assert.match(sql, /'ownedArtifacts'[\s\S]+?from public\.user_artifacts/);
  assert.match(sql, /on conflict \(season_id, user_id, day\) do nothing/);
  assert.match(sql, /advancedRouteSafetyApproved/);
  assert.match(sql, /required_capability_revision/);
  assert.match(sql, /delete from auth\.users where id = v_user_id/);
  assert.match(sql, /select receipt into v_receipt from public\.data_deletion_receipts/);
  assert.match(sql, /insert into public\.data_deletion_receipts/);
  assert.match(sql, /'authIdentityDeleted', true/);
  assert.match(sql, /set_config\('mayhem\.allow_event_delete', 'on', true\)/);
  assert.match(sql, /'feed_item_impressed', 'feed_item_opened', 'feed_item_skipped',[\s\S]+?'feed_item_saved'[\s\S]+?v_assignment_id is null or v_attempt_id is not null/);
  for (const reason of ["notNow", "tooIntense", "wrongContext", "notRelevant"]) {
    assert.match(sql, new RegExp(`'${reason}'`));
  }
  assert.match(sql, /grant execute on function public\.delete_my_data\(\) to authenticated/);
  assert.match(sql, /revoke all on function public\.mayhem_apply_momentum_dev_v1\(uuid, date, timestamptz, text\) from public/);
  assert.match(sql, /revoke all on function public\.mayhem_progress_payload\(uuid\) from public/);
  assert.doesNotMatch(sql, /grant execute on function public\.mayhem_(?:apply_momentum_dev_v1|progress_payload)/);
  assert.doesNotMatch(sql, /grant execute[^;]+ to anon/);
});

test("Founder rewards and social proof stay server-authoritative", async () => {
  const sql = await readFile(rpcPath, "utf8");
  const helperStart = sql.indexOf(
    "create or replace function public.mayhem_apply_season_event_v1"
  );
  const helperEnd = sql.indexOf(
    "create or replace function public.ingest_events_v2"
  );
  assert.ok(helperStart >= 0 && helperEnd > helperStart);
  const helper = sql.slice(helperStart, helperEnd);
  const artifactValidation = helper.indexOf(
    "jsonb_typeof(v_season.payload -> 'artifacts')"
  );
  const socialValidation = helper.indexOf("v_social_config :=");
  const participationWrite = helper.indexOf(
    "insert into public.boss_participation"
  );
  assert.ok(artifactValidation >= 0);
  assert.ok(socialValidation > artifactValidation);
  assert.ok(participationWrite > socialValidation);
  assert.match(helper, /insert into public\.user_artifacts[\s\S]+?on conflict \(artifact_id, user_id\) do nothing/);
  assert.match(helper, /pg_advisory_xact_lock\(hashtextextended\('social:' \|\| v_social_key, 0\)\)/);
  assert.match(helper, /get diagnostics v_participation_inserted = row_count/);
  assert.match(helper, /on conflict \(aggregate_key\) do update set[\s\S]+?value = public\.social_proof_aggregates\.value \+ excluded\.value/);

  const activeSeasonStart = sql.indexOf(
    "create or replace function public.get_active_season"
  );
  const activeSeasonEnd = sql.indexOf(
    "create or replace function public.get_bootstrap_payload"
  );
  const activeSeason = sql.slice(activeSeasonStart, activeSeasonEnd);
  assert.match(activeSeason, /v_season\.payload - 'socialProof'/);
  assert.match(activeSeason, /a\.value >= a\.threshold/);
  assert.match(activeSeason, /a\.threshold >= 20/);
  assert.match(activeSeason, /a\.window_starts_at <= now\(\)/);
  assert.match(activeSeason, /jsonb_set\(v_payload, '\{socialProof\}'/);
});

test("Season projection runs only after generic event validation", async () => {
  const sql = await readFile(rpcPath, "utf8");
  const ingestStart = sql.indexOf(
    "create or replace function public.ingest_events_v2"
  );
  const ingestEnd = sql.indexOf(
    "create or replace function public.delete_my_data"
  );
  assert.ok(ingestStart >= 0 && ingestEnd > ingestStart);
  const ingest = sql.slice(ingestStart, ingestEnd);
  const assignmentValidation = ingest.indexOf(
    "if v_assignment_id is not null then"
  );
  const seasonProjection = ingest.indexOf(
    "v_disposition := public.mayhem_apply_season_event_v1"
  );
  assert.ok(assignmentValidation >= 0);
  assert.ok(seasonProjection > assignmentValidation);
  assert.match(
    ingest,
    /if v_assignment_id is not null or v_attempt_id is not null then[\s\S]+?'invalid_transition'[\s\S]+?mayhem_apply_season_event_v1/
  );
  assert.match(
    sql,
    /season_participation[\s\S]+?joined_at <= p_occurred_at/
  );
});
