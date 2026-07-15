import assert from "node:assert/strict";
import { BOSS_QUESTS, MODIFIERS, QUESTS, getGuideForQuest, getNpcDialogForQuest } from "../src/data.js";
import {
  calculateRewardXp,
  clearAllProgress,
  completeNpcTraining,
  completeQuest,
  deferQuest,
  normalizeState,
  openQuestGuide,
  dailyQuestKey,
  refreshDailyQuests,
  rollModifier,
  setPro,
  startQuest,
  syncPendingEvents,
  todayKey,
  utcDayKey,
  updateEnergy
} from "../src/game.js";

const now = new Date("2026-07-08T12:00:00.000Z");

function quest(id) {
  return QUESTS.find((item) => item.id === id) || BOSS_QUESTS.find((item) => item.id === id);
}

function fresh() {
  return refreshDailyQuests(clearAllProgress(now), QUESTS, BOSS_QUESTS, now);
}

function countBy(items, key) {
  return items.reduce((acc, item) => {
    acc[item[key]] = (acc[item[key]] || 0) + 1;
    return acc;
  }, {});
}

{
  const localMorning = new Date(2026, 6, 9, 11, 59);
  const localNoon = new Date(2026, 6, 9, 12, 0);
  assert.equal(dailyQuestKey(localMorning), todayKey(new Date(2026, 6, 8, 12, 0)), "daily quests should not refresh before 12:00 local");
  assert.equal(dailyQuestKey(localNoon), todayKey(localNoon), "daily quests should refresh at 12:00 local");

  let state = refreshDailyQuests(clearAllProgress(new Date(2026, 6, 8, 13, 0)), QUESTS, BOSS_QUESTS, new Date(2026, 6, 8, 13, 0));
  const beforeNoonQuestIds = state.daily.localQuestIds.join(",");
  state = refreshDailyQuests(state, QUESTS, BOSS_QUESTS, localMorning);
  assert.equal(state.daily.date, dailyQuestKey(localMorning), "daily date should use the active noon-based window");
  assert.equal(state.daily.localQuestIds.join(","), beforeNoonQuestIds, "daily quests should remain stable until noon");
  state = refreshDailyQuests(state, QUESTS, BOSS_QUESTS, new Date(2026, 6, 9, 12, 1));
  assert.equal(state.daily.date, todayKey(new Date(2026, 6, 9, 12, 1)), "daily quests should switch after noon");
}

{
  const beforeUtcMidnight = new Date("2026-07-09T20:55:00.000Z");
  const afterUtcMidnight = new Date("2026-07-10T00:05:00.000Z");
  let state = refreshDailyQuests(clearAllProgress(beforeUtcMidnight), QUESTS, BOSS_QUESTS, beforeUtcMidnight);
  const localDailyDate = state.daily.date;
  state = refreshDailyQuests(state, QUESTS, BOSS_QUESTS, afterUtcMidnight);
  assert.equal(state.daily.date, localDailyDate, "local quests should stay stable before the local noon reset");
  assert.equal(state.daily.bossDate, utcDayKey(afterUtcMidnight), "boss should refresh independently at UTC midnight");
}

{
  const stateWithHistory = clearAllProgress(now);
  stateWithHistory.events.push({ type: "quest_completed" });
  const state = refreshDailyQuests(stateWithHistory, QUESTS, BOSS_QUESTS, now);
  assert.deepEqual(
    state.daily.localQuestIds.map((id) => quest(id).level),
    [2, 3],
    "after the first completion backup runs should use the harder level 2 and 3 pools"
  );
}

