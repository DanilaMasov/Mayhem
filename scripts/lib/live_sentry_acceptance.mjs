const confirmation = "I_UNDERSTAND_THIS_SENDS_A_SYNTHETIC_STAGING_EVENT";

export const sentryAcceptanceChecks = Object.freeze([
  "event_ingested",
  "event_id_matches",
  "staging_environment_matches",
  "release_matches",
  "privacy_policy_tag_matches",
  "private_marker_absent",
  "user_request_and_breadcrumbs_absent",
  "exception_details_redacted",
  "attachments_absent"
]);

export class LiveSentryAcceptanceError extends Error {
  constructor(code) {
    super(code);
    this.name = "LiveSentryAcceptanceError";
    this.code = code;
  }
}

export function loadLiveSentryConfig(environment = process.env) {
  requireEqual(
    environment.MAYHEM_R5_SENTRY_CONFIRM,
    confirmation,
    "sentry_live_confirmation_required"
  );
  const environmentId = requireValue(
    environment.MAYHEM_R5_SENTRY_ENVIRONMENT_ID,
    "sentry_environment_id_required"
  );
  check(
    /^[a-z0-9][a-z0-9._-]{2,63}$/i.test(environmentId) &&
      !/prod(?:uction)?/i.test(environmentId),
    "sentry_environment_id_invalid"
  );
  const dsn = requireValue(
    environment.MAYHEM_SENTRY_DSN,
    "sentry_dsn_required"
  );
  validatePublicDsn(dsn);
  const authToken = requireValue(
    environment.SENTRY_AUTH_TOKEN,
    "sentry_auth_token_required"
  );
  check(authToken.length >= 8, "sentry_auth_token_invalid");
  const organization = requireSlug(
    environment.SENTRY_ORG,
    "sentry_organization_invalid"
  );
  const project = requireSlug(
    environment.SENTRY_PROJECT,
    "sentry_project_invalid"
  );
  const apiBaseUrl = validateApiBaseUrl(
    environment.SENTRY_API_BASE_URL || "https://sentry.io"
  );
  return Object.freeze({
    environmentId,
    dsn,
    authToken,
    organization,
    project,
    apiBaseUrl
  });
}

export async function inspectLiveSentrySubmission({
  config,
  submission,
  fetchImpl = fetch,
  clock = Date.now,
  sleep = (milliseconds) =>
    new Promise((resolve) => setTimeout(resolve, milliseconds)),
  maxAttempts = 20,
  retryDelayMs = 6000
}) {
  validateSubmission(submission);
  const startedAtMs = clock();
  const eventUrl = projectEventUrl(config, submission.eventId);
  let event;
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const response = await requestSentry(eventUrl, config, fetchImpl);
    if (response.status === 200) {
      event = await boundedJson(response, "sentry_event_response_invalid");
      break;
    }
    if (response.status !== 404 && response.status !== 429) {
      fail(apiStatusCode(response.status));
    }
    if (attempt < maxAttempts) await sleep(retryDelayMs);
  }
  check(event != null, "sentry_event_not_ingested_before_timeout");

  const attachmentResponse = await requestSentry(
    `${eventUrl}attachments/`,
    config,
    fetchImpl
  );
  check(
    attachmentResponse.status === 200,
    apiStatusCode(attachmentResponse.status, "sentry_attachments")
  );
  const attachments = await boundedJson(
    attachmentResponse,
    "sentry_attachments_response_invalid"
  );
  verifyLiveSentryEvent({ event, attachments, submission });

  const completedAtMs = clock();
  return Object.freeze({
    schemaVersion: 1,
    environment: {
      environmentId: config.environmentId,
      apiHost: new URL(config.apiBaseUrl).host,
      organizationConfigured: true,
      projectConfigured: true
    },
    event: {
      eventId: submission.eventId,
      environment: submission.environment,
      release: submission.release,
      policyTag: submission.policyTag
    },
    startedAt: new Date(startedAtMs).toISOString(),
    completedAt: new Date(completedAtMs).toISOString(),
    durationMs: completedAtMs - startedAtMs,
    checks: [...sentryAcceptanceChecks],
    result: "passed"
  });
}

