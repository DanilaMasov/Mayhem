import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  PsqlRunner,
  SupabaseAcceptanceClient,
  canonicalEvent,
  loadLiveSupabaseConfig,
  migrationPlan,
  safeEnvironmentSummary
} from "./lib/live_supabase_acceptance.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

export async function runLiveSupabaseAcceptance({
  environment = process.env,
  psql,
  client,
  uuid = randomUUID
} = {}) {
  const config = loadLiveSupabaseConfig(environment);
  const database =
    psql ?? new PsqlRunner({ databaseUrl: config.databaseUrl });
  const supabase =
    client ??
    new SupabaseAcceptanceClient({
      supabaseUrl: config.supabaseUrl,
      anonKey: config.anonKey
    });
  const migrations = await migrationPlan(repositoryRoot);
  const checks = [];

  await database.verifyAvailable();
  await database.assertMayhemSchemaIsEmpty();
  for (const migration of migrations) {
    await database.applyMigration(migration.path);
  }
  await database.query("notify pgrst, 'reload schema'");
  await new Promise((resolve) => setTimeout(resolve, 1000));
  checks.push("migrations_from_zero");

  const first = await supabase.signUpAnonymous();
  const second = await supabase.signUpAnonymous();
  assert.notEqual(first.userId, second.userId);
  const refreshedFirst = await supabase.refresh(first);
  assert.equal(refreshedFirst.userId, first.userId);
  checks.push("anonymous_signup_and_refresh");

  const firstInstallation = uuid();
  const secondInstallation = uuid();
  await registerInstallation(
    supabase,
    refreshedFirst,
    firstInstallation,
    "r2-local-user-first"
  );
  await registerInstallation(
    supabase,
    second,
    secondInstallation,
    "r2-local-user-second"
  );

  const ownershipCollision = await supabase.request(
    "/rest/v1/rpc/register_installation",
    {
      body: installationBody(firstInstallation, "r2-local-user-second"),
      accessToken: second.accessToken,
      allowFailure: true
    }
  );
  assert.equal(ownershipCollision.ok, false);

  const firstRows = await supabase.rest(
    "user_installations?select=installation_id,user_id",
    { method: "GET", accessToken: refreshedFirst.accessToken }
  );
  const secondRows = await supabase.rest(
    "user_installations?select=installation_id,user_id",
    { method: "GET", accessToken: second.accessToken }
  );
  assert.deepEqual(
    firstRows.value.map((row) => row.installation_id),
    [firstInstallation]
  );
  assert.deepEqual(
    secondRows.value.map((row) => row.installation_id),
    [secondInstallation]
  );
  checks.push("installation_registration_and_ownership_isolation");

  const directWrite = await supabase.request("/rest/v1/user_events", {
    body: {},
    accessToken: refreshedFirst.accessToken,
    allowFailure: true
  });
  assert.equal(directWrite.ok, false);
  assert.ok([401, 403].includes(directWrite.status));
  checks.push("direct_table_write_denied");

  const firstEvent = canonicalEvent({
    eventId: uuid(),
    installationId: firstInstallation,
    clientSequence: 1,
    eventType: "onboarding_started"
  });
  const accepted = await ingest(
    supabase,
    refreshedFirst,
    firstInstallation,
    [firstEvent]
  );
  assert.deepEqual(accepted.acceptedIds, [firstEvent.eventId]);
  assert.equal(accepted.results[0].disposition, "accepted");

  const duplicate = await ingest(
    supabase,
    refreshedFirst,
    firstInstallation,
    [firstEvent]
  );
  assert.deepEqual(duplicate.acceptedIds, [firstEvent.eventId]);
  assert.equal(duplicate.results[0].disposition, "duplicate_event");

  const secondEvent = canonicalEvent({
    eventId: uuid(),
    installationId: firstInstallation,
    clientSequence: 2,
    eventType: "calibration_answered",
    payload: { trait: "presence", answer: 2 }
  });
  const rejectedEvent = canonicalEvent({
    eventId: uuid(),
    installationId: firstInstallation,
    clientSequence: 3,
    eventType: "reflection_submitted",
    payload: { privateNote: "must never reach the server" }
  });
  const partial = await ingest(
    supabase,
    refreshedFirst,
    firstInstallation,
    [secondEvent, rejectedEvent]
  );
  assert.deepEqual(partial.acceptedIds, [secondEvent.eventId]);
  assert.equal(partial.results[0].accepted, true);
  assert.equal(partial.results[1].accepted, false);
  assert.equal(partial.results[1].disposition, "permanent_schema");
  checks.push("exact_duplicate_and_partial_ack");

  const revokedAttempt = await supabase.request(
    "/rest/v1/rpc/get_progress_projection",
    {
      body: {},
      accessToken: "revoked-r2-token",
      allowFailure: true
    }
  );
  assert.equal(revokedAttempt.ok, false);
  assert.equal(revokedAttempt.status, 401);
  const recoveredSession = await supabase.refresh(refreshedFirst);
  const recoveredProjection = await supabase.rpc(
    "get_progress_projection",
    {},
    recoveredSession.accessToken
  );
  assert.ok(recoveredProjection.value);
  checks.push("revoked_token_refresh_and_retry");

  const deletion = await supabase.rpc(
    "delete_my_data",
    {},
    recoveredSession.accessToken
  );
  assert.equal(deletion.value.remoteUserId, first.userId);
  assert.equal(deletion.value.authIdentityDeleted, true);
  const deletedSession = await supabase.request(
    "/rest/v1/rpc/get_progress_projection",
    {
      body: {},
      accessToken: recoveredSession.accessToken,
      allowFailure: true
    }
  );
  assert.equal(deletedSession.ok, false);
  const survivingUser = await supabase.rpc(
    "get_progress_projection",
    {},
    second.accessToken
  );
  assert.ok(survivingUser.value);

  const deletionState = JSON.parse(
    await database.query(deletionVerificationSql, {
      deleted_user_id: first.userId,
      surviving_user_id: second.userId
    })
  );
  assert.deepEqual(deletionState, {
    deletedAuthUsers: 0,
    deletedInstallations: 0,
    deletedLegacyEvents: 0,
    deletedVnextEvents: 0,
    deletedArtifacts: 0,
    deletionReceipts: 1,
    survivingAuthUsers: 1,
    survivingInstallations: 1
  });
  checks.push("delete_everywhere_and_cross_user_survival");

  return Object.freeze({
    environment: safeEnvironmentSummary(config),
    migrationVersions: migrations.map((migration) => migration.version),
    checks,
    result: "passed"
  });
}

