import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  FlutterLiveClientRunner,
  PsqlRunner,
  SupabaseAcceptanceClient,
  canonicalEvent,
  loadLiveSupabaseConfig,
  migrationPlan,
  safeEnvironmentSummary
} from "./lib/live_supabase_acceptance.mjs";
import {
  LiveProbeRecorder,
  deletionVerificationSql,
  r2Fixture,
  r2FixtureSql,
  seasonVerificationSql,
  securityVerificationSql,
  seedBelowThresholdSql
} from "./lib/r2_live_probes.mjs";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  ".."
);

export async function runLiveSupabaseAcceptance({
  environment = process.env,
  psql,
  client,
  dartClient,
  uuid = randomUUID,
  clock = Date.now
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
  const clientAcceptance =
    dartClient ??
    new FlutterLiveClientRunner({ config, baseEnvironment: environment });
  const migrations = await migrationPlan(repositoryRoot);
  const recorder = new LiveProbeRecorder({ clock });
  const environmentSummary = safeEnvironmentSummary(config);
  const migrationVersions = migrations.map((migration) => migration.version);
  let clientChecks = [];

  let first;
  let second;
  let firstSession;
  let firstInstallation;
  let secondInstallation;

  try {
    await recorder.run("migrations_from_zero", async () => {
      await database.verifyAvailable();
      await database.assertMayhemSchemaIsEmpty();
      for (const migration of migrations) {
        await database.applyMigration(migration.path);
      }
      await database.query("notify pgrst, 'reload schema'");
      await new Promise((resolve) => setTimeout(resolve, 1000));
      await database.query(r2FixtureSql);
    });

    await recorder.run("authentication_and_session_refresh", async () => {
      first = await supabase.signUpAnonymous();
      second = await supabase.signUpAnonymous();
      assert.notEqual(first.userId, second.userId);
      firstSession = await supabase.refresh(first);
      assert.equal(firstSession.userId, first.userId);
    });

    await recorder.run("installation_ownership_and_rls", async () => {
      firstInstallation = uuid();
      secondInstallation = uuid();
      await registerInstallation(
        supabase,
        firstSession,
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
        { method: "GET", accessToken: firstSession.accessToken }
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
    });

    await recorder.run("direct_write_and_grant_security", async () => {
      const directEventWrite = await supabase.request("/rest/v1/user_events", {
        body: {},
        accessToken: firstSession.accessToken,
        allowFailure: true
      });
      assert.equal(directEventWrite.ok, false);
      assert.ok([401, 403].includes(directEventWrite.status));

      const directArtifactWrite = await supabase.request(
        "/rest/v1/user_artifacts",
        {
          body: {},
          accessToken: firstSession.accessToken,
          allowFailure: true
        }
      );
      assert.equal(directArtifactWrite.ok, false);
      assert.ok([401, 403].includes(directArtifactWrite.status));

      const security = JSON.parse(await database.query(securityVerificationSql));
      assert.deepEqual(security, {
        unsafeSecurityDefiners: 0,
        anonExecutableSecurityDefiners: 0,
        authenticatedDeleteExecute: true,
        authenticatedIngestExecute: true,
        authenticatedDirectEventInsert: false,
        anonArtifactSelect: false
      });
    });

    await recorder.run(
      "exact_duplicate_partial_ack_and_auth_recovery",
      async () => {
        const firstEvent = canonicalEvent({
          eventId: uuid(),
          installationId: firstInstallation,
          clientSequence: 1,
          eventType: "onboarding_started"
        });
        const accepted = await ingest(
          supabase,
          firstSession,
          firstInstallation,
          [firstEvent]
        );
        assert.deepEqual(accepted.acceptedIds, [firstEvent.eventId]);
        assert.equal(accepted.results[0].disposition, "accepted");

        const duplicate = await ingest(
          supabase,
          firstSession,
          firstInstallation,
          [firstEvent]
        );
        assert.deepEqual(duplicate.acceptedIds, [firstEvent.eventId]);
        assert.equal(duplicate.results[0].disposition, "duplicate_event");

        const validPartial = canonicalEvent({
          eventId: uuid(),
          installationId: firstInstallation,
          clientSequence: 2,
          eventType: "calibration_answered",
          payload: { trait: "presence", answer: 2 }
        });
        const rejectedPartial = canonicalEvent({
          eventId: uuid(),
          installationId: firstInstallation,
          clientSequence: 3,
          eventType: "reflection_submitted",
          payload: { privateNote: "must never reach the server" }
        });
        const partial = await ingest(
          supabase,
          firstSession,
          firstInstallation,
          [validPartial, rejectedPartial]
        );
        assert.deepEqual(partial.acceptedIds, [validPartial.eventId]);
        assert.equal(partial.results[0].accepted, true);
        assert.equal(partial.results[1].accepted, false);
        assert.equal(partial.results[1].disposition, "permanent_schema");

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
        firstSession = await supabase.refresh(firstSession);
        const recoveredProjection = await supabase.rpc(
          "get_progress_projection",
          {},
          firstSession.accessToken
        );
        assert.ok(recoveredProjection.value);
      }
    );

    await recorder.run("season_join_day_and_window_rules", async () => {
      const preJoinBoss = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 4,
          eventType: "boss_participated",
          bossEventId: r2Fixture.bossEventId
        })
      );
      assertRejected(preJoinBoss, "invalid_transition");

      const joined = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 5,
          eventType: "season_joined"
        })
      );
      assertAccepted(joined);
      const duplicateJoin = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 6,
          eventType: "season_joined"
        })
      );
      assertAccepted(duplicateJoin);

      const closedJoin = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 7,
          eventType: "season_joined",
          seasonId: r2Fixture.closedSeasonId
        })
      );
      assertRejected(closedJoin, "invalid_transition");

      const unavailableDay = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 8,
          eventType: "season_day_completed",
          day: 2
        })
      );
      assertRejected(unavailableDay, "invalid_transition");

      const completedDay = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 9,
          eventType: "season_day_completed",
          day: 1
        })
      );
      assertAccepted(completedDay);
      const duplicateDay = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 10,
          eventType: "season_day_completed",
          day: 1
        })
      );
      assertAccepted(duplicateDay);

      const futureBoss = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 11,
          eventType: "boss_participated",
          bossEventId: r2Fixture.futureBossEventId
        })
      );
      assertRejected(futureBoss, "invalid_transition");

      const clientArtifact = await ingestOne(
        supabase,
        firstSession,
        firstInstallation,
        seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 12,
          eventType: "artifact_unlocked"
        })
      );
      assertRejected(clientArtifact, "invalid_transition");

      const secondJoin = await ingestOne(
        supabase,
        second,
        secondInstallation,
        seasonEvent({
          uuid,
          installationId: secondInstallation,
          sequence: 1,
          eventType: "season_joined"
        })
      );
      assertAccepted(secondJoin);

      const belowThreshold = await supabase.rpc(
        "get_active_season",
        {},
        firstSession.accessToken
      );
      assert.equal(belowThreshold.value.payload.socialProof, undefined);
      await database.query(seedBelowThresholdSql);
      const seededBelowThreshold = await supabase.rpc(
        "get_active_season",
        {},
        firstSession.accessToken
      );
      assert.equal(seededBelowThreshold.value.payload.socialProof, undefined);
    });

    await recorder.run(
      "concurrent_boss_artifact_and_social_proof",
      async () => {
        const firstBoss = seasonEvent({
          uuid,
          installationId: firstInstallation,
          sequence: 13,
          eventType: "boss_participated",
          bossEventId: r2Fixture.bossEventId
        });
        const secondBoss = seasonEvent({
          uuid,
          installationId: secondInstallation,
          sequence: 2,
          eventType: "boss_participated",
          bossEventId: r2Fixture.bossEventId
        });
        const [firstBossAck, secondBossAck] = await Promise.all([
          ingestOne(
            supabase,
            firstSession,
            firstInstallation,
            firstBoss
          ),
          ingestOne(supabase, second, secondInstallation, secondBoss)
        ]);
        assertAccepted(firstBossAck);
        assertAccepted(secondBossAck);

        const duplicateBoss = await ingestOne(
          supabase,
          firstSession,
          firstInstallation,
          seasonEvent({
            uuid,
            installationId: firstInstallation,
            sequence: 14,
            eventType: "boss_participated",
            bossEventId: r2Fixture.bossEventId
          })
        );
        assertAccepted(duplicateBoss);

        const state = JSON.parse(
          await database.query(seasonVerificationSql, {
            first_user_id: first.userId
          })
        );
        assert.deepEqual(state, {
          firstSeasonRows: 1,
          firstDayRows: 1,
          bossParticipationRows: 2,
          artifactRows: 2,
          aggregateValue: 20
        });

        const firstArtifacts = await supabase.rest(
          "user_artifacts?select=artifact_id,user_id",
          { method: "GET", accessToken: firstSession.accessToken }
        );
        const secondArtifacts = await supabase.rest(
          "user_artifacts?select=artifact_id,user_id",
          { method: "GET", accessToken: second.accessToken }
        );
        assert.deepEqual(firstArtifacts.value, [
          { artifact_id: r2Fixture.artifactId, user_id: first.userId }
        ]);
        assert.deepEqual(secondArtifacts.value, [
          { artifact_id: r2Fixture.artifactId, user_id: second.userId }
        ]);

        const crossUserArtifacts = await supabase.rest(
          `user_artifacts?select=artifact_id&user_id=eq.${second.userId}`,
          { method: "GET", accessToken: firstSession.accessToken }
        );
        assert.deepEqual(crossUserArtifacts.value, []);

        const projection = await supabase.rpc(
          "get_progress_projection",
          {},
          firstSession.accessToken
        );
        assert.deepEqual(
          projection.value.ownedArtifacts.map((artifact) => artifact.artifactId),
          [r2Fixture.artifactId]
        );

        const visible = await supabase.rpc(
          "get_active_season",
          {},
          firstSession.accessToken
        );
        assert.deepEqual(
          Object.keys(visible.value.payload.socialProof).sort(),
          [
            "aggregateKey",
            "threshold",
            "value",
            "windowEndsAt",
            "windowStartsAt"
          ]
        );
        assert.equal(visible.value.payload.socialProof.value, 20);
        assert.doesNotMatch(
          JSON.stringify(visible.value.payload.socialProof),
          /identity|private|reflection|userId/i
        );
      }
    );

    await recorder.run("flutter_client_contract", async () => {
      const report = await clientAcceptance.run(
        path.join(repositoryRoot, "mobile")
      );
      clientChecks = [...report.checks];
      assert.ok(clientChecks.length >= 6);
    });

    await recorder.run(
      "delete_everywhere_and_cross_user_survival",
      async () => {
        const crossUserDelete = await supabase.request(
          `/rest/v1/user_installations?user_id=eq.${second.userId}`,
          {
            method: "DELETE",
            accessToken: firstSession.accessToken,
            allowFailure: true
          }
        );
        assert.equal(crossUserDelete.ok, false);
        assert.ok([401, 403].includes(crossUserDelete.status));

        const parameterizedDelete = await supabase.request(
          "/rest/v1/rpc/delete_my_data",
          {
            body: { p_user_id: second.userId },
            accessToken: firstSession.accessToken,
            allowFailure: true
          }
        );
        assert.equal(parameterizedDelete.ok, false);

        const deletion = await supabase.rpc(
          "delete_my_data",
          {},
          firstSession.accessToken
        );
        assert.equal(deletion.value.remoteUserId, first.userId);
        assert.equal(deletion.value.authIdentityDeleted, true);

        const retry = await supabase.request("/rest/v1/rpc/delete_my_data", {
          body: {},
          accessToken: firstSession.accessToken,
          allowFailure: true
        });
        if (retry.ok) {
          assert.deepEqual(retry.value, deletion.value);
        } else {
          assert.equal(retry.status, 401);
        }

        const deletedSession = await supabase.request(
          "/rest/v1/rpc/get_progress_projection",
          {
            body: {},
            accessToken: firstSession.accessToken,
            allowFailure: true
          }
        );
        assert.equal(deletedSession.ok, false);

        const survivingProjection = await supabase.rpc(
          "get_progress_projection",
          {},
          second.accessToken
        );
        assert.ok(survivingProjection.value);
        const survivingSeason = await supabase.rpc(
          "get_active_season",
          {},
          second.accessToken
        );
        assert.equal(survivingSeason.value.payload.socialProof, undefined);

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
          deletedProgress: 0,
          deletedSeasonParticipation: 0,
          deletedSeasonDays: 0,
          deletedBossParticipation: 0,
          deletedArtifacts: 0,
          deletionReceipts: 1,
          socialValueAfterDeletion: 19,
          survivingAuthUsers: 1,
          survivingInstallations: 1,
          survivingBossParticipation: 1,
          survivingArtifacts: 1
        });
      }
    );

    return withClientChecks(
      recorder.report({
        environment: environmentSummary,
        migrationVersions,
        result: "passed"
      }),
      clientChecks
    );
  } catch (error) {
    error.r2Report = withClientChecks(
      recorder.report({
        environment: environmentSummary,
        migrationVersions,
        result: "failed"
      }),
      clientChecks
    );
    throw error;
  }
}