export function verifyLiveSentryEvent({ event, attachments, submission }) {
  const serialized = JSON.stringify(event);
  check(event?.eventID === submission.eventId, "sentry_event_id_mismatch");
  check(
    !serialized.includes(submission.privateMarker),
    "sentry_private_marker_leaked"
  );

  const tags = tagMap(event?.tags);
  check(
    tags.get("environment") === submission.environment,
    "sentry_environment_mismatch"
  );
  check(tags.get("release") === submission.release, "sentry_release_mismatch");
  check(
    tags.get("privacy_policy") === submission.policyTag,
    "sentry_privacy_policy_mismatch"
  );
  check(event?.user == null, "sentry_user_present");
  check(event?.request == null, "sentry_request_present");

  const entries = Array.isArray(event?.entries) ? event.entries : [];
  check(
    entries.every((entry) => !["breadcrumbs", "request"].includes(entry?.type)),
    "sentry_private_entry_present"
  );
  const exceptionEntry = entries.find((entry) => entry?.type === "exception");
  const exceptions = exceptionEntry?.data?.values;
  check(
    Array.isArray(exceptions) && exceptions.length === 1,
    "sentry_exception_missing"
  );
  check(
    exceptions[0]?.type === "SyntheticPrivacyProbe" &&
      exceptions[0]?.value === "details redacted",
    "sentry_exception_not_redacted"
  );
  check(Array.isArray(attachments), "sentry_attachments_response_invalid");
  check(attachments.length === 0, "sentry_attachment_present");
  return true;
}

export function verifyLiveSentryReport({
  report,
  expectedEventId,
  environment = process.env
}) {
  assertNoProtectedValues(JSON.stringify(report), environment);
  check(report?.schemaVersion === 1, "sentry_report_schema_invalid");
  check(report?.result === "passed", "sentry_report_not_passed");
  check(
    /^[a-f0-9]{32}$/.test(report?.event?.eventId ?? ""),
    "sentry_report_event_id_invalid"
  );
  if (expectedEventId) {
    check(
      report.event.eventId === expectedEventId,
      "sentry_report_event_id_mismatch"
    );
  }
  check(report.event.environment === "staging", "sentry_report_environment_invalid");
  check(
    /^com\.danilamasov\.mayhem\.staging@\d+\.\d+\.\d+\+\d+$/.test(
      report.event.release ?? ""
    ),
    "sentry_report_release_invalid"
  );
  check(
    report.event.policyTag === "staging_crash_v1",
    "sentry_report_policy_invalid"
  );
  check(
    /^[a-z0-9][a-z0-9._-]{2,63}$/i.test(
      report?.environment?.environmentId ?? ""
    ) && !/prod(?:uction)?/i.test(report.environment.environmentId),
    "sentry_report_environment_id_invalid"
  );
  check(
    /^(?:[a-z0-9-]+\.)*sentry\.io$/i.test(report.environment.apiHost ?? ""),
    "sentry_report_api_host_invalid"
  );
  check(
    report.environment.organizationConfigured === true &&
      report.environment.projectConfigured === true,
    "sentry_report_project_configuration_invalid"
  );
  check(
    JSON.stringify(report.checks) === JSON.stringify(sentryAcceptanceChecks),
    "sentry_report_checks_invalid"
  );
  check(
    Number.isFinite(Date.parse(report.startedAt)) &&
      Number.isFinite(Date.parse(report.completedAt)) &&
      Number.isInteger(report.durationMs) &&
      report.durationMs >= 0,
    "sentry_report_timing_invalid"
  );
  return Object.freeze({
    eventId: report.event.eventId,
    checks: report.checks.length
  });
}

export function failedLiveSentryReport({ code, clock = Date.now }) {
  return Object.freeze({
    schemaVersion: 1,
    completedAt: new Date(clock()).toISOString(),
    errorCode: safeErrorCode(code),
    result: "failed"
  });
}

function validateSubmission(submission) {
  check(submission?.schemaVersion === 1, "sentry_submission_schema_invalid");
  check(
    /^[a-f0-9]{32}$/.test(submission?.eventId ?? ""),
    "sentry_submission_event_id_invalid"
  );
  check(submission.environment === "staging", "sentry_submission_environment_invalid");
  check(
    /^com\.danilamasov\.mayhem\.staging@\d+\.\d+\.\d+\+\d+$/.test(
      submission.release ?? ""
    ),
    "sentry_submission_release_invalid"
  );
  check(
    submission.policyTag === "staging_crash_v1",
    "sentry_submission_policy_invalid"
  );
  check(
    typeof submission.privateMarker === "string" &&
      submission.privateMarker.length >= 16,
    "sentry_submission_private_marker_invalid"
  );
  check(
    Number.isFinite(Date.parse(submission.submittedAt)),
    "sentry_submission_time_invalid"
  );
}

