import assert from "node:assert/strict";
import test from "node:test";
import { performance } from "node:perf_hooks";
import { BOSS_QUESTS, MODIFIERS, QUESTS } from "../src/data.js";
import { createMaintenanceLoop } from "../src/application/maintenance-loop.js";
import { createQuestCatalog, QuestCatalogError } from "../src/domain/quest-catalog.js";
import { createDefaultState, syncPendingEvents } from "../src/game.js";
import { createLocalStateRepository } from "../src/infrastructure/state-repository.js";

class MemoryStorage {
  constructor(entries = {}) {
    this.entries = new Map(Object.entries(entries));
    this.failWrites = false;
  }

  getItem(key) {
    return this.entries.has(key) ? this.entries.get(key) : null;
  }

  setItem(key, value) {
    if (this.failWrites) throw new Error("quota exceeded");
    this.entries.set(key, String(value));
  }

  removeItem(key) {
    this.entries.delete(key);
  }
}

function silentLogger() {
  return { warn() {} };
}

test("maintenance loop keeps scheduler and infrastructure outside the UI", () => {
  let state = { value: 1, pending: true };
  let persisted = null;
  let renderCount = 0;
  let scheduledCallback = null;
  let setIntervalCount = 0;
  let clearIntervalCount = 0;
  const scheduler = {
    setInterval(callback) {
      setIntervalCount += 1;
      scheduledCallback = callback;
      return 42;
    },
    clearInterval(id) {
      assert.equal(id, 42);
      clearIntervalCount += 1;
    }
  };
  const loop = createMaintenanceLoop({
    getState: () => state,
    setState: (next) => { state = next; },
    refreshState: (current) => ({ ...current, value: current.value + 1 }),
    hasPendingWork: (current) => current.pending,
    syncState: (current) => ({ ...current, pending: false, synced: true }),
    persistState: (current) => { persisted = current; },
    shouldRender: () => true,
    render: () => { renderCount += 1; },
    scheduler,
    clock: () => new Date("2026-07-11T00:00:00.000Z")
  });

  loop.start();
  loop.start();
  assert.equal(setIntervalCount, 1);
  scheduledCallback();
  assert.deepEqual(state, { value: 2, pending: false, synced: true });
  assert.equal(persisted, state);
  assert.equal(renderCount, 1);
  loop.stop();
  assert.equal(clearIntervalCount, 1);
  assert.equal(loop.isRunning(), false);
});

test("state repository loads legacy raw state and writes a versioned envelope", () => {
  const storage = new MemoryStorage({ app: JSON.stringify({ schemaVersion: 2, value: 7 }) });
  const repository = createLocalStateRepository({ storage, key: "app", logger: silentLogger() });
  const loaded = repository.load({
    createDefault: () => ({ value: 0 }),
    normalize: (state) => ({ ...state, normalized: true })
  });

  assert.equal(loaded.source, "primary");
  assert.equal(loaded.state.value, 7);
  assert.equal(loaded.state.normalized, true);

  assert.equal(repository.save({ value: 8 }).ok, true);
  const envelope = JSON.parse(storage.getItem("app"));
  assert.equal(envelope.formatVersion, 1);
  assert.deepEqual(envelope.state, { value: 8 });
  assert.equal(JSON.parse(storage.getItem("app.backup")).value, 7);
});

test("state repository recovers from backup and does not throw on write failure", () => {
  const backup = JSON.stringify({ formatVersion: 1, savedAt: "2026-07-11T00:00:00.000Z", state: { value: 4 } });
  const storage = new MemoryStorage({ app: "{broken", "app.backup": backup });
  const repository = createLocalStateRepository({ storage, key: "app", logger: silentLogger() });
  const loaded = repository.load({
    createDefault: () => ({ value: 0 }),
    normalize: (state) => state
  });

  assert.equal(loaded.source, "backup");
  assert.equal(loaded.recovered, true);
  assert.equal(loaded.state.value, 4);

  storage.failWrites = true;
  const result = repository.save({ value: 5 });
  assert.equal(result.ok, false);
  assert.match(result.error, /quota exceeded/);
  assert.equal(repository.getDiagnostics().recoveryCount, 1);
});

test("quest catalog validates records and provides indexed lookup", () => {
  const catalog = createQuestCatalog({ quests: QUESTS, bosses: BOSS_QUESTS, modifiers: MODIFIERS });
  assert.equal(catalog.getQuest(QUESTS[0].id), QUESTS[0]);
  assert.equal(catalog.isBoss(BOSS_QUESTS[0].id), true);
  assert.equal(catalog.has("missing"), false);

  const invalidBosses = [{ ...BOSS_QUESTS[0], id: QUESTS[0].id, lowPressureVariant: "" }];
  assert.throws(
    () => createQuestCatalog({ quests: QUESTS, bosses: invalidBosses, modifiers: MODIFIERS }),
    (error) => error instanceof QuestCatalogError
      && error.errors.some((item) => item.includes("duplicate quest id"))
      && error.errors.some((item) => item.includes("alternate route"))
  );
});

test("event sync handles a reversed 10k-event offline journal within a bounded time", () => {
  const state = createDefaultState(new Date("2026-07-11T00:00:00.000Z"));
  const events = [];
  const baseTime = Date.parse("2026-07-11T00:00:00.000Z");

  for (let index = 0; index < 5000; index += 1) {
    const startTime = new Date(baseTime + index * 2).toISOString();
    const completionTime = new Date(baseTime + index * 2 + 1).toISOString();
    events.push({
      id: `load_start_${index}`,
      type: "quest_started",
      questId: "q_c_001",
      payload: { level: 1, statType: "charisma", isShadow: false },
      clientSequence: index * 2 + 1,
      synced: false,
      createdAt: startTime
    });
    events.push({
      id: `load_complete_${index}`,
      type: "quest_completed",
      questId: "q_c_001",
      payload: { xpDelta: 40, energyDelta: -10, energyAfter: 90, isBoss: false, npcTrained: false },
      xpDelta: 40,
      energyDelta: -10,
      clientSequence: index * 2 + 2,
      synced: false,
      createdAt: completionTime
    });
  }

  state.events = events.reverse();
  const startedAt = performance.now();
  const synced = syncPendingEvents(state, QUESTS, BOSS_QUESTS, new Date("2026-07-11T01:00:00.000Z"));
  const durationMs = performance.now() - startedAt;

  assert.equal(synced.sync.pendingCount, 0);
  assert.equal(synced.sync.acceptedCount, 10_000);
  assert.equal(synced.sync.lastSyncStatus, "ok");
  assert.ok(durationMs < 2000, `10k event sync took ${durationMs.toFixed(1)}ms`);
});
