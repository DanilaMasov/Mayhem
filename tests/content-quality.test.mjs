import assert from "node:assert/strict";
import test from "node:test";

import {
  BOSS_QUESTS,
  QUESTS,
  getGuideForQuest,
  getNpcDialogForQuest
} from "../src/data.js";

const allQuests = [...QUESTS, ...BOSS_QUESTS];
const rehearsalQuests = [
  ...QUESTS.filter((quest) => !quest.isShadow && quest.level >= 2),
  ...BOSS_QUESTS
];

const bannedFragments = [
  "пенис",
  "секс",
  "имитируй акцент",
  "пародируй",
  "скрытая съёмка",
  "без согласия",
  "когнитив",
  "экспозицион",
  "диагноз",
  "вылечить тревогу"
];

function normalizedContent(quest) {
  const guide = getGuideForQuest(quest);
  const dialog = quest.isShadow || quest.level < 2
    ? null
    : getNpcDialogForQuest(quest);
  return JSON.stringify({ guide, dialog }).toLowerCase();
}

test("guides meet editorial diversity and mobile-length gates", () => {
  const stepSets = new Set();
  const phraseSets = new Set();

  for (const quest of allQuests) {
    const guide = getGuideForQuest(quest);
    assert.equal(guide.steps.length, 3, `${quest.id} must have three steps`);
    assert.ok(guide.phrases.length >= 3 && guide.phrases.length <= 5, `${quest.id} phrase count`);
    assert.ok(guide.steps.every((step) => step.length <= 180), `${quest.id} has an oversized step`);
    assert.ok(guide.phrases.every((phrase) => phrase.length <= 90), `${quest.id} has an oversized phrase`);
    assert.ok(guide.refusalScript.length <= 180, `${quest.id} has an oversized exit script`);
    assert.equal(
      bannedFragments.some((fragment) => normalizedContent(quest).includes(fragment)),
      false,
      `${quest.id} contains banned editorial content`
    );
    stepSets.add(JSON.stringify(guide.steps));
    phraseSets.add(JSON.stringify(guide.phrases));
  }

  assert.ok(stepSets.size >= 12, `guide step diversity regressed to ${stepSets.size}`);
  assert.ok(phraseSets.size >= 12, `guide phrase diversity regressed to ${phraseSets.size}`);
});

test("every rehearsal has a quest-specific branch and safe exit", () => {
  const ids = new Set();
  const bodies = new Set();

  for (const quest of rehearsalQuests) {
    const dialog = getNpcDialogForQuest(quest);
    assert.ok(ids.add(dialog.id), `duplicate dialog id: ${dialog.id}`);
    assert.ok(dialog.nodes[dialog.startNodeId].text.includes(quest.questText), `${quest.id} scenario is not personalized`);
    assert.equal(dialog.nodes.safe_exit?.success, true, `${quest.id} is missing a successful safe exit`);
    assert.equal(dialog.nodes.success?.success, true, `${quest.id} is missing a successful direct route`);
    for (const node of Object.values(dialog.nodes)) {
      assert.ok(node.text.length <= 360, `${quest.id}/${node.id || "node"} text is too long`);
      for (const option of node.options) {
        assert.ok(option.label.length <= 110, `${quest.id} option is too long`);
      }
    }
    bodies.add(JSON.stringify(dialog));
  }

  assert.equal(ids.size, rehearsalQuests.length);
  assert.equal(bodies.size, rehearsalQuests.length, "every eligible quest needs a distinct rehearsal");
});