function validatePublicDsn(value) {
  let url;
  let decodedPublicKey;
  try {
    url = new URL(value);
    decodedPublicKey = decodeURIComponent(url.username);
  } catch {
    fail("sentry_dsn_invalid");
  }
  check(
    url.protocol === "https:" &&
      url.hostname.length > 0 &&
      decodedPublicKey.length > 0 &&
      !decodedPublicKey.includes(":") &&
      !decodedPublicKey.includes("@") &&
      url.password.length === 0 &&
      url.search.length === 0 &&
      url.hash.length === 0 &&
      /^\d+$/.test(url.pathname.split("/").filter(Boolean).at(-1) ?? ""),
    "sentry_dsn_invalid"
  );
}

function validateApiBaseUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    fail("sentry_api_base_url_invalid");
  }
  check(
    url.protocol === "https:" &&
      /^(?:[a-z0-9-]+\.)*sentry\.io$/i.test(url.hostname) &&
      !url.port &&
      !url.username &&
      !url.password &&
      (url.pathname === "/" || url.pathname === "") &&
      !url.search &&
      !url.hash,
    "sentry_api_base_url_invalid"
  );
  return url.origin;
}

function projectEventUrl(config, eventId) {
  const organization = encodeURIComponent(config.organization);
  const project = encodeURIComponent(config.project);
  return `${config.apiBaseUrl}/api/0/projects/${organization}/${project}/events/${eventId}/`;
}

async function requestSentry(url, config, fetchImpl) {
  let response;
  try {
    response = await fetchImpl(url, {
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${config.authToken}`
      },
      signal: AbortSignal.timeout(15000)
    });
  } catch {
    fail("sentry_api_unreachable");
  }
  check(
    response != null && Number.isInteger(response.status),
    "sentry_api_response_invalid"
  );
  return response;
}

async function boundedJson(response, code) {
  try {
    return await response.json();
  } catch {
    fail(code);
  }
}

function apiStatusCode(status, prefix = "sentry_event") {
  if (status === 401 || status === 403) return "sentry_api_auth_rejected";
  return `${prefix}_http_${Number.isInteger(status) ? status : "unknown"}`;
}

function tagMap(tags) {
  check(Array.isArray(tags), "sentry_tags_missing");
  return new Map(
    tags
      .filter((tag) => typeof tag?.key === "string")
      .map((tag) => [tag.key, tag.value])
  );
}

function assertNoProtectedValues(serialized, environment) {
  const protectedValues = [
    environment.MAYHEM_SENTRY_DSN,
    environment.SENTRY_AUTH_TOKEN
  ].filter((value) => typeof value === "string" && value.length >= 4);
  for (const value of protectedValues) {
    check(!serialized.includes(value), "sentry_report_contains_protected_value");
  }
  check(
    !/https:\/\/[^\s/@]+@[^\s/]+\/\d+/i.test(serialized),
    "sentry_report_contains_dsn"
  );
  check(
    !/(?:sntrys_|sentry(?:_auth)?_token)[a-z0-9._-]{8,}/i.test(serialized),
    "sentry_report_contains_token"
  );
}

function requireSlug(value, code) {
  const result = requireValue(value, code);
  check(/^[a-z0-9][a-z0-9_-]{0,63}$/i.test(result), code);
  return result;
}

function requireValue(value, code) {
  const result = typeof value === "string" ? value.trim() : "";
  check(result.length > 0, code);
  return result;
}

function requireEqual(actual, expected, code) {
  check(actual === expected, code);
}

function safeErrorCode(value) {
  return /^[a-z0-9_]{3,80}$/.test(value ?? "")
    ? value
    : "sentry_acceptance_unexpected_failure";
}

function check(condition, code) {
  if (!condition) fail(code);
}

function fail(code) {
  throw new LiveSentryAcceptanceError(code);
}
