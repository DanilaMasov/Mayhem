import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  LiveSentryAcceptanceError,
  inspectLiveSentrySubmission,
  loadLiveSentryConfig,
  sentryAcceptanceChecks,
  verifyLiveSentryEvent,
  verifyLiveSentryReport
} from "../scripts/lib/live_sentry_acceptance.mjs";
import { runLiveSentryAcceptance } from "../scripts/run_live_sentry_acceptance.mjs";

const workflow = read(".github/workflows/staging-sentry-acceptance.yml");

test("staging Sentry acceptance is protected, manual, and main-only", () => {
  assert.match(workflow, /^\s{2}workflow_dispatch:/m);
  assert.doesNotMatch(workflow, /^\s{2}(?:push|pull_request):/m);
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/);
  assert.match(
    workflow,
    /I_UNDERSTAND_THIS_SENDS_A_SYNTHETIC_STAGING_EVENT/
  );
  assert.match(workflow, /environment: staging-acceptance/);
  assert.match(workflow, /permissions:\s+contents: read/);
  assert.match(workflow, /secrets\.MAYHEM_SENTRY_DSN/);
  assert.match(workflow, /secrets\.SENTRY_AUTH_TOKEN/);
  assert.match(workflow, /vars\.SENTRY_ORG/);
  assert.match(workflow, /vars\.SENTRY_PROJECT/);
  assert.doesNotMatch(workflow, /service_role|production/i);
});

test("workflow submits through Flutter and uploads only bounded evidence", () => {
  assert.match(workflow, /flutter pub get --enforce-lockfile/);
  assert.match(
    workflow,
    /flutter test --no-pub --no-test-assets -j 1/
  );
  assert.doesNotMatch(workflow, /flutter test --release/);
  assert.match(workflow, /test\/live\/r5_live_sentry_test\.dart/);
  assert.match(workflow, /node scripts\/run_live_sentry_acceptance\.mjs/);
  assert.match(workflow, /node scripts\/verify_live_sentry_report\.mjs/);
  assert.match(workflow, /path: \/tmp\/mayhem-r5-sentry-report\.json/);
  assert.doesNotMatch(workflow, /path:.*submission/);
  assert.match(workflow, /retention-days: 7/);

  const submitStep = workflow.slice(
    workflow.indexOf("- name: Submit one scrubbed staging privacy probe"),
    workflow.indexOf("- name: Inspect live event and attachments")
  );
  assert.match(submitStep, /secrets\.MAYHEM_SENTRY_DSN/);
  assert.doesNotMatch(submitStep, /SENTRY_AUTH_TOKEN|SENTRY_ORG|SENTRY_PROJECT/);
});

test("live Sentry configuration rejects unsafe or production inputs", () => {
  const config = loadLiveSentryConfig(protectedEnvironment);
  assert.equal(config.environmentId, "mayhem-staging-sentry");
  assert.equal(config.apiBaseUrl, "https://de.sentry.io");

  for (const environment of [
    { ...protectedEnvironment, MAYHEM_R5_SENTRY_ENVIRONMENT_ID: "production" },
    { ...protectedEnvironment, MAYHEM_SENTRY_DSN: validDsn.replace("https", "http") },
    {
      ...protectedEnvironment,
      MAYHEM_SENTRY_DSN: validDsn.replace("public-key", "public-key:secret")
    },
    {
      ...protectedEnvironment,
      MAYHEM_SENTRY_DSN: validDsn.replace("public-key", "public-key%3Asecret")
    },
    { ...protectedEnvironment, SENTRY_API_BASE_URL: "https://example.invalid" },
    { ...protectedEnvironment, SENTRY_API_BASE_URL: "https://sentry.io:8443" },
    { ...protectedEnvironment, SENTRY_AUTH_TOKEN: "" }
  ]) {
    assert.throws(
      () => loadLiveSentryConfig(environment),
      LiveSentryAcceptanceError
    );
  }
});

test("event inspection proves ingestion, scrubbing, and no attachments", async () => {
  const submission = passingSubmission();
  const responses = [
    response(404, {}),
    response(200, passingEvent(submission)),
    response(200, [])
  ];
  let now = Date.parse("2026-07-21T10:00:00.000Z");
  const report = await inspectLiveSentrySubmission({
    config: loadLiveSentryConfig(protectedEnvironment),
    submission,
    fetchImpl: async () => responses.shift(),
    sleep: async () => {},
    clock: () => {
      now += 10;
      return now;
    },
    retryDelayMs: 0
  });
  assert.equal(report.result, "passed");
  assert.deepEqual(report.checks, sentryAcceptanceChecks);
  assert.equal(report.event.eventId, submission.eventId);

  assert.throws(
    () =>
      verifyLiveSentryEvent({
        event: {
          ...passingEvent(submission),
          message: submission.privateMarker
        },
        attachments: [],
        submission
      }),
    /sentry_private_marker_leaked/
  );
  assert.throws(
    () =>
      verifyLiveSentryEvent({
        event: passingEvent(submission),
        attachments: [{ name: "private.txt" }],
        submission
      }),
    /sentry_attachment_present/
  );
});

