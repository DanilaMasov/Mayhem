import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";

import {
  PsqlRunner,
  SupabaseAcceptanceClient,
  canonicalEvent,
  disposableConfirmation,
  loadLiveSupabaseConfig,
  migrationPlan,
  safeEnvironmentSummary
} from "../scripts/lib/live_supabase_acceptance.mjs";

const validEnvironment = {
  MAYHEM_R2_ENVIRONMENT_ID: "mayhem-r2-disposable",
  MAYHEM_R2_CONFIRM_DISPOSABLE: disposableConfirmation,
  SUPABASE_URL: "https://r2-test.supabase.co",
  SUPABASE_ANON_KEY: "anon-secret-value",
  SUPABASE_DB_URL: "postgresql://postgres:database-secret@db.test:5432/postgres"
};

test("R2 preflight fails closed without every disposable credential", () => {
  assert.throws(
    () => loadLiveSupabaseConfig({}),
    /R2 preflight missing/
  );
  assert.throws(
    () =>
      loadLiveSupabaseConfig({
        ...validEnvironment,
        MAYHEM_R2_CONFIRM_DISPOSABLE: "yes"
      }),
    /confirmation is missing/
  );
});

test("R2 preflight rejects production and insecure remote targets", () => {
  assert.throws(
    () =>
      loadLiveSupabaseConfig({
        ...validEnvironment,
        MAYHEM_R2_ENVIRONMENT_ID: "mayhem-production"
      }),
    /containing production/
  );
  assert.throws(
    () =>
      loadLiveSupabaseConfig({
        ...validEnvironment,
        SUPABASE_URL: "http://remote.test"
      }),
    /must use HTTPS/
  );
});

test("R2 summary and errors never expose credentials", async () => {
  const config = loadLiveSupabaseConfig(validEnvironment);
  const summary = JSON.stringify(safeEnvironmentSummary(config));
  assert.doesNotMatch(summary, /anon-secret-value|database-secret/);

  const client = new SupabaseAcceptanceClient({
    supabaseUrl: config.supabaseUrl,
    anonKey: config.anonKey,
    fetchRequest: async () =>
      new Response('{"message":"anon-secret-value full response"}', {
        status: 500
      })
  });
  await assert.rejects(
    () => client.rpc("get_progress_projection", {}, "access-secret"),
    (error) => {
      assert.doesNotMatch(error.message, /anon-secret-value|access-secret|full response/);
      return true;
    }
  );
});

test("R2 migration plan is deterministic and complete", async () => {
  const migrations = await migrationPlan(new URL("..", import.meta.url).pathname);
  assert.deepEqual(
    migrations.map((migration) => migration.version),
    [
      "202607120001",
      "202607120002",
      "202607120003",
      "202607120004",
      "202607130005",
      "202607130006"
    ]
  );
});

test("psql receives the database URL only through its environment", async () => {
  const calls = [];
  const spawnProcess = (executable, argumentsList, options) => {
    calls.push({ executable, argumentsList, options });
    const child = new EventEmitter();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    queueMicrotask(() => {
      child.stdout.end("0\n");
      child.stderr.end();
      child.emit("close", 0);
    });
    return child;
  };
  const runner = new PsqlRunner({
    databaseUrl: validEnvironment.SUPABASE_DB_URL,
    spawnProcess
  });

  await runner.query("select 0");

  assert.equal(calls.length, 1);
  assert.doesNotMatch(
    JSON.stringify(calls[0].argumentsList),
    /database-secret/
  );
  assert.equal(
    calls[0].options.env.PGDATABASE,
    validEnvironment.SUPABASE_DB_URL
  );
  assert.equal(calls[0].options.env.SUPABASE_ANON_KEY, undefined);
});

test("canonical R2 events match the v2 transport envelope", () => {
  const event = canonicalEvent({
    eventId: "11111111-1111-4111-8111-111111111111",
    installationId: "22222222-2222-4222-8222-222222222222",
    clientSequence: 1,
    eventType: "onboarding_started"
  });
  assert.equal(event.schemaVersion, 2);
  assert.equal(event.timezoneId, "Etc/UTC");
  assert.equal(event.timezoneOffsetMinutes, 0);
  assert.deepEqual(event.payload, {});
});