{
  assert.equal(QUESTS.length, 50, "quest pool should contain 50 quests");
  assert.equal(QUESTS.filter((item) => item.isShadow).length, 13, "quest pool should contain 13 shadow quests");
  assert.deepEqual(countBy(QUESTS, "level"), { 1: 18, 2: 22, 3: 10 }, "quest levels should match PRD distribution");
  assert.deepEqual(
    countBy(QUESTS.filter((item) => !item.isShadow), "statType"),
    { charisma: 15, boldness: 12, networking: 10 },
    "offline stat distribution should match PRD appendix"
  );

  const removedIds = new Set(["q_b_001", "q_b_003", "q_b_005", "q_b_006", "q_b_007", "q_b_008", "q_b_012", "q_b_015", "q_c_010", "q_c_011", "q_b_011"]);
  assert.deepEqual(QUESTS.filter((item) => removedIds.has(item.id)).map((item) => item.id), [], "deleted v2 IDs must not be reused");

  for (const item of QUESTS.filter((questItem) => !questItem.isShadow)) {
    assert.equal(item.energyCost, { 1: 10, 2: 25, 3: 50 }[item.level], `${item.id} energy should match its level`);
  }

  const bannedFragments = ["скидку без повода", "номер телефона", "сними", "селфи с незнакомцем", "имитируй акцент"];
  for (const item of QUESTS) {
    const text = `${item.questText} ${item.lowPressureVariant} ${item.advancedVariant}`.toLowerCase();
    assert.equal(bannedFragments.some((fragment) => text.includes(fragment)), false, `unsafe fragment in ${item.id}`);
  }

  const bossBannedFragments = [
    "пенис",
    "секс",
    "барист",
    "кассир",
    "продав",
    "курьер",
    "официант",
    "сядь рядом",
    "можно ли сесть вместе",
    "скрытую съёмку",
    "без согласия"
  ];
  for (const item of BOSS_QUESTS) {
    const text = `${item.questText} ${item.lowPressureVariant} ${item.advancedVariant}`.toLowerCase();
    assert.equal(item.isBoss, true, `${item.id} must stay a boss challenge`);
    assert.equal(item.level, 3, `${item.id} must stay level 3`);
    assert.ok(item.lowPressureVariant.trim(), `${item.id} must have another route`);
    assert.ok(item.advancedVariant.trim(), `${item.id} must have an advanced route`);
    assert.equal(
      bossBannedFragments.some((fragment) => text.includes(fragment)),
      false,
      `boss challenge must not target captive workers or use sexual shock: ${item.id}`
    );
  }


  const hardPoolBannedFragments = [
    "барист",
    "кассир",
    "продав",
    "курьер",
    "официант",
    "сядь рядом",
    "можно ли сесть вместе"
  ];
  for (const item of QUESTS.filter((questItem) => !questItem.isShadow && questItem.level >= 2)) {
    const text = `${item.questText} ${item.lowPressureVariant} ${item.advancedVariant}`.toLowerCase();
    assert.equal(
      hardPoolBannedFragments.some((fragment) => text.includes(fragment)),
      false,
      `hard backup pool must put social risk on the player: ${item.id}`
    );
  }
}

{
  const state = fresh();
  state.energy.value = 10;
  state.energy.lastUpdatedAt = now.toISOString();
  const later = new Date(now.getTime() + 30 * 60 * 1000);
  const updated = updateEnergy(state, later);
  assert.equal(updated.energy.value, 13, "energy should regenerate 1% every 10 minutes");
}

{
  let state = fresh();
  state.energy.value = 30;
  const selected = quest("q_b_004");
  state = completeNpcTraining(state, selected, now);
  state = rollModifier(state, selected.id, MODIFIERS, now).state;
  state = startQuest(state, selected, now);
  state = deferQuest(state, selected, new Date(now.getTime() + 65_000));
  const deferred = state.events.at(-1);
  assert.equal(state.energy.value, 30, "deferring should not punish the user with an energy charge");
  assert.equal(state.activeQuest, null, "deferring should release the active attempt");
  assert.equal(deferred.type, "quest_deferred", "deferring should use a distinct analytics event");
  assert.equal(deferred.payload.deferReason, "not_now", "deferral should record a neutral reason");
  assert.equal(deferred.payload.attemptDurationSeconds, 65, "deferral should preserve attempt duration for quest quality analysis");
  assert.equal(state.prep.npcTrainedByQuestId[selected.id], true, "deferring should preserve completed NPC preparation");
  assert.ok(state.prep.modifiersByQuestId[selected.id], "deferring should preserve the rolled modifier");
  state = startQuest(state, selected, new Date(now.getTime() + 66_000));
  assert.equal(state.activeQuest.questId, selected.id, "a deferred quest should be immediately restartable");
}

