import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import test from "node:test";

import { safeFailureDiagnostic } from "../scripts/run_live_supabase_acceptance.mjs";
import {
  FlutterLiveClientRunner,
  PsqlRunner,
  SupabaseAcceptanceClient,
  canonicalEvent,
  disposableConfirmation,
  disposableResetConfirmation,
  loadLiveSupabaseConfig,
  migrationPlan,
  safeEnvironmentSummary
} from "../scripts/lib/live_supabase_acceptance.mjs";
import {
  LiveProbeRecorder,
  r2FixtureSql,
  r2ProbeNames,
  securityVerificationSql
} from "../scripts/lib/r2_live_probes.mjs";

const validEnvironment = {
  MAYHEM_R2_ENVIRONMENT_ID: "mayhem-r2-disposable",
  MAYHEM_R2_CONFIRM_DISPOSABLE: disposableConfirmation,
  SUPABASE_URL: "https://abcdefghijklmnopqrst.supabase.co",
  SUPABASE_ANON_KEY: "anon-secret-value",
  SUPABASE_DB_URL:
    "postgresql://postgres.abcdefghijklmnopqrst:database-secret@aws-0-test.pooler.supabase.com:5432/postgres"
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
  assert.throws(
    () =>
      loadLiveSupabaseConfig({
        ...validEnvironment,
        MAYHEM_R2_RESET_EXISTING: "reset"
      }),
    /reset confirmation is invalid/
  );
  assert.equal(
    loadLiveSupabaseConfig({
      ...validEnvironment,
      MAYHEM_R2_RESET_EXISTING: disposableResetConfirmation
    }).resetExisting,
    true
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
  assert.throws(
    () =>
      loadLiveSupabaseConfig({
        ...validEnvironment,
        SUPABASE_DB_URL:
          "postgresql://postgres.differentprojectrefxx:database-secret@aws-0-test.pooler.supabase.com:5432/postgres"
      }),
    /targets do not match/
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

test("R2 CLI diagnostic preserves bounded cause without credentials", () => {
  const failure = new Error("R2 probe failed: migrations_from_zero (Error)");
  failure.cause = new Error(
    `database rejected ${validEnvironment.SUPABASE_DB_URL} ` +
      `${validEnvironment.SUPABASE_ANON_KEY} database-secret\nserver detail`
  );
  const diagnostic = safeFailureDiagnostic(failure, validEnvironment);

  assert.match(diagnostic, /migrations_from_zero/);
  assert.match(diagnostic, /<redacted>/);
  assert.doesNotMatch(
    diagnostic,
    /database-secret|anon-secret-value|postgresql:\/\//
  );
  assert.ok(diagnostic.length <= 240);
  assert.doesNotMatch(diagnostic, /[\r\n]/);
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
      "202607130006",
      "202607170007",
      "202607170008",
      "202607170009",
      "202607180010",
      "202607200011",
      "202607220012"
    ]
  );
});

test("psql receives decomposed credentials only through libpq environment", async () => {
  const calls = [];
  const spawnProcess = (executable, argumentsList, options) => {
    const call = { executable, argumentsList, options, input: "" };
    calls.push(call);
    const child = new EventEmitter();
    child.stdin = new PassThrough();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    child.stdin.on("data", (chunk) => {
      call.input += chunk;
    });
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
  assert.equal(calls[0].options.env.PGHOST, "aws-0-test.pooler.supabase.com");
  assert.equal(calls[0].options.env.PGPORT, "5432");
  assert.equal(calls[0].options.env.PGDATABASE, "postgres");
  assert.equal(
    calls[0].options.env.PGUSER,
    "postgres.abcdefghijklmnopqrst"
  );
  assert.equal(calls[0].options.env.PGPASSWORD, "database-secret");
  assert.equal(calls[0].options.env.SUPABASE_ANON_KEY, undefined);
  assert.match(calls[0].argumentsList.join(" "), /--file=-/);
  assert.equal(calls[0].input, "select 0\n");
});

test("disposable reset is transactional and scoped to the confirmed target", async () => {
  const calls = [];
  const spawnProcess = (_executable, _argumentsList, options) => {
    const call = { options, input: "" };
    calls.push(call);
    const child = new EventEmitter();
    child.stdin = new PassThrough();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    child.stdin.on("data", (chunk) => {
      call.input += chunk;
    });
    queueMicrotask(() => {
      child.stdout.end();
      child.stderr.end();
      child.emit("close", 0);
    });
    return child;
  };
  const runner = new PsqlRunner({
    databaseUrl: validEnvironment.SUPABASE_DB_URL,
    spawnProcess
  });

  await assert.rejects(
    () => runner.resetDisposableTarget(),
    /reset confirmation is missing/
  );
  await runner.resetDisposableTarget(disposableResetConfirmation);

  assert.equal(calls.length, 1);
  assert.match(calls[0].input, /begin;[\s\S]+?drop schema if exists public cascade/);
  assert.match(calls[0].input, /delete from auth\.users;[\s\S]+?commit;/);
  assert.equal(calls[0].options.env.PGPASSWORD, "database-secret");
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

test("R2 probe recorder preserves timings and explicit not-run state", async () => {
  const times = [0, 10, 25, 40, 55, 70];
  const recorder = new LiveProbeRecorder({
    names: ["first", "second", "third"],
    clock: () => times.shift()
  });
  await recorder.run("first", async () => {});
  await assert.rejects(
    () => recorder.run("second", async () => {
      throw new Error("sensitive response body");
    }),
    (error) => {
      assert.match(error.message, /second \(Error\)/);
      assert.doesNotMatch(error.message, /sensitive response body/);
      return true;
    }
  );
  const report = recorder.report({
    environment: { environmentId: "r2-test" },
    migrationVersions: ["1"],
    result: "failed"
  });
  assert.deepEqual(report.passed, ["first"]);
  assert.deepEqual(report.failed, ["second"]);
  assert.deepEqual(report.notRun, ["third"]);
  assert.deepEqual(
    report.probes.map((probe) => probe.durationMs),
    [15, 15]
  );
});

test("R2 fixtures cover active and closed Season, Boss, social, and grants", () => {
  assert.match(r2FixtureSql, /r2-live-season/);
  assert.match(r2FixtureSql, /r2-closed-season/);
  assert.match(r2FixtureSql, /r2-live-boss/);
  assert.match(r2FixtureSql, /r2-future-boss/);
  assert.match(r2FixtureSql, /r2-live-feed-20/);
  assert.match(r2FixtureSql, /'threshold', 20/);
  assert.match(securityVerificationSql, /unsafeSecurityDefiners/);
  assert.match(securityVerificationSql, /anonExecutableSecurityDefiners/);
  assert.equal(r2ProbeNames.length, 9);
});

test("Flutter live client receives only its minimum secret environment", async () => {
  const config = loadLiveSupabaseConfig(validEnvironment);
  const calls = [];
  const spawnProcess = (executable, argumentsList, options) => {
    calls.push({ executable, argumentsList, options });
    const child = new EventEmitter();
    child.stdout = new PassThrough();
    child.stderr = new PassThrough();
    queueMicrotask(() => {
      const report = Buffer.from(JSON.stringify({
        environmentId: config.environmentId,
        checks: ["client"],
        result: "passed"
      })).toString("base64url");
      child.stdout.end(`test output\nMAYHEM_R2_CLIENT_REPORT:${report}\n`);
      child.stderr.end();
      child.emit("close", 0);
    });
    return child;
  };
  const runner = new FlutterLiveClientRunner({
    config,
    spawnProcess,
    baseEnvironment: {
      PATH: "/bin",
      SUPABASE_DB_URL: validEnvironment.SUPABASE_DB_URL,
      DATABASE_URL: "postgresql://must-not-leak"
    }
  });

  const report = await runner.run("/workspace/mobile");

  assert.equal(report.result, "passed");
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0].argumentsList, [
    "test",
    "--no-pub",
    "--no-test-assets",
    "-j",
    "1",
    "test/live/r2_live_supabase_test.dart"
  ]);
  assert.equal(calls[0].options.env.SUPABASE_DB_URL, undefined);
  assert.equal(calls[0].options.env.DATABASE_URL, undefined);
  assert.doesNotMatch(
    JSON.stringify(calls[0].argumentsList),
    /anon-secret-value|database-secret/
  );
});