test("report verifier accepts bounded evidence and rejects protected values", () => {
  const submission = passingSubmission();
  const report = passingReport(submission);
  assert.deepEqual(
    verifyLiveSentryReport({
      report,
      expectedEventId: submission.eventId,
      environment: protectedEnvironment
    }),
    { eventId: submission.eventId, checks: 9 }
  );
  assert.throws(
    () =>
      verifyLiveSentryReport({
        report: { ...report, leaked: protectedEnvironment.SENTRY_AUTH_TOKEN },
        environment: protectedEnvironment
      }),
    /sentry_report_contains_protected_value/
  );
});

test("runner writes only the verified secret-free report", async () => {
  const temporaryDirectory = await mkdtemp(
    path.join(tmpdir(), "mayhem-sentry-acceptance-")
  );
  const submissionPath = path.join(temporaryDirectory, "submission.json");
  const reportPath = path.join(temporaryDirectory, "report.json");
  const environment = {
    ...protectedEnvironment,
    MAYHEM_R5_SENTRY_SUBMISSION_PATH: submissionPath,
    MAYHEM_R5_SENTRY_REPORT_PATH: reportPath
  };
  const submission = passingSubmission();
  try {
    await writeFile(submissionPath, JSON.stringify(submission));
    const responses = [
      response(200, passingEvent(submission)),
      response(200, [])
    ];
    await runLiveSentryAcceptance({
      environment,
      fetchImpl: async () => responses.shift(),
      sleep: async () => {},
      clock: () => Date.parse("2026-07-21T10:00:01.000Z")
    });
    const serialized = await readFile(reportPath, "utf8");
    assert.doesNotMatch(serialized, /MAYHEM_R5_PRIVATE_SENTINEL/);
    assert.doesNotMatch(serialized, /synthetic-project-read-token/);
    assert.doesNotMatch(serialized, /https:\/\/public-key@/);
    assert.equal(JSON.parse(serialized).result, "passed");
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
});

const validDsn = [
  "https://public-key",
  "@o123.ingest.sentry.io",
  "/456"
].join("");

const protectedEnvironment = {
  MAYHEM_R5_SENTRY_CONFIRM:
    "I_UNDERSTAND_THIS_SENDS_A_SYNTHETIC_STAGING_EVENT",
  MAYHEM_R5_SENTRY_ENVIRONMENT_ID: "mayhem-staging-sentry",
  MAYHEM_SENTRY_DSN: validDsn,
  SENTRY_AUTH_TOKEN: "synthetic-project-read-token",
  SENTRY_ORG: "mayhem-org",
  SENTRY_PROJECT: "mayhem-staging",
  SENTRY_API_BASE_URL: "https://de.sentry.io"
};

function passingSubmission() {
  return {
    schemaVersion: 1,
    eventId: "a".repeat(32),
    release: "com.danilamasov.mayhem.staging@0.0.0+1",
    environment: "staging",
    policyTag: "staging_crash_v1",
    privateMarker: "MAYHEM_R5_PRIVATE_SENTINEL_DO_NOT_INGEST",
    submittedAt: "2026-07-21T10:00:00.000Z"
  };
}

function passingEvent(submission) {
  return {
    eventID: submission.eventId,
    user: null,
    request: null,
    tags: [
      { key: "environment", value: submission.environment },
      { key: "release", value: submission.release },
      { key: "privacy_policy", value: submission.policyTag }
    ],
    entries: [
      {
        type: "exception",
        data: {
          values: [
            {
              type: "SyntheticPrivacyProbe",
              value: "details redacted",
              stacktrace: {
                frames: [
                  {
                    filename: "features/acceptance/probe.dart",
                    function: "runPrivacyProbe",
                    lineNo: 42
                  }
                ]
              }
            }
          ]
        }
      }
    ]
  };
}

function passingReport(submission) {
  return {
    schemaVersion: 1,
    environment: {
      environmentId: "mayhem-staging-sentry",
      apiHost: "de.sentry.io",
      organizationConfigured: true,
      projectConfigured: true
    },
    event: {
      eventId: submission.eventId,
      environment: submission.environment,
      release: submission.release,
      policyTag: submission.policyTag
    },
    startedAt: "2026-07-21T10:00:00.000Z",
    completedAt: "2026-07-21T10:00:01.000Z",
    durationMs: 1000,
    checks: [...sentryAcceptanceChecks],
    result: "passed"
  };
}

function response(status, body) {
  return {
    status,
    async json() {
      return body;
    }
  };
}

function read(relativePath) {
  return readFileSync(new URL(`../${relativePath}`, import.meta.url), "utf8");
}
