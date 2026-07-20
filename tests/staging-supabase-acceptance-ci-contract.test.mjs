import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

import {
  r2ClientCheckNames,
  verifyLiveSupabaseReport
} from "../scripts/verify_live_supabase_report.mjs";
import { r2ProbeNames } from "../scripts/lib/r2_live_probes.mjs";

const workflow = read(".github/workflows/staging-supabase-acceptance.yml");
const migrationVersions = [
  "202607120001",
  "202607120002",
  "202607120003",
  "202607120004",
  "202607130005",
  "202607130006",
  "202607170007",
  "202607170008",
  "202607170009",
  "202607180010"
];

test("staging Supabase acceptance is manual, disposable, and main-only", () => {
  assert.match(workflow, /^\s{2}workflow_dispatch:/m);
  assert.doesNotMatch(workflow, /^\s{2}(?:push|pull_request):/m);
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /I_UNDERSTAND_THIS_IS_DISPOSABLE/);
  assert.match(workflow, /environment: staging-acceptance/);
  assert.match(workflow, /permissions:\s+contents: read/);
  assert.doesNotMatch(workflow, /production|service_role|access_token/i);
});

test("staging acceptance uses protected inputs and emits bounded evidence", () => {
  assert.match(workflow, /secrets\.SUPABASE_URL/);
  assert.match(workflow, /secrets\.SUPABASE_ANON_KEY/);
  assert.match(workflow, /secrets\.SUPABASE_DB_URL/);
  assert.match(workflow, /vars\.MAYHEM_R2_ENVIRONMENT_ID/);
  assert.match(workflow, /flutter pub get --enforce-lockfile/);
  assert.match(workflow, /node scripts\/run_live_supabase_acceptance\.mjs/);
  assert.match(workflow, /node scripts\/verify_live_supabase_report\.mjs/);
  assert.match(workflow, /actions\/upload-artifact@v4/);
  assert.match(workflow, /retention-days: 7/);
});

test("report verifier accepts the complete migration 010 evidence shape", () => {
  const report = passingReport();
  const result = verifyLiveSupabaseReport({
    report,
    expectedMigrationVersions: migrationVersions,
    environment: protectedEnvironment
  });
  assert.deepEqual(result, { migrations: 10, probes: 9, clientChecks: 8 });
});

test("report verifier rejects missing migration or leaked credentials", () => {
  assert.throws(
    () =>
      verifyLiveSupabaseReport({
        report: { ...passingReport(), migrationVersions: migrationVersions.slice(0, -1) },
        expectedMigrationVersions: migrationVersions,
        environment: protectedEnvironment
      }),
    /Expected values to be strictly deep-equal/
  );
  assert.throws(
    () =>
      verifyLiveSupabaseReport({
        report: { ...passingReport(), leak: protectedEnvironment.SUPABASE_ANON_KEY },
        expectedMigrationVersions: migrationVersions,
        environment: protectedEnvironment
      }),
    /protected runtime value/
  );
});

const protectedEnvironment = {
  SUPABASE_URL: "https://acceptance.supabase.co",
  SUPABASE_ANON_KEY: "test-publishable-value",
  SUPABASE_DB_URL:
    "postgresql://postgres:database-password@db.acceptance.test:5432/postgres"
};

function passingReport() {
  return {
    environment: {
      environmentId: "mayhem-staging-acceptance",
      supabaseHost: "acceptance.supabase.co",
      transport: "https",
      databaseConfigured: true,
      anonKeyConfigured: true
    },
    migrationVersions,
    startedAt: "2026-07-20T10:00:00.000Z",
    completedAt: "2026-07-20T10:01:00.000Z",
    durationMs: 60000,
    probes: r2ProbeNames.map((name) => ({
      name,
      status: "passed",
      durationMs: 1
    })),
    passed: [...r2ProbeNames],
    failed: [],
    blocked: [],
    notRun: [],
    result: "passed",
    clientChecks: [...r2ClientCheckNames]
  };
}

function read(relativePath) {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}