function withClientChecks(report, clientChecks) {
  return Object.freeze({
    ...report,
    commands: Object.freeze({
      acceptance: "npm run supabase:live",
      migrations: "psql --single-transaction --file=<versioned migration>",
      fixture: "runner-managed deterministic R2 fixture via psql --command",
      flutterClient:
        "flutter test --no-pub --no-test-assets -j 1 test/live/r2_live_supabase_test.dart"
    }),
    clientChecks: [...clientChecks]
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

async function ingestOne(client, session, installationId, event) {
  return ingest(client, session, installationId, [event]);
}

function seasonEvent({
  uuid,
  installationId,
  sequence,
  eventType,
  seasonId = r2Fixture.seasonId,
  bossEventId,
  day
}) {
  const boss = eventType === "boss_participated";
  return canonicalEvent({
    eventId: uuid(),
    installationId,
    clientSequence: sequence,
    eventType,
    contentId: boss ? r2Fixture.contentId : null,
    contentRevision: boss ? r2Fixture.contentRevision : null,
    payload: {
      seasonId,
      seasonRevision: 1,
      ...(bossEventId === undefined ? {} : { bossEventId, route: "normal" }),
      ...(day === undefined ? {} : { day })
    }
  });
}

function assertAccepted(ack) {
  assert.equal(ack.results.length, 1);
  assert.equal(ack.results[0].accepted, true);
  assert.equal(ack.results[0].disposition, "accepted");
  assert.deepEqual(ack.acceptedIds, [ack.results[0].eventId]);
}

function assertRejected(ack, disposition) {
  assert.equal(ack.results.length, 1);
  assert.equal(ack.results[0].accepted, false);
  assert.equal(ack.results[0].disposition, disposition);
  assert.deepEqual(ack.acceptedIds, []);
}

async function writeReport(reportPath, report) {
  if (!reportPath || report === undefined) return;
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, {
    flag: "wx"
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const reportPath = process.env.MAYHEM_R2_REPORT_PATH?.trim();
  try {
    const report = await runLiveSupabaseAcceptance();
    await writeReport(reportPath, report);
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } catch (error) {
    try {
      await writeReport(reportPath, error.r2Report);
    } catch {
      process.stderr.write("R2 acceptance report could not be written\n");
    }
    process.stderr.write(`R2 acceptance failed: ${error.message}\n`);
    process.exitCode = 1;
  }
}
