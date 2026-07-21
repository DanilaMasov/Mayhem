import { readFile, writeFile } from "node:fs/promises";

import {
  LiveSentryAcceptanceError,
  failedLiveSentryReport,
  inspectLiveSentrySubmission,
  loadLiveSentryConfig,
  verifyLiveSentryReport
} from "./lib/live_sentry_acceptance.mjs";

export async function runLiveSentryAcceptance({
  environment = process.env,
  fetchImpl = fetch,
  clock = Date.now,
  sleep
} = {}) {
  const submissionPath = requiredPath(
    environment.MAYHEM_R5_SENTRY_SUBMISSION_PATH,
    "sentry_submission_path_required"
  );
  const reportPath = requiredPath(
    environment.MAYHEM_R5_SENTRY_REPORT_PATH,
    "sentry_report_path_required"
  );
  try {
    const config = loadLiveSentryConfig(environment);
    const submission = JSON.parse(await readFile(submissionPath, "utf8"));
    const report = await inspectLiveSentrySubmission({
      config,
      submission,
      fetchImpl,
      clock,
      ...(sleep ? { sleep } : {})
    });
    verifyLiveSentryReport({
      report,
      expectedEventId: submission.eventId,
      environment
    });
    await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, {
      mode: 0o600
    });
    return report;
  } catch (error) {
    const code =
      error instanceof LiveSentryAcceptanceError
        ? error.code
        : "sentry_acceptance_unexpected_failure";
    await writeFile(
      reportPath,
      `${JSON.stringify(failedLiveSentryReport({ code, clock }), null, 2)}\n`,
      { mode: 0o600 }
    );
    throw new LiveSentryAcceptanceError(code);
  }
}

function requiredPath(value, code) {
  const result = typeof value === "string" ? value.trim() : "";
  if (!result) throw new LiveSentryAcceptanceError(code);
  return result;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  runLiveSentryAcceptance()
    .then((report) => {
      process.stdout.write(
        `R5 Sentry event verified: ${report.checks.length} checks passed\n`
      );
    })
    .catch((error) => {
      const code =
        error instanceof LiveSentryAcceptanceError
          ? error.code
          : "sentry_acceptance_unexpected_failure";
      process.stderr.write(`R5 Sentry acceptance failed: ${code}\n`);
      process.exitCode = 1;
    });
}
