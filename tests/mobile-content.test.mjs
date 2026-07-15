import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { buildMobileContent } from "../scripts/export_mobile_content.mjs";

const contentPaths = {
  quests: new URL("../mobile/assets/content/quest_catalog.json", import.meta.url),
  guides: new URL("../mobile/assets/content/guide_catalog.json", import.meta.url),
  dialogs: new URL("../mobile/assets/content/dialog_catalog.json", import.meta.url),
  modifiers: new URL("../mobile/assets/content/modifier_catalog.json", import.meta.url)
};

async function readJson(url) {
  return JSON.parse(await readFile(url, "utf8"));
}

test("mobile content is an exact deterministic export of the source catalog", async () => {
  const expected = buildMobileContent();
  const actual = {
    quests: await readJson(contentPaths.quests),
    guides: await readJson(contentPaths.guides),
    dialogs: await readJson(contentPaths.dialogs),
    modifiers: await readJson(contentPaths.modifiers)
  };

  assert.deepEqual(actual, expected);
  assert.equal(actual.quests.quests.length, 50);
  assert.equal(actual.quests.bosses.length, 5);
  assert.equal(actual.guides.guides.length, 55);
  assert.equal(actual.dialogs.dialogs.length, 29);
  assert.equal(actual.modifiers.modifiers.length, 5);
});
