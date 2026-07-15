export const STORAGE_KEY = "confidenceQuest.v1";
export const ENERGY_REGEN_MS = 10 * 60 * 1000;
export const XP_BY_LEVEL = {
  1: 40,
  2: 75,
  3: 140
};
export const EVENT_TYPES = new Set([
  "quest_started",
  "quest_completed",
  "quest_deferred",
  "quest_failed",
  "energy_spent",
  "reward_granted",
  "dice_rolled",
  "reflection_submitted",
  "boss_raid_participated",
  "guide_opened",
  "npc_training_completed"
]);
const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
const LEGACY_QUEST_ID_ALIASES = Object.freeze({
  boss_thanks_barista: "boss_group_entry",
  boss_recommendation: "boss_clear_position",
  boss_queue_warmth: "boss_direct_invite",
  boss_object_compliment: "boss_contact_exit",
  boss_coworking_intro: "boss_join_space"
});

const DEFAULT_STATS = {
  charisma: 0,
  boldness: 0,
  networking: 0
};

export function createDefaultState(now = new Date()) {
  const iso = now.toISOString();
  return {
    schemaVersion: 3,
    profile: {
      name: "Странник",
      createdAt: iso,
      pro: false,
      trialStartedAt: null
    },
    onboarding: {
      done: false,
      notMedicalAcknowledged: false,
      completedOfflineCount: 0
    },
    energy: {
      value: 100,
      lastUpdatedAt: iso
    },
    stats: { ...DEFAULT_STATS },
    daily: freshDaily(dailyQuestKey(now), utcDayKey(now), todayKey(now)),
    activeQuest: null,
    completedQuestIdsByDate: {},
    bossParticipants: {},
    prep: freshPrep(),
    reflections: [],
    events: [],
    sync: {
      lastSyncAt: null,
      pendingCount: 0,
      lastClientSequence: 0,
      lastSyncStatus: "idle",
      lastSyncError: "",
      acceptedCount: 0,
      duplicateCount: 0,
      lastErrorCount: 0
    }
  };
}

export function normalizeState(input, now = new Date()) {
  const base = createDefaultState(now);
  const state = {
    ...base,
    ...(input && typeof input === "object" ? input : {})
  };

  state.schemaVersion = 3;
  state.profile = { ...base.profile, ...(state.profile || {}) };
  state.onboarding = { ...base.onboarding, ...(state.onboarding || {}) };
  state.energy = { ...base.energy, ...(state.energy || {}) };
  state.stats = { ...DEFAULT_STATS, ...(state.stats || {}) };
  state.daily = { ...freshDaily(dailyQuestKey(now), utcDayKey(now), todayKey(now)), ...(state.daily || {}) };
  state.daily.localQuestIds = (state.daily.localQuestIds || []).map(canonicalQuestId);
  state.daily.bossId = canonicalQuestId(state.daily.bossId);
  delete state.cooldownUntil;
  delete state.daily.cooldownUntil;
  state.daily.dice = { ...freshDice(todayKey(now)), ...(state.daily.dice || {}) };
  state.daily.dice.questRerolls = migrateQuestKeyedRecord(state.daily.dice.questRerolls);
  state.activeQuest = state.activeQuest
    ? { ...state.activeQuest, questId: canonicalQuestId(state.activeQuest.questId) }
    : null;
  state.completedQuestIdsByDate = Object.fromEntries(
    Object.entries(state.completedQuestIdsByDate || {}).map(([date, ids]) => [
      date,
      Array.isArray(ids) ? ids.map(canonicalQuestId) : []
    ])
  );
  state.bossParticipants = Object.fromEntries(
    Object.entries(state.bossParticipants || {}).map(([date, participants]) => [
      date,
      migrateQuestKeyedRecord(participants)
    ])
  );
  state.prep = normalizePrep(state.prep);
  state.reflections = Array.isArray(state.reflections)
    ? state.reflections.map((item) => ({
      ...item,
      questId: canonicalQuestId(item.questId),
      isShadow: Boolean(item.isShadow || String(item.questId || "").startsWith("q_s_"))
    }))
    : [];
  state.events = Array.isArray(state.events) ? state.events.map(normalizeEvent) : [];
  state.sync = normalizeSync({ ...base.sync, ...(state.sync || {}) }, state.events);

  return updateEnergy(state, now);
}

