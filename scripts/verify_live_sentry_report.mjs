import { readFile } from "node:fs/promises";

import {
  LiveSentryAcceptanceError,
  verifyLiveSentryReport
} from "./lib/live_sentry_acceptance.mjs";

export async function verifyLiveSentryReportFile({
  environment = process.env
} = {}) {
  const reportPath = environment.MAYHEM_R5_SENTRY_REPORT_PATH?.trim();
  if (!reportPath) {
    throw new LiveSentryAcceptanceError("sentry_report_path_required");
  }
  const report = JSON.parse(await readFile(reportPath, "utf8"));
  return verifyLiveSentryReport({ report, environment });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  verifyLiveSentryReportFile()
    .then((result) => {
      process.stdout.write(
        `R5 Sentry report verified: ${result.checks} checks passed\n`
      );
    })
    .catch((error) => {
      const code =
        error instanceof LiveSentryAcceptanceError
          ? error.code
          : "sentry_report_unexpected_failure";
      process.stderr.write(`R5 Sentry report verification failed: ${code}\n`);
      process.exitCode = 1;
    });
}