function installationBody(installationId, localUserId) {
  return {
    p_installation_id: installationId,
    p_local_user_id: localUserId,
    p_platform: "test",
    p_app_version: "r2-acceptance",
    p_capabilities: {}
  };
}

async function registerInstallation(client, session, installationId, localUserId) {
  const response = await client.rpc(
    "register_installation",
    installationBody(installationId, localUserId),
    session.accessToken
  );
  assert.equal(response.value.installationId, installationId);
  assert.equal(response.value.remoteUserId, session.userId);
}

async function ingest(client, session, installationId, events) {
  const response = await client.rpc(
    "ingest_events_v2",
    { p_installation_id: installationId, p_events: events },
    session.accessToken
  );
  return response.value;
}

const deletionVerificationSql = `
select json_build_object(
  'deletedAuthUsers', (select count(*)::integer from auth.users where id = :'deleted_user_id'::uuid),
  'deletedInstallations', (select count(*)::integer from public.user_installations where user_id = :'deleted_user_id'::uuid),
  'deletedLegacyEvents', (select count(*)::integer from public.quest_events_cloud where user_id = :'deleted_user_id'::uuid),
  'deletedVnextEvents', (select count(*)::integer from public.user_events where user_id = :'deleted_user_id'::uuid),
  'deletedArtifacts', (select count(*)::integer from public.user_artifacts where user_id = :'deleted_user_id'::uuid),
  'deletionReceipts', (select count(*)::integer from public.data_deletion_receipts where user_id = :'deleted_user_id'::uuid),
  'survivingAuthUsers', (select count(*)::integer from auth.users where id = :'surviving_user_id'::uuid),
  'survivingInstallations', (select count(*)::integer from public.user_installations where user_id = :'surviving_user_id'::uuid)
)::text;
`;

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const report = await runLiveSupabaseAcceptance();
    const serialized = `${JSON.stringify(report, null, 2)}\n`;
    const reportPath = process.env.MAYHEM_R2_REPORT_PATH?.trim();
    if (reportPath) await writeFile(reportPath, serialized, { flag: "wx" });
    process.stdout.write(serialized);
  } catch (error) {
    process.stderr.write(`R2 acceptance failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