{
  const legacy = fresh();
  legacy.schemaVersion = 2;
  legacy.cooldownUntil = new Date(now.getTime() + 60 * 60 * 1000).toISOString();
  legacy.daily.cooldownUntil = legacy.cooldownUntil;
  const migrated = normalizeState(legacy, now);
  assert.equal(migrated.schemaVersion, 3, "legacy state should migrate to the defer-policy schema");
  assert.equal("cooldownUntil" in migrated, false, "migration should remove the punitive top-level cooldown");
  assert.equal("cooldownUntil" in migrated.daily, false, "migration should remove the legacy daily cooldown");
  assert.doesNotThrow(() => startQuest(migrated, quest("q_c_001"), now), "legacy cooldown must not block a quest after migration");
}

{
  const legacy = fresh();
  legacy.daily.bossId = "boss_thanks_barista";
  legacy.activeQuest = { questId: "boss_recommendation", startedAt: now.toISOString() };
  legacy.prep.npcTrainedByQuestId.boss_queue_warmth = true;
  legacy.daily.dice.questRerolls.boss_object_compliment = 1;
  legacy.completedQuestIdsByDate[legacy.daily.date] = ["boss_coworking_intro"];
  legacy.events.push({
    id: "legacy_boss_event",
    type: "boss_raid_participated",
    questId: "boss_thanks_barista",
    payload: { bossQuestId: "boss_thanks_barista" },
    synced: false,
    createdAt: now.toISOString()
  });

  const migrated = normalizeState(legacy, now);
  assert.equal(migrated.daily.bossId, "boss_group_entry");
  assert.equal(migrated.activeQuest.questId, "boss_clear_position");
  assert.equal(migrated.prep.npcTrainedByQuestId.boss_direct_invite, true);
  assert.equal(migrated.daily.dice.questRerolls.boss_contact_exit, 1);
  assert.deepEqual(migrated.completedQuestIdsByDate[legacy.daily.date], ["boss_join_space"]);
  assert.equal(migrated.events.at(-1).questId, "boss_group_entry");
  assert.equal(migrated.events.at(-1).payload.bossQuestId, "boss_group_entry");
}

{
  let state = fresh();
  state = startQuest(state, quest("q_c_001"), now);
  assert.throws(
    () => startQuest(state, quest("q_b_004"), new Date(now.getTime() + 1000)),
    /текущий квест/,
    "starting another quest must not overwrite the active attempt"
  );
}

{
  let state = fresh();
  state.energy.value = 0;
  const shadow = quest("q_s_001");
  state = startQuest(state, shadow, now);
  state = completeQuest(state, shadow, { fear: 2, mood: 6, repeat: true }, {}, now);
  assert.equal(state.energy.value, 5, "shadow quest should restore 5 energy");
  assert.equal(state.stats.charisma, calculateRewardXp(shadow), "shadow quest should grant half XP");
  assert.equal(state.events.at(-1).type, "reflection_submitted", "submitted reflection should be logged separately");
}

{
  let state = fresh();
  state.energy.value = 0;
  const shadow = quest("q_s_001");
  state = startQuest(state, shadow, now);
  state = deferQuest(state, shadow, new Date(now.getTime() + 10_000));
  assert.equal(state.energy.value, 0, "deferring a shadow quest should not change energy");
  assert.equal(state.activeQuest, null, "shadow quest should not trap the active attempt");
  assert.equal(state.events.at(-1).type, "quest_deferred", "shadow deferral should use the same neutral event");
  assert.doesNotThrow(() => startQuest(state, shadow, new Date(now.getTime() + 11_000)), "shadow quest should be immediately restartable");
}

