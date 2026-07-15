import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { BOSS_QUESTS, MODIFIERS, QUESTS } from "../src/data.js";
import { buildSupabaseQuestSeed } from "../scripts/export_supabase_seed.mjs";

const migration = (name) => new URL(`../supabase/migrations/${name}`, import.meta.url);

const paths = {
  core: migration("202607120001_core_event_log.sql"),
  ingest: migration("202607120002_ingest_quest_events.sql"),
  seed: migration("202607120003_quest_catalog_seed.sql"),
  deletion: migration("202607120004_delete_user_data.sql"),
  mobileEvents: new URL("../mobile/lib/domain/models/game_event.dart", import.meta.url)
};

test("Supabase schema keeps events append-only and user-scoped", async () => {
  const sql = await readFile(paths.core, "utf8");
  for (const table of [
    "quests_pool_cloud",
    "user_installations",
    "quest_events_cloud",
    "user_stats_cloud",
    "daily_boss_quests",
    "boss_quest_participants"
  ]) {
    assert.match(sql, new RegExp(`create table public\\.${table}`));
    assert.match(sql, new RegExp(`alter table public\\.${table} enable row level security`));
  }
  assert.match(sql, /primary key \(user_id, id\)/);
  assert.match(sql, /quest_events_cloud_append_only/);
  assert.match(sql, /revoke insert, update, delete on public\.quest_events_cloud/);
  assert.match(sql, /using \(user_id = auth\.uid\(\)\)/);
});

test("ingestion RPC matches mobile events and MVP validation rules", async () => {
  const [sql, dart] = await Promise.all([
    readFile(paths.ingest, "utf8"),
    readFile(paths.mobileEvents, "utf8")
  ]);
  const mobileEventNames = [...dart.matchAll(/^  \w+\('([^']+)'\)[,;]/gm)].map((match) => match[1]);
  for (const eventName of mobileEventNames) {
    assert.match(sql, new RegExp(`'${eventName}'`), `RPC is missing ${eventName}`);
  }
  for (const modifier of MODIFIERS) {
    assert.match(sql, new RegExp(`'${modifier.id}'`), `RPC is missing modifier ${modifier.id}`);
  }
  assert.match(sql, /auth\.uid\(\)/);
  assert.match(sql, /jsonb_array_length\(p_events\) > 100/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /requires quest_started in the previous 24 hours/);
  assert.match(sql, /xpDelta does not match canonical reward/);
  assert.match(sql, /energy would become negative/);
  assert.match(sql, /'acceptedIds', v_accepted/);
  assert.match(sql, /'rejectedById', v_rejected/);
  assert.doesNotMatch(sql, /insert into public\.daily_boss_quests/);
});

test("generated Supabase seed exactly matches the canonical quest catalog", async () => {
  const actual = await readFile(paths.seed, "utf8");
  assert.equal(actual, buildSupabaseQuestSeed());
  for (const quest of [...QUESTS, ...BOSS_QUESTS]) {
    assert.ok(actual.includes(`('${quest.id}',`), `seed is missing ${quest.id}`);
  }
  assert.equal(QUESTS.length, 50);
  assert.equal(BOSS_QUESTS.length, 5);
});

test("cloud deletion is authenticated and compensates Boss counters", async () => {
  const sql = await readFile(paths.deletion, "utf8");
  assert.match(sql, /v_user_id uuid := auth\.uid\(\)/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /participants_count = greatest/);
  assert.match(sql, /set_config\('mayhem\.allow_event_delete', 'on', true\)/);
  assert.match(sql, /delete from public\.quest_events_cloud where user_id = v_user_id/);
  assert.match(sql, /grant execute on function public\.delete_my_cloud_data\(\) to authenticated/);
});
