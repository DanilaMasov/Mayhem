import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const workflow = readFileSync(
  new URL("../.github/workflows/android-preview-apk.yml", import.meta.url),
  "utf8"
);

test("Android preview workflow is manual and least privileged", () => {
  assert.match(workflow, /workflow_dispatch:/);
  assert.doesNotMatch(workflow, /^\s+(?:push|pull_request):/m);
  assert.match(workflow, /permissions:\s*\n\s+contents: read/);
  assert.match(workflow, /github\.ref == 'refs\/heads\/main'/);
  assert.match(workflow, /cancel-in-progress: false/);
});

test("preview builds only a debug-signed staging APK with local Feed", () => {
  assert.match(
    workflow,
    /flutter build apk --debug --flavor staging --no-pub/
  );
  assert.match(workflow, /MAYHEM_ENVIRONMENT=staging/);
  assert.match(workflow, /MAYHEM_NEW_FEED_ENABLED=true/);
  assert.match(workflow, /apksigner" verify --verbose/);
  assert.doesNotMatch(workflow, /flutter build appbundle|--release/);
  assert.doesNotMatch(workflow, /MAYHEM_ENVIRONMENT=production/);
});

test("preview consumes no backend or telemetry secret", () => {
  assert.doesNotMatch(
    workflow,
    /secrets\.|SUPABASE_|SENTRY_|MAYHEM_SUPPORT_CONTACT/
  );
  assert.match(workflow, /flutter pub get --enforce-lockfile/);
});

test("preview upload contains APK and checksum with bounded retention", () => {
  assert.match(workflow, /actions\/upload-artifact@v4/);
  assert.match(workflow, /Mayhem-staging-preview\.apk/);
  assert.match(workflow, /sha256sum/);
  assert.match(workflow, /if-no-files-found: error/);
  assert.match(workflow, /retention-days: 7/);
});