{
  const boss = BOSS_QUESTS[0];
  const normalXp = calculateRewardXp(boss);
  const lowPressureXp = calculateRewardXp(boss, { variant: "low_pressure" });
  assert.equal(normalXp, lowPressureXp, "boss variants should have identical XP");

  let state = fresh();
  state = startQuest(state, boss, now);
  state = completeQuest(state, boss, null, { skipReflection: true }, now);
  assert.equal(state.bossParticipants[utcDayKey(now)][boss.id], true, "boss participation should be keyed by UTC day");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state = completeQuest(state, selected, null, { isBoss: true, npcTrained: true, skipReflection: true }, now);
  const completion = state.events.find((event) => event.type === "quest_completed");
  assert.equal(state.stats.charisma, calculateRewardXp(selected), "completion must derive XP from canonical quest and preparation state");
  assert.equal(completion.payload.isBoss, false, "caller must not promote a regular quest to boss");
  assert.equal(completion.payload.npcTrained, false, "caller must not forge NPC training");
  assert.equal(state.bossParticipants[utcDayKey(now)]?.[selected.id], undefined, "regular quest must not write boss participation");
}

{
  let state = fresh();
  state = rollModifier(state, "q_c_001", MODIFIERS, now).state;
  assert.equal(state.events.at(-1).type, "dice_rolled", "dice roll should use canonical event name");
  assert.equal(state.events.at(-1).payload.isPro, false, "dice roll should log free/pro state");
  assert.throws(() => rollModifier(state, "q_c_001", MODIFIERS, now), /Бесплатный бросок/, "free user gets one roll per day");
}

{
  let state = setPro(fresh(), true);
  state = rollModifier(state, "q_c_001", MODIFIERS, new Date(now.getTime() + 1000)).state;
  state = rollModifier(state, "q_c_001", MODIFIERS, new Date(now.getTime() + 2000)).state;
  state = rollModifier(state, "q_c_001", MODIFIERS, new Date(now.getTime() + 3000)).state;
  state = rollModifier(state, "q_c_001", MODIFIERS, new Date(now.getTime() + 4000)).state;
  assert.throws(() => rollModifier(state, "q_c_001", MODIFIERS, new Date(now.getTime() + 5000)), /PRO-лимит/, "pro user gets 3 daily rolls and 1 reroll per quest");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  assert.throws(() => completeQuest(state, selected, null, { skipReflection: true }, now), /Сначала начни квест/, "quest completion should require quest_started");
  state = startQuest(state, selected, now);
  state = completeQuest(state, selected, null, { skipReflection: true }, now);
  assert.equal(state.stats.charisma, calculateRewardXp(selected), "skipping reflection should still grant XP");
  assert.equal(state.reflections[0].reflectionSkipped, true, "history should mark skipped reflection");
  assert.equal(state.events.some((event) => event.type === "reflection_submitted"), false, "skipped reflection should not submit reflection event");
  assert.equal(state.onboarding.done, true, "first offline completion should unlock disclaimer gate");
  assert.equal(state.onboarding.notMedicalAcknowledged, false, "first completion should not auto-acknowledge medical disclaimer");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  const guide = getGuideForQuest(selected);
  state = openQuestGuide(state, selected, guide, now);
  assert.equal(guide.steps.length, 3, "guide should expose 3 execution steps");
  assert.ok(guide.phrases.length >= 3, "guide should expose at least 3 phrases");
  assert.equal(state.events.at(-1).type, "guide_opened", "opening guide should be logged");
  assert.equal(state.events.at(-1).payload.guideId, guide.id, "guide event should include guide id");
}

{
  let state = fresh();
  const selected = quest("q_c_006");
  const dialog = getNpcDialogForQuest(selected);
  assert.ok(dialog.nodes[dialog.startNodeId], "NPC dialog should have a start node");
  assert.ok(dialog.nodes[dialog.startNodeId].options.length > 0, "NPC start node should offer choices");
  state = completeNpcTraining(state, selected, now);
  assert.equal(state.activeQuest, null, "NPC training should not implicitly start a quest");
  assert.equal(state.prep.npcTrainedByQuestId[selected.id], true, "NPC training should prepare XP buff for the quest");
  assert.equal(state.events.at(-1).type, "npc_training_completed", "NPC completion should be logged");
  state = startQuest(state, selected, now);
  assert.equal(state.activeQuest.npcTrained, true, "prepared NPC training should attach to started quest");
}

