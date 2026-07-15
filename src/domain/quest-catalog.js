const STAT_TYPES = new Set(["charisma", "boldness", "networking"]);
const LEVEL_ENERGY = { 1: 10, 2: 25, 3: 50 };

export class QuestCatalogError extends Error {
  constructor(errors) {
    super(`Quest catalog is invalid: ${errors.join("; ")}`);
    this.name = "QuestCatalogError";
    this.errors = [...errors];
  }
}

export function createQuestCatalog(
  { quests, bosses, modifiers },
  { expectedQuestCount = 50, minimumBossCount = 1, minimumModifierCount = 1 } = {}
) {
  const errors = validateQuestCatalog(
    { quests, bosses, modifiers },
    { expectedQuestCount, minimumBossCount, minimumModifierCount }
  );
  if (errors.length) throw new QuestCatalogError(errors);

  const questById = new Map();
  const bossIds = new Set();
  for (const quest of quests) questById.set(quest.id, quest);
  for (const boss of bosses) {
    questById.set(boss.id, boss);
    bossIds.add(boss.id);
  }

  return Object.freeze({
    quests,
    bosses,
    modifiers,
    getQuest(id) {
      return questById.get(id) || null;
    },
    isBoss(id) {
      return bossIds.has(id);
    },
    has(id) {
      return questById.has(id);
    }
  });
}

export function validateQuestCatalog(
  { quests, bosses, modifiers },
  { expectedQuestCount = 50, minimumBossCount = 1, minimumModifierCount = 1 } = {}
) {
  const errors = [];
  if (!Array.isArray(quests)) errors.push("quests must be an array");
  if (!Array.isArray(bosses)) errors.push("bosses must be an array");
  if (!Array.isArray(modifiers)) errors.push("modifiers must be an array");
  if (errors.length) return errors;

  if (Number.isFinite(expectedQuestCount) && quests.length !== expectedQuestCount) {
    errors.push(`expected ${expectedQuestCount} quests, received ${quests.length}`);
  }
  if (bosses.length < minimumBossCount) errors.push(`expected at least ${minimumBossCount} boss quests`);
  if (modifiers.length < minimumModifierCount) errors.push(`expected at least ${minimumModifierCount} modifiers`);

  const ids = new Set();
  for (const quest of quests) validateQuestRecord(quest, { ids, errors, isBoss: false });
  for (const boss of bosses) validateQuestRecord(boss, { ids, errors, isBoss: true });

  const modifierIds = new Set();
  for (const modifier of modifiers) {
    const id = cleanString(modifier?.id);
    if (!id) errors.push("modifier id is required");
    else if (modifierIds.has(id)) errors.push(`duplicate modifier id: ${id}`);
    else modifierIds.add(id);
    if (!cleanString(modifier?.title)) errors.push(`modifier ${id || "<unknown>"} title is required`);
    if (!cleanString(modifier?.text)) errors.push(`modifier ${id || "<unknown>"} text is required`);
  }

  return errors;
}

function validateQuestRecord(quest, { ids, errors, isBoss }) {
  const id = cleanString(quest?.id);
  if (!id) errors.push("quest id is required");
  else if (ids.has(id)) errors.push(`duplicate quest id: ${id}`);
  else ids.add(id);

  const label = id || "<unknown>";
  const level = Number(quest?.level);
  if (![1, 2, 3].includes(level)) errors.push(`${label} level must be 1, 2, or 3`);
  if (!STAT_TYPES.has(quest?.statType)) errors.push(`${label} has invalid statType`);
  if (!cleanString(quest?.questText)) errors.push(`${label} questText is required`);
  if (!cleanString(quest?.lowPressureVariant)) errors.push(`${label} alternate route is required`);
  if (!cleanString(quest?.advancedVariant)) errors.push(`${label} advanced route is required`);

  if (isBoss) {
    if (!quest?.isBoss) errors.push(`${label} must set isBoss`);
    if (level !== 3) errors.push(`${label} boss level must be 3`);
    if (Number(quest?.energyCost) !== 50) errors.push(`${label} boss energyCost must be 50`);
    return;
  }

  if (quest?.isShadow) {
    if (Number(quest.energyCost) !== 0) errors.push(`${label} shadow energyCost must be 0`);
    if (Number(quest.rewardEnergy) <= 0) errors.push(`${label} shadow rewardEnergy must be positive`);
    return;
  }

  if (Number(quest?.energyCost) !== LEVEL_ENERGY[level]) {
    errors.push(`${label} energyCost must match level ${level}`);
  }
}

function cleanString(value) {
  return typeof value === "string" ? value.trim() : "";
}
