import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { migrationPlan } from "./lib/live_supabase_acceptance.mjs";
import { r2ProbeNames } from "./lib/r2_live_probes.mjs";

export const r2ClientCheckNames = Object.freeze([
  "anonymous_bootstrap_secure_restore_and_refresh",
  "installation_bootstrap_and_safe_flags",
  "remote_content_validation_and_feed_parsing",
  "remote_content_and_feed_local_persistence",
  "exact_and_partial_ack_through_production_gateway",
  "season_bootstrap_persistence_and_artifact_reconciliation",
  "delete_everywhere_interruption_and_recovery",
  "backend_absence_fails_closed"
]);

export function verifyLiveSupabaseReport({
  report,
  expectedMigrationVersions,
  environment = process.env
}) {
  const serialized = JSON.stringify(report);
  assertNoProtectedValues(serialized, environment);

  assert.equal(report?.result, "passed");
  assert.deepEqual(report.migrationVersions, expectedMigrationVersions);
  assert.ok(report.migrationVersions.includes("202607180010"));
  assert.deepEqual(report.passed, r2ProbeNames);
  assert.deepEqual(report.failed, []);
  assert.deepEqual(report.blocked, []);
  assert.deepEqual(report.notRun, []);
  assert.deepEqual(
    report.probes.map(({ name, status }) => ({ name, status })),
    r2ProbeNames.map((name) => ({ name, status: "passed" }))
  );
  assert.deepEqual(report.clientChecks, r2ClientCheckNames);
  assert.match(report.environment.environmentId, /^[a-z0-9][a-z0-9._-]{2,63}$/i);
  assert.doesNotMatch(report.environment.environmentId, /prod(uction)?/i);
  assert.equal(report.environment.transport, "https");
  assert.equal(report.environment.databaseConfigured, true);
  assert.equal(report.environment.anonKeyConfigured, true);
  assert.ok(Number.isFinite(Date.parse(report.startedAt)));
  assert.ok(Number.isFinite(Date.parse(report.completedAt)));
  assert.ok(Number.isInteger(report.durationMs) && report.durationMs >= 0);

  return Object.freeze({
    migrations: report.migrationVersions.length,
    probes: report.passed.length,
    clientChecks: report.clientChecks.length
  });
}

function assertNoProtectedValues(serialized, environment) {
  const protectedValues = [
    environment.SUPABASE_URL,
    environment.SUPABASE_ANON_KEY,
    environment.SUPABASE_DB_URL,
    databasePassword(environment.SUPABASE_DB_URL)
  ].filter((value) => typeof value === "string" && value.length >= 4);
  for (const value of protectedValues) {
    if (serialized.includes(value)) {
      throw new Error("R2 report contains a protected runtime value");
    }
  }
  assert.doesNotMatch(serialized, /postgres(?:ql)?:\/\//i);
  assert.doesNotMatch(serialized, /sb_(?:publishable|secret)_[a-z0-9_-]+/i);
  assert.doesNotMatch(
    serialized,
    /eyJ[a-z0-9_-]{8,}\.[a-z0-9_-]{8,}\.[a-z0-9_-]{8,}/i
  );
}

function databasePassword(databaseUrl) {
  if (!databaseUrl) return null;
  try {
    return decodeURIComponent(new URL(databaseUrl).password);
  } catch {
    return null;
  }
}

async function main() {
  const reportPath = process.env.MAYHEM_R2_REPORT_PATH?.trim();
  if (!reportPath) throw new Error("MAYHEM_R2_REPORT_PATH is required");
  const repositoryRoot = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    ".."
  );
  const migrations = await migrationPlan(repositoryRoot);
  const report = JSON.parse(await readFile(reportPath, "utf8"));
  const result = verifyLiveSupabaseReport({
    report,
    expectedMigrationVersions: migrations.map(({ version }) => version)
  });
  process.stdout.write(
    `R2 report verified: ${result.migrations} migrations, ` +
      `${result.probes} probes, ${result.clientChecks} client checks\n`
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    process.stderr.write(`R2 report verification failed: ${error.message}\n`);
    process.exitCode = 1;
  });
}