export function todayKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function dailyQuestKey(date = new Date()) {
  const shifted = new Date(date);
  if (shifted.getHours() < 12) {
    shifted.setDate(shifted.getDate() - 1);
  }
  return todayKey(shifted);
}

export function utcDayKey(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

export function updateEnergy(state, now = new Date()) {
  const next = clone(state);
  const last = Date.parse(next.energy.lastUpdatedAt || now.toISOString());
  const elapsedTicks = Math.max(0, Math.floor((now.getTime() - last) / ENERGY_REGEN_MS));

  if (elapsedTicks > 0) {
    next.energy.value = clamp(next.energy.value + elapsedTicks, 0, 100);
    next.energy.lastUpdatedAt = new Date(last + elapsedTicks * ENERGY_REGEN_MS).toISOString();
  }

  return next;
}

export function refreshDailyQuests(state, quests, bosses, now = new Date()) {
  let next = ensureDiceDate(updateEnergy(state, now), now);
  const day = dailyQuestKey(now);
  const bossDay = utcDayKey(now);
  const localNeedsRefresh = next.daily.date !== day || next.daily.localQuestIds?.length !== 2;
  const bossNeedsRefresh = next.daily.bossDate !== bossDay || !next.daily.bossId;

  if (!localNeedsRefresh && !bossNeedsRefresh) {
    return next;
  }

  if (localNeedsRefresh) {
    const hasCompletedAnyQuest = next.events.some((event) => event.type === "quest_completed");
    const levelOne = quests.filter((quest) => !quest.isShadow && quest.level === 1);
    const levelTwo = quests.filter((quest) => !quest.isShadow && quest.level === 2);
    const levelThree = quests.filter((quest) => !quest.isShadow && quest.level === 3);
    const firstQuest = levelOne.find((quest) => quest.id === "q_c_001") || pickStable(levelOne, day, 0);
    const secondQuest = pickStable(levelTwo, day, 3);

    next.daily.date = day;
    next.daily.localQuestIds = hasCompletedAnyQuest
      ? [secondQuest.id, pickStable(levelThree, day, 5).id]
      : [firstQuest.id, secondQuest.id];
    next.completedQuestIdsByDate[day] = next.completedQuestIdsByDate[day] || [];
  }

  if (bossNeedsRefresh) {
    next.daily.bossDate = bossDay;
    next.daily.bossId = pickStable(bosses, bossDay, 7).id;
  }

  return next;
}

export function getEnergyStatus(state, now = new Date()) {
  const refreshed = updateEnergy(state, now);
  if (refreshed.energy.value <= 0) {
    return {
      key: "recluse",
      label: "Затворник",
      blocked: true,
      availableAt: null
    };
  }
  if (refreshed.energy.value < 20) {
    return {
      key: "recovering",
      label: "Нужна энергия",
      blocked: true,
      availableAt: null
    };
  }
  return {
    key: "ready",
    label: "Готов",
    blocked: false,
    availableAt: null
  };
}

export function canStartQuest(state, quest, now = new Date()) {
  if (!quest) return { ok: false, reason: "Квест не найден." };
  if (quest.isShadow) return { ok: true, reason: "" };

  if (state.energy.value < quest.energyCost) return { ok: false, reason: "Недостаточно энергии." };
  if (state.energy.value < 20) return { ok: false, reason: "Обычные квесты откроются с 20% энергии." };

  return { ok: true, reason: "" };
}

export function startQuest(state, quest, now = new Date()) {
  const next = updateEnergy(state, now);
  if (next.activeQuest?.questId === quest.id) {
    throw new Error("Этот квест уже начат.");
  }
  if (next.activeQuest) {
    throw new Error("Сначала заверши или отложи текущий квест.");
  }
  const allowed = canStartQuest(next, quest, now);
  if (!allowed.ok) throw new Error(allowed.reason);
  next.prep = normalizePrep(next.prep);

  next.activeQuest = {
    questId: quest.id,
    startedAt: now.toISOString(),
    npcTrained: Boolean(next.prep.npcTrainedByQuestId[quest.id]),
    modifier: next.prep.modifiersByQuestId[quest.id] || null
  };
  appendEvent(next, {
    type: "quest_started",
    questId: quest.id,
    payload: {
      level: quest.level,
      statType: quest.statType,
      isShadow: Boolean(quest.isShadow)
    }
  }, now);
  return next;
}

export function completeNpcTraining(state, quest, now = new Date()) {
  const next = clone(state);
  next.prep = normalizePrep(next.prep);
  next.prep.npcTrainedByQuestId[quest.id] = true;

  if (next.activeQuest?.questId === quest.id) {
    next.activeQuest = {
      ...next.activeQuest,
      npcTrained: true
    };
  }
  appendEvent(next, {
    type: "npc_training_completed",
    questId: quest.id,
    payload: {
      dialogId: `npc_${quest.category || "default"}`,
      xpBuffPercent: 10
    }
  }, now);
  return next;
}

export function openQuestGuide(state, quest, guide, now = new Date()) {
  const next = clone(state);
  appendEvent(next, {
    type: "guide_opened",
    questId: quest.id,
    payload: {
      guideId: guide?.id || `guide_${quest.id}`,
      curated: Boolean(guide?.curated)
    }
  }, now);
  return next;
}

export function deferQuest(state, quest, now = new Date()) {
  const next = updateEnergy(state, now);
  if (next.activeQuest?.questId !== quest.id) {
    throw new Error("Сначала начни квест.");
  }
  next.prep = normalizePrep(next.prep);
  const startedAt = Date.parse(next.activeQuest.startedAt);
  const attemptDurationSeconds = Number.isFinite(startedAt)
    ? Math.max(0, Math.floor((now.getTime() - startedAt) / 1000))
    : 0;
  const preparedNpc = Boolean(next.activeQuest.npcTrained || next.prep.npcTrainedByQuestId[quest.id]);
  const modifierId = next.activeQuest.modifier?.id || next.prep.modifiersByQuestId[quest.id]?.id || null;
  next.activeQuest = null;
  appendEvent(next, {
    type: "quest_deferred",
    questId: quest.id,
    payload: {
      deferReason: "not_now",
      attemptDurationSeconds,
      hadNpcTraining: preparedNpc,
      modifierId,
      energyDelta: 0,
      energyAfter: next.energy.value,
    }
  }, now);
  return next;
}

export function completeQuest(state, quest, reflection, options = {}, now = new Date()) {
  const next = updateEnergy(state, now);
  const day = dailyQuestKey(now);
  const bossDay = utcDayKey(now);
  const isBoss = Boolean(quest.isBoss);
  const variant = options.variant || "normal";
  const skipReflection = Boolean(options.skipReflection);

  if (isBoss && next.bossParticipants[bossDay]?.[quest.id]) {
    throw new Error("Daily Drop уже закрыт сегодня.");
  }
  if (next.activeQuest?.questId !== quest.id) {
    throw new Error("Сначала начни квест.");
  }

  const allowed = canStartQuest(next, quest, now);
  if (!allowed.ok) throw new Error(allowed.reason);
  next.prep = normalizePrep(next.prep);

  const beforeEnergy = next.energy.value;
  if (quest.isShadow) {
    next.energy.value = clamp(next.energy.value + (quest.rewardEnergy || 5), 0, 100);
  } else {
    next.energy.value = clamp(next.energy.value - quest.energyCost, 0, 100);
  }
  next.energy.lastUpdatedAt = now.toISOString();

  const npcTrained = Boolean(next.activeQuest?.npcTrained || next.prep.npcTrainedByQuestId[quest.id]);
  const xpGained = calculateRewardXp(quest, { npcTrained });
  next.stats[quest.statType] = Math.max(0, (next.stats[quest.statType] || 0) + xpGained);

  const reflectionRecord = {
    id: createId("reflection"),
    questId: quest.id,
    questText: quest.questText,
    statType: quest.statType,
    isBoss,
    isShadow: Boolean(quest.isShadow),
    variant,
    reflectionSkipped: skipReflection,
    fear: skipReflection ? null : Number(reflection?.fear || 5),
    mood: skipReflection ? null : Number(reflection?.mood || 6),
    repeat: skipReflection ? null : Boolean(reflection?.repeat),
    note: skipReflection ? "" : String(reflection?.note || "").trim(),
    xpGained,
    energyDelta: next.energy.value - beforeEnergy,
    createdAt: now.toISOString()
  };

  next.reflections.unshift(reflectionRecord);
  next.completedQuestIdsByDate[day] = Array.from(new Set([...(next.completedQuestIdsByDate[day] || []), quest.id]));

  if (isBoss) {
    next.bossParticipants[bossDay] = {
      ...(next.bossParticipants[bossDay] || {}),
      [quest.id]: true
    };
  }

  appendEvent(next, {
    type: "quest_completed",
    questId: quest.id,
    payload: {
      statType: quest.statType,
      xpDelta: xpGained,
      energyDelta: next.energy.value - beforeEnergy,
      energyAfter: next.energy.value,
      reflectionId: reflectionRecord.id,
      variant,
      isBoss,
      npcTrained
    }
  }, now);

  if (!skipReflection) {
    appendEvent(next, {
      type: "reflection_submitted",
      questId: quest.id,
      payload: {
        reflectionId: reflectionRecord.id,
        fearScore: reflectionRecord.fear,
        feelAfterScore: reflectionRecord.mood,
        wantRepeat: reflectionRecord.repeat
      }
    }, now);
  }

  if (isBoss) {
    appendEvent(next, {
      type: "boss_raid_participated",
      questId: quest.id,
      payload: {
        bossQuestId: quest.id,
        variant
      }
    }, now);
  }

  if (!next.profile.trialStartedAt && !quest.isShadow) {
    next.profile.trialStartedAt = now.toISOString();
  }

  next.activeQuest = null;
  clearQuestPrep(next, quest.id);
  if (!quest.isShadow) {
    next.onboarding.done = true;
    next.onboarding.completedOfflineCount = Math.max(
      Number(next.onboarding.completedOfflineCount || 0),
      countOfflineCompletions(next)
    );
  }
  return next;
}

export function calculateRewardXp(quest, options = {}) {
  const base = XP_BY_LEVEL[quest.level] || 40;
  let xp = quest.isShadow ? base * 0.5 : base;
  if (quest.isBoss) xp *= 2;
  if (options.npcTrained) xp *= 1.1;
  return Math.round(xp);
}

export function rollModifier(state, questId, modifiers, now = new Date()) {
  const next = ensureDiceDate(clone(state), now);
  next.prep = normalizePrep(next.prep);
  const dice = next.daily.dice;
  const pro = Boolean(next.profile.pro);
  const questRerolls = dice.questRerolls[questId] || 0;

  if (pro) {
    if (dice.proRollsUsed < 3) {
      dice.proRollsUsed += 1;
    } else if (questRerolls < 1) {
      dice.questRerolls[questId] = questRerolls + 1;
    } else {
      throw new Error("PRO-лимит кубика на сегодня исчерпан.");
    }
  } else if (!dice.freeRollUsed) {
    dice.freeRollUsed = true;
  } else {
    throw new Error("Бесплатный бросок уже использован сегодня.");
  }

  const modifier = modifiers[Math.abs(hash(`${questId}:${now.toISOString()}:${dice.proRollsUsed}:${dice.freeRollUsed}`)) % modifiers.length];
  if (next.activeQuest?.questId === questId) {
    next.activeQuest = {
      ...next.activeQuest,
      modifier
    };
  } else {
    next.prep.modifiersByQuestId[questId] = modifier;
  }

  appendEvent(next, {
    type: "dice_rolled",
    questId,
    payload: {
      modifierId: modifier.id,
      isPro: pro
    }
  }, now);

  return { state: next, modifier };
}

export function getDiceAllowance(state, questId, now = new Date()) {
  const next = ensureDiceDate(clone(state), now);
  const dice = next.daily.dice;
  if (next.profile.pro) {
    const questRerolls = dice.questRerolls[questId] || 0;
    return {
      label: `${Math.max(0, 3 - dice.proRollsUsed)} / 3 сегодня`,
      canRoll: dice.proRollsUsed < 3 || questRerolls < 1,
      rerollAvailable: questRerolls < 1
    };
  }
  return {
    label: dice.freeRollUsed ? "0 / 1 сегодня" : "1 / 1 сегодня",
    canRoll: !dice.freeRollUsed,
    rerollAvailable: false
  };
}

export function getTotalXp(state) {
  return Object.values(state.stats || {}).reduce((sum, value) => sum + Number(value || 0), 0);
}

export function getPlayerLevel(state) {
  return Math.max(1, Math.floor(getTotalXp(state) / 250) + 1);
}

export function getLevelProgress(state) {
  return (getTotalXp(state) % 250) / 250;
}

export function getStatShare(state, statType) {
  const total = Math.max(1, getTotalXp(state));
  return Math.round(((state.stats?.[statType] || 0) / total) * 100);
}

export function getBossParticipants(state, bossQuest, now = new Date()) {
  const day = utcDayKey(now);
  const dayHash = Math.abs(hash(`${day}:${bossQuest.id}`));
  const localBump = state.bossParticipants[day]?.[bossQuest.id] ? 1 : 0;
  return bossQuest.participantsSeed + (dayHash % 900) + localBump;
}

export function setPro(state, value) {
  const next = clone(state);
  next.profile.pro = Boolean(value);
  return next;
}

export function acknowledgeBoundaries(state) {
  const next = clone(state);
  next.onboarding.notMedicalAcknowledged = true;
  return next;
}

export function clearAllProgress(now = new Date()) {
  return createDefaultState(now);
}

export function syncPendingEvents(state, quests = [], bosses = [], now = new Date()) {
  const next = clone(state);
  next.events = Array.isArray(next.events) ? next.events.map(normalizeEvent) : [];
  next.sync = normalizeSync(next.sync || {}, next.events);

  const questMap = buildQuestMap(quests, bosses);
  const acceptedIds = new Set();
  const priorEventIndex = new Map();
  const orderedEvents = [...next.events].sort(compareEventsForSync);
  let acceptedCount = 0;
  let duplicateCount = 0;
  let errorCount = 0;
  let lastError = "";

  for (const event of orderedEvents) {
    if (event.synced) {
      if (!acceptedIds.has(event.id)) {
        acceptedIds.add(event.id);
        indexAcceptedEvent(priorEventIndex, event);
      }
      continue;
    }

    if (acceptedIds.has(event.id)) {
      event.synced = true;
      event.syncStatus = "deduplicated";
      event.syncError = "";
      event.syncedAt = now.toISOString();
      duplicateCount += 1;
      continue;
    }

    const validation = validateEventForSync(event, priorEventIndex, questMap);
    if (!validation.ok) {
      event.synced = false;
      event.syncStatus = "error";
      event.syncError = validation.reason;
      lastError = validation.reason;
      errorCount += 1;
      continue;
    }

    event.synced = true;
    event.syncStatus = "synced";
    event.syncError = "";
    event.syncedAt = now.toISOString();
    acceptedIds.add(event.id);
    indexAcceptedEvent(priorEventIndex, event);
    acceptedCount += 1;
  }

  next.sync.lastSyncAt = now.toISOString();
  next.sync.pendingCount = next.events.filter((event) => !event.synced).length;
  next.sync.lastSyncStatus = errorCount ? "partial" : "ok";
  next.sync.lastSyncError = errorCount ? lastError : "";
  next.sync.acceptedCount = Number(next.sync.acceptedCount || 0) + acceptedCount;
  next.sync.duplicateCount = Number(next.sync.duplicateCount || 0) + duplicateCount;
  next.sync.lastErrorCount = errorCount;
  next.sync.lastClientSequence = Math.max(next.sync.lastClientSequence || 0, ...next.events.map((event) => Number(event.clientSequence || 0)));
  return next;
}

function freshDaily(date, bossDate = null, diceDate = date) {
  return {
    date,
    localQuestIds: [],
    bossId: null,
    bossDate,
    dice: freshDice(diceDate)
  };
}

function freshDice(date) {
  return {
    date,
    freeRollUsed: false,
    proRollsUsed: 0,
    questRerolls: {}
  };
}

function freshPrep() {
  return {
    npcTrainedByQuestId: {},
    modifiersByQuestId: {}
  };
}

function normalizePrep(prep) {
  return {
    ...freshPrep(),
    ...(prep || {}),
    npcTrainedByQuestId: migrateQuestKeyedRecord(prep?.npcTrainedByQuestId),
    modifiersByQuestId: migrateQuestKeyedRecord(prep?.modifiersByQuestId)
  };
}

function clearQuestPrep(state, questId) {
  state.prep = normalizePrep(state.prep);
  delete state.prep.npcTrainedByQuestId[questId];
  delete state.prep.modifiersByQuestId[questId];
}

function ensureDiceDate(state, now) {
  const day = todayKey(now);
  if (state.daily.dice?.date !== day) {
    state.daily.dice = freshDice(day);
  }
  return state;
}

function appendEvent(state, event, now) {
  const id = event.id || createId("event");
  if (state.events.some((existing) => existing.id === id)) return state;
  state.sync = normalizeSync(state.sync || {}, state.events);
  const clientSequence = Number(event.clientSequence || state.sync.lastClientSequence + 1);
  const metadata = { ...(event.payload || {}), ...(event.metadata || {}) };
  state.events.push({
    id,
    type: event.type,
    eventType: event.type,
    questId: event.questId || null,
    modifierId: event.modifierId || metadata.modifierId || null,
    xpDelta: Number(event.xpDelta ?? metadata.xpDelta ?? 0),
    energyDelta: Number(event.energyDelta ?? metadata.energyDelta ?? 0),
    payload: event.payload || {},
    metadata,
    clientSequence,
    synced: false,
    syncStatus: "pending",
    syncError: "",
    createdAt: now.toISOString()
  });
  state.sync.lastClientSequence = clientSequence;
  state.sync.pendingCount = state.events.filter((item) => !item.synced).length;
  return state;
}

function normalizeEvent(event, index = 0) {
  if (!event || typeof event !== "object") return event;
  const next = {
    ...event,
    questId: canonicalQuestId(event.questId),
    id: event.id || createId("event"),
    payload: { ...(event.payload || {}) },
    metadata: { ...(event.metadata || event.payload || {}) },
    synced: Boolean(event.synced),
    syncStatus: event.syncStatus || (event.synced ? "synced" : "pending"),
    syncError: event.syncError || "",
    createdAt: event.createdAt || new Date().toISOString()
  };
  if (next.type === "quest_abandoned") {
    next.type = "quest_failed";
    next.payload.failReason = next.payload.failReason || "escape";
  }
  if (next.type === "modifier_rolled") {
    next.type = "dice_rolled";
    next.payload.isPro = Boolean(next.payload.isPro ?? next.payload.pro);
    delete next.payload.pro;
  }
  next.eventType = next.eventType || next.type;
  next.metadata = { ...next.payload, ...next.metadata };
  if (next.payload.bossQuestId) next.payload.bossQuestId = canonicalQuestId(next.payload.bossQuestId);
  if (next.metadata.bossQuestId) next.metadata.bossQuestId = canonicalQuestId(next.metadata.bossQuestId);
  next.modifierId = next.modifierId || next.metadata.modifierId || null;
  next.xpDelta = Number(next.xpDelta ?? next.metadata.xpDelta ?? 0);
  next.energyDelta = Number(next.energyDelta ?? next.metadata.energyDelta ?? 0);
  next.clientSequence = Number(next.clientSequence || index + 1);
  return next;
}

function canonicalQuestId(id) {
  return LEGACY_QUEST_ID_ALIASES[id] || id;
}

function migrateQuestKeyedRecord(record) {
  return Object.fromEntries(
    Object.entries(record || {}).map(([questId, value]) => [canonicalQuestId(questId), value])
  );
}

function normalizeSync(sync, events) {
  const lastClientSequence = Math.max(
    Number(sync?.lastClientSequence || 0),
    ...events.map((event) => Number(event?.clientSequence || 0))
  );
  return {
    lastSyncAt: sync?.lastSyncAt || null,
    pendingCount: events.filter((event) => !event.synced).length,
    lastClientSequence,
    lastSyncStatus: sync?.lastSyncStatus || "idle",
    lastSyncError: sync?.lastSyncError || "",
    acceptedCount: Number(sync?.acceptedCount || 0),
    duplicateCount: Number(sync?.duplicateCount || 0),
    lastErrorCount: Number(sync?.lastErrorCount || 0)
  };
}

function buildQuestMap(quests, bosses) {
  const map = new Map();
  for (const quest of quests) {
    map.set(quest.id, { quest, isBoss: false });
  }
  for (const boss of bosses) {
    map.set(boss.id, { quest: boss, isBoss: true });
  }
  return map;
}

function validateEventForSync(event, priorEventIndex, questMap) {
  if (!event.id) return { ok: false, reason: "event id is required" };
  if (!EVENT_TYPES.has(event.type)) return { ok: false, reason: `unknown event type: ${event.type}` };
  if (event.questId && !questMap.has(event.questId)) return { ok: false, reason: `unknown quest id: ${event.questId}` };

  if (event.type === "quest_completed") {
    const record = questMap.get(event.questId);
    const started = hasPriorQuestEvent(priorEventIndex, event, "quest_started");
    if (!started) return { ok: false, reason: "quest_completed requires quest_started in the last 24h" };

    if (event.metadata?.isBoss !== undefined && Boolean(event.metadata.isBoss) !== record.isBoss) {
      return { ok: false, reason: `isBoss mismatch for ${event.questId}` };
    }

    const npcTrained = hasPriorQuestEvent(priorEventIndex, event, "npc_training_completed");
    if (event.metadata?.npcTrained && !npcTrained) {
      return { ok: false, reason: "npcTrained requires npc_training_completed in the last 24h" };
    }

    const expectedXp = calculateRewardXp(record.quest, { npcTrained });
    if (Number(event.xpDelta) !== expectedXp) {
      return { ok: false, reason: `xp_delta mismatch for ${event.questId}` };
    }

    const energyValidation = validateEnergyTransition(event, record.quest, "complete");
    if (!energyValidation.ok) return energyValidation;
  }

  if (event.type === "quest_failed") {
    const record = questMap.get(event.questId);
    const started = hasPriorQuestEvent(priorEventIndex, event, "quest_started");
    if (!started) return { ok: false, reason: "quest_failed requires quest_started" };
    const energyValidation = validateEnergyTransition(event, record.quest, "fail");
    if (!energyValidation.ok) return energyValidation;
  }

  if (event.type === "quest_deferred") {
    const record = questMap.get(event.questId);
    const started = findPriorQuestEvent(priorEventIndex, event, "quest_started");
    if (!started) return { ok: false, reason: "quest_deferred requires quest_started" };
    if (event.metadata?.deferReason !== "not_now") {
      return { ok: false, reason: "quest_deferred requires defer_reason: not_now" };
    }
    const expectedDuration = Math.floor((Date.parse(event.createdAt) - Date.parse(started.createdAt)) / 1000);
    if (Number(event.metadata?.attemptDurationSeconds) !== expectedDuration) {
      return { ok: false, reason: "attempt_duration_seconds mismatch" };
    }
    const energyValidation = validateEnergyTransition(event, record.quest, "defer");
    if (!energyValidation.ok) return energyValidation;
  }

  return { ok: true, reason: "" };
}

function hasPriorQuestEvent(priorEventIndex, event, eventType) {
  return Boolean(findPriorQuestEvent(priorEventIndex, event, eventType));
}

function findPriorQuestEvent(priorEventIndex, event, eventType) {
  const eventTime = Date.parse(event.createdAt);
  if (!Number.isFinite(eventTime)) return null;
  const candidate = priorEventIndex.get(priorEventKey(event.questId, eventType));
  if (!candidate) return null;
  const candidateTime = Date.parse(candidate.createdAt);
  if (!Number.isFinite(candidateTime) || candidateTime > eventTime || eventTime - candidateTime > TWENTY_FOUR_HOURS_MS) {
    return null;
  }
  return candidate;
}

function indexAcceptedEvent(priorEventIndex, event) {
  if (!event.questId || !event.type) return;
  priorEventIndex.set(priorEventKey(event.questId, event.type), event);
}

function priorEventKey(questId, eventType) {
  return `${questId || ""}\u0000${eventType || ""}`;
}

function compareEventsForSync(left, right) {
  const leftTime = Date.parse(left.createdAt);
  const rightTime = Date.parse(right.createdAt);
  const safeLeftTime = Number.isFinite(leftTime) ? leftTime : Number.MAX_SAFE_INTEGER;
  const safeRightTime = Number.isFinite(rightTime) ? rightTime : Number.MAX_SAFE_INTEGER;
  if (safeLeftTime !== safeRightTime) return safeLeftTime - safeRightTime;
  const sequenceDelta = Number(left.clientSequence || 0) - Number(right.clientSequence || 0);
  if (sequenceDelta !== 0) return sequenceDelta;
  return String(left.id || "").localeCompare(String(right.id || ""));
}

function validateEnergyTransition(event, quest, mode) {
  const energyAfter = Number(event.metadata?.energyAfter);
  const energyDelta = Number(event.energyDelta);
  const energyBefore = energyAfter - energyDelta;
  if (![energyBefore, energyAfter, energyDelta].every(Number.isFinite)) {
    return { ok: false, reason: "energy transition requires finite values" };
  }
  if (energyBefore < 0 || energyBefore > 100 || energyAfter < 0 || energyAfter > 100) {
    return { ok: false, reason: "energy must stay between 0 and 100" };
  }

  const expectedAfter = mode === "defer"
    ? energyBefore
    : mode === "fail"
      ? clamp(energyBefore - (quest.isShadow ? 0 : quest.energyCost * 2), 0, 100)
      : quest.isShadow
        ? clamp(energyBefore + (quest.rewardEnergy || 5), 0, 100)
        : clamp(energyBefore - quest.energyCost, 0, 100);
  if (energyAfter !== expectedAfter || energyDelta !== expectedAfter - energyBefore) {
    return { ok: false, reason: `energy_delta mismatch for ${event.questId}` };
  }
  return { ok: true, reason: "" };
}

function countOfflineCompletions(state) {
  return state.reflections.filter((item) => !item.isBoss && !item.isShadow).length;
}

function pickStable(items, seed, salt) {
  if (!items.length) throw new Error("No items to pick from.");
  return items[Math.abs(hash(`${seed}:${salt}`)) % items.length];
}

function hash(input) {
  let value = 2166136261;
  for (let index = 0; index < input.length; index += 1) {
    value ^= input.charCodeAt(index);
    value = Math.imul(value, 16777619);
  }
  return value | 0;
}

function createId(prefix) {
  const randomPart = globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2);
  return `${prefix}_${randomPart}`;
}

function clone(value) {
  return typeof structuredClone === "function"
    ? structuredClone(value)
    : JSON.parse(JSON.stringify(value));
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, Math.round(value)));
}
