import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const workflow = read(".github/workflows/staging-release-smoke.yml");

test("staging release smoke is pull-request or manually triggered only", () => {
  assert.match(workflow, /^\s{2}pull_request:/m);
  assert.match(workflow, /^\s{2}workflow_dispatch:/m);
  assert.doesNotMatch(workflow, /^\s{2}push:/m);
  assert.match(workflow, /permissions:\s+contents: read/);
});

test("Android smoke compiles one unsigned staging release", () => {
  assert.match(workflow, /flutter build appbundle --release --flavor staging/);
  assert.match(workflow, /--dart-define=MAYHEM_ENVIRONMENT=staging/);
  assert.match(workflow, /app-staging-release\.aab/);
  assert.doesNotMatch(workflow, /MAYHEM_ANDROID_KEYSTORE/);
});

test("iOS smoke compiles staging without signing", () => {
  assert.match(
    workflow,
    /flutter build ios --release --no-codesign --flavor staging/
  );
  assert.match(workflow, /build\/ios\/iphoneos\/Runner\.app/);
});

test("release smoke uses locked dependencies and never targets production", () => {
  assert.equal(
    [...workflow.matchAll(/flutter pub get --enforce-lockfile/g)].length,
    2
  );
  assert.doesNotMatch(workflow, /--flavor production/);
  assert.doesNotMatch(workflow, /MAYHEM_ENVIRONMENT=production/);
  assert.doesNotMatch(workflow, /SUPABASE_(?:URL|ANON_KEY)/);
});

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
}