{
  let state = fresh();
  const selected = quest("q_c_006");
  state = completeNpcTraining(state, selected, now);
  state = startQuest(state, selected, new Date(now.getTime() + 1000));
  state = completeQuest(state, selected, null, { skipReflection: true }, new Date(now.getTime() + 2000));
  assert.equal(state.stats.charisma, calculateRewardXp(selected, { npcTrained: true }), "verified NPC training should grant the 10% XP bonus");
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date(now.getTime() + 3000));
  assert.equal(state.sync.pendingCount, 0, "valid NPC training, start, and completion sequence should sync");
}

{
  let state = fresh();
  state = rollModifier(state, "q_c_001", MODIFIERS, now).state;
  assert.equal(state.activeQuest, null, "dice roll should not implicitly start a quest");
  assert.ok(state.prep.modifiersByQuestId.q_c_001, "dice roll should prepare the modifier for start");
  state = startQuest(state, quest("q_c_001"), now);
  assert.ok(state.activeQuest.modifier, "prepared modifier should attach to started quest");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state = completeQuest(state, selected, { fear: 3, mood: 7, repeat: true }, {}, now);
  assert.ok(state.events.every((event, index) => event.clientSequence === index + 1), "events should have client sequence numbers");
  assert.equal(state.events.find((event) => event.type === "quest_completed").xpDelta, calculateRewardXp(selected), "quest_completed should expose xp_delta");
  assert.equal(state.sync.pendingCount, state.events.length, "new events should remain pending until sync");

  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, now);
  assert.equal(state.sync.pendingCount, 0, "valid events should sync");
  assert.equal(state.sync.lastSyncStatus, "ok", "valid sync should be ok");
  assert.ok(state.events.every((event) => event.synced), "synced events should be marked");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state = deferQuest(state, selected, new Date(now.getTime() + 30_000));
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date(now.getTime() + 31_000));
  assert.equal(state.sync.pendingCount, 0, "valid start and defer events should sync");
  assert.equal(state.events.at(-1).syncStatus, "synced", "a valid deferral should be accepted");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state.events.push({
    id: "event_forged_defer_charge",
    type: "quest_deferred",
    eventType: "quest_deferred",
    questId: selected.id,
    payload: { deferReason: "not_now", attemptDurationSeconds: 1, energyDelta: -10, energyAfter: 90 },
    metadata: { deferReason: "not_now", attemptDurationSeconds: 1, energyDelta: -10, energyAfter: 90 },
    energyDelta: -10,
    clientSequence: 2,
    synced: false,
    syncStatus: "pending",
    createdAt: new Date(now.getTime() + 1000).toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date(now.getTime() + 2000));
  const forged = state.events.find((event) => event.id === "event_forged_defer_charge");
  assert.equal(forged.synced, false, "deferral sync must reject an energy penalty");
  assert.match(forged.syncError, /energy_delta mismatch/, "invalid deferral energy should explain the mismatch");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state.events.push({
    id: "event_forged_defer_duration",
    type: "quest_deferred",
    eventType: "quest_deferred",
    questId: selected.id,
    payload: { deferReason: "not_now", attemptDurationSeconds: 99, energyDelta: 0, energyAfter: 100 },
    metadata: { deferReason: "not_now", attemptDurationSeconds: 99, energyDelta: 0, energyAfter: 100 },
    energyDelta: 0,
    clientSequence: 2,
    synced: false,
    syncStatus: "pending",
    createdAt: new Date(now.getTime() + 1000).toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date(now.getTime() + 2000));
  const forged = state.events.find((event) => event.id === "event_forged_defer_duration");
  assert.equal(forged.synced, false, "deferral sync must reject a forged attempt duration");
  assert.match(forged.syncError, /attempt_duration_seconds mismatch/, "invalid duration should explain the mismatch");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state.events.push({
    id: "event_legacy_failed",
    type: "quest_failed",
    eventType: "quest_failed",
    questId: selected.id,
    payload: { failReason: "escape", energyDelta: -20, energyAfter: 80 },
    metadata: { failReason: "escape", energyDelta: -20, energyAfter: 80 },
    energyDelta: -20,
    clientSequence: 2,
    synced: false,
    syncStatus: "pending",
    createdAt: new Date(now.getTime() + 1000).toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date(now.getTime() + 2000));
  const legacyFail = state.events.find((event) => event.id === "event_legacy_failed");
  assert.equal(legacyFail.synced, true, "legacy penalized fail events should remain recoverable during sync");
}

{
  let state = fresh();
  state.events.push({
    id: "event_bad_completion",
    type: "quest_completed",
    eventType: "quest_completed",
    questId: "q_c_001",
    payload: { xpDelta: 40, energyDelta: -10, energyAfter: 90 },
    metadata: { xpDelta: 40, energyDelta: -10, energyAfter: 90 },
    xpDelta: 40,
    energyDelta: -10,
    clientSequence: 1,
    synced: false,
    syncStatus: "pending",
    createdAt: now.toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, now);
  assert.equal(state.events[0].synced, false, "invalid completion should remain unsynced");
  assert.equal(state.events[0].syncStatus, "error", "invalid completion should be marked as sync error");
  assert.match(state.events[0].syncError, /quest_started/, "invalid completion should explain missing start");
  assert.equal(state.sync.lastSyncStatus, "partial", "sync with validation errors should be partial");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state.events.push({
    id: "event_forged_boss_reward",
    type: "quest_completed",
    eventType: "quest_completed",
    questId: selected.id,
    payload: { xpDelta: 80, energyDelta: 0, energyAfter: 100, isBoss: true },
    metadata: { xpDelta: 80, energyDelta: 0, energyAfter: 100, isBoss: true },
    xpDelta: 80,
    energyDelta: 0,
    clientSequence: 2,
    synced: false,
    syncStatus: "pending",
    createdAt: new Date(now.getTime() + 1000).toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, now);
  const forged = state.events.find((event) => event.id === "event_forged_boss_reward");
  assert.equal(forged.synced, false, "client metadata must not turn a regular quest into a boss reward");
  assert.match(forged.syncError, /isBoss mismatch/, "forged boss metadata should explain the validation error");
}

{
  let state = fresh();
  const selected = quest("q_c_006");
  state = startQuest(state, selected, now);
  state.events.push({
    id: "event_forged_npc_reward",
    type: "quest_completed",
    eventType: "quest_completed",
    questId: selected.id,
    payload: { xpDelta: 88, energyDelta: -10, energyAfter: 90, npcTrained: true },
    metadata: { xpDelta: 88, energyDelta: -10, energyAfter: 90, npcTrained: true },
    xpDelta: 88,
    energyDelta: -10,
    clientSequence: 2,
    synced: false,
    syncStatus: "pending",
    createdAt: new Date(now.getTime() + 1000).toISOString()
  });
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, now);
  const forged = state.events.find((event) => event.id === "event_forged_npc_reward");
  assert.equal(forged.synced, false, "NPC bonus must require a prior training event");
  assert.match(forged.syncError, /npc_training_completed/, "forged NPC bonus should explain the missing prerequisite");
}

{
  let state = fresh();
  const selected = quest("q_c_001");
  state = startQuest(state, selected, now);
  state.events.push({ ...state.events[0], synced: false, syncStatus: "pending" });
  state.sync.pendingCount = state.events.length;
  state = syncPendingEvents(state, QUESTS, BOSS_QUESTS, now);
  assert.equal(state.sync.pendingCount, 0, "duplicate event retries should not stay pending");
  assert.equal(state.events.at(-1).syncStatus, "deduplicated", "duplicate event id should be deduplicated");
}

console.log("All game rules passed.");
