import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  BOSS_QUESTS,
  MODIFIERS,
  QUESTS,
  getGuideForQuest,
  getNpcDialogForQuest
} from "../src/data.js";

const projectRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const contentDirectory = resolve(projectRoot, "mobile/assets/content");

const outputFiles = {
  quests: resolve(contentDirectory, "quest_catalog.json"),
  guides: resolve(contentDirectory, "guide_catalog.json"),
  dialogs: resolve(contentDirectory, "dialog_catalog.json"),
  modifiers: resolve(contentDirectory, "modifier_catalog.json")
};

function mapQuest(quest) {
  const mapped = {
    id: quest.id,
    level: quest.level,
    statType: quest.statType,
    energyCost: quest.energyCost,
    category: quest.category,
    questText: quest.questText,
    alternateRoute: quest.lowPressureVariant,
    advancedRoute: quest.advancedVariant
  };

  if (quest.rewardEnergy) mapped.rewardEnergy = quest.rewardEnergy;
  if (quest.isShadow) mapped.isShadow = true;
  if (quest.isBoss) mapped.isBoss = true;
  return mapped;
}

function mapGuide(quest) {
  const guide = getGuideForQuest(quest);
  return {
    id: `guide_${quest.id}`,
    questId: quest.id,
    steps: guide.steps,
    phrases: guide.phrases,
    exitScript: guide.refusalScript,
    alternateRoute: guide.lowPressureVariant,
    advancedRoute: guide.advancedVariant
  };
}

function mapDialog(quest) {
  const template = getNpcDialogForQuest(quest);
  return {
    id: `dialog_${quest.id}`,
    questId: quest.id,
    startNodeId: template.startNodeId,
    nodes: Object.entries(template.nodes).map(([id, node]) => ({
      id,
      speaker: node.speaker,
      text: node.text,
      options: node.options.map((option) => ({
        label: option.label,
        nextNodeId: option.next
      })),
      ...(node.success ? { success: true } : {})
    }))
  };
}

function assertUniqueIds(records, label) {
  const ids = new Set();
  for (const record of records) {
    if (!ids.add(record.id)) {
      throw new Error(`Duplicate ${label} id: ${record.id}`);
    }
  }
}

export function buildMobileContent() {
  const allQuests = [...QUESTS, ...BOSS_QUESTS];
  const rehearsalQuests = [
    ...QUESTS.filter((quest) => !quest.isShadow && quest.level >= 2),
    ...BOSS_QUESTS
  ];

  const content = {
    quests: {
      schemaVersion: 1,
      quests: QUESTS.map(mapQuest),
      bosses: BOSS_QUESTS.map(mapQuest)
    },
    guides: {
      schemaVersion: 1,
      guides: allQuests.map(mapGuide)
    },
    dialogs: {
      schemaVersion: 1,
      dialogs: rehearsalQuests.map(mapDialog)
    },
    modifiers: {
      schemaVersion: 1,
      modifiers: MODIFIERS.map(({ id, title, text }) => ({ id, title, text }))
    }
  };

  assertUniqueIds([...content.quests.quests, ...content.quests.bosses], "quest");
  assertUniqueIds(content.guides.guides, "guide");
  assertUniqueIds(content.dialogs.dialogs, "dialog");
  assertUniqueIds(content.modifiers.modifiers, "modifier");
  return content;
}

function serialize(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

async function checkFile(path, expected) {
  const actual = await readFile(path, "utf8");
  if (actual !== serialize(expected)) {
    throw new Error(`Generated mobile content is stale: ${path}`);
  }
}

async function main() {
  const content = buildMobileContent();
  const checkOnly = process.argv.includes("--check");

  if (checkOnly) {
    await Promise.all([
      checkFile(outputFiles.quests, content.quests),
      checkFile(outputFiles.guides, content.guides),
      checkFile(outputFiles.dialogs, content.dialogs),
      checkFile(outputFiles.modifiers, content.modifiers)
    ]);
  } else {
    await Promise.all([
      writeFile(outputFiles.quests, serialize(content.quests)),
      writeFile(outputFiles.guides, serialize(content.guides)),
      writeFile(outputFiles.dialogs, serialize(content.dialogs)),
      writeFile(outputFiles.modifiers, serialize(content.modifiers))
    ]);
  }

  console.log(
    `${checkOnly ? "Verified" : "Exported"}: ` +
      `${content.quests.quests.length} quests, ` +
      `${content.quests.bosses.length} bosses, ` +
      `${content.guides.guides.length} guides, ` +
      `${content.dialogs.dialogs.length} dialogs, ` +
      `${content.modifiers.modifiers.length} modifiers`
  );
}

const isMain =
  process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  await main();
}
