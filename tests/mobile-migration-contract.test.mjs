import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import test from "node:test";

const source = await readFile("mobile/database/migrations/005_feed_vnext.sql", "utf8");
const verticalSliceSource = await readFile(
  "mobile/database/migrations/006_feed_vertical_slice.sql",
  "utf8"
);

test("mobile v5 migration is additive and covers the Feed vNext schema", () => {
  assert.doesNotMatch(source, /\bDROP\s+(?:TABLE|COLUMN|INDEX)\b/iu);
  assert.doesNotMatch(source, /\bDELETE\s+FROM\b/iu);
  for (const table of [
    "user_identity",
    "content_item_revisions",
    "feed_batches",
    "feed_assignments",
    "challenge_attempts",
    "private_reflections",
    "event_log_v2",
    "projection_checkpoints",
    "event_quarantine",
    "feature_flags_cache"
  ]) {
    assert.match(source, new RegExp(`CREATE TABLE IF NOT EXISTS ${table}\\b`, "u"));
  }
  assert.match(source, /UNIQUE \(installation_id, client_sequence\)/u);
  assert.match(source, /private_note TEXT/u);
});

test("mobile v6 migration prevents duplicate attempts per assignment", () => {
  assert.doesNotMatch(verticalSliceSource, /\bDROP\s+(?:TABLE|COLUMN|INDEX)\b/iu);
  assert.match(
    verticalSliceSource,
    /ADD COLUMN active INTEGER NOT NULL DEFAULT 1/iu
  );
  assert.match(
    verticalSliceSource,
    /CREATE UNIQUE INDEX IF NOT EXISTS challenge_attempts_assignment_idx/iu
  );
  assert.match(verticalSliceSource, /ON challenge_attempts \(assignment_id\)/u);
});

test("mobile v5 schema executes for fresh and v4 databases", () => {
  const result = spawnSync("python3", ["scripts/test_mobile_migration.py"], {
    encoding: "utf8"
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.match(result.stdout, /fresh, v4 upgrade and rollback/u);
});
