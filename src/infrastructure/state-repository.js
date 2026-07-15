const STORAGE_FORMAT_VERSION = 1;

export function createBrowserStateRepository({ key, backupKey, now, logger, storage = globalThis.localStorage }) {
  return createLocalStateRepository({ storage, key, backupKey, now, logger });
}

export function createLocalStateRepository({
  storage,
  key,
  backupKey = `${key}.backup`,
  now = () => new Date(),
  logger = console
}) {
  if (!key) throw new Error("State repository requires a storage key.");

  const diagnostics = {
    lastLoadSource: "none",
    lastSavedAt: null,
    lastError: "",
    recoveryCount: 0
  };

  function load({ createDefault, normalize }) {
    if (typeof createDefault !== "function" || typeof normalize !== "function") {
      throw new Error("State repository load requires createDefault and normalize functions.");
    }

    const primary = readAndNormalize(key, normalize);
    if (primary.ok) {
      diagnostics.lastLoadSource = "primary";
      diagnostics.lastError = "";
      return { state: primary.state, source: "primary", recovered: false };
    }

    const backup = readAndNormalize(backupKey, normalize);
    if (backup.ok) {
      diagnostics.lastLoadSource = "backup";
      diagnostics.lastError = primary.error;
      diagnostics.recoveryCount += 1;
      warn(`Recovered local state from backup: ${primary.error}`);
      return { state: backup.state, source: "backup", recovered: true };
    }

    const state = normalize(createDefault());
    diagnostics.lastLoadSource = "default";
    diagnostics.lastError = primary.error || backup.error;
    if (primary.error || backup.error) {
      diagnostics.recoveryCount += 1;
      warn(`Started with default state: ${primary.error || backup.error}`);
    }
    return { state, source: "default", recovered: Boolean(primary.error || backup.error) };
  }

  function save(state) {
    try {
      const envelope = JSON.stringify({
        formatVersion: STORAGE_FORMAT_VERSION,
        savedAt: now().toISOString(),
        state
      });
      const previous = storage?.getItem?.(key);
      const previousIsKnownBad = diagnostics.lastLoadSource === "backup"
        || (diagnostics.lastLoadSource === "default" && diagnostics.lastError);
      if (previous && !previousIsKnownBad) storage.setItem(backupKey, previous);
      storage?.setItem?.(key, envelope);
      if (!storage?.setItem) throw new Error("storage.setItem is unavailable");
      diagnostics.lastSavedAt = now().toISOString();
      diagnostics.lastError = "";
      return { ok: true, error: "" };
    } catch (error) {
      const message = errorMessage(error);
      diagnostics.lastError = message;
      warn(`Local state save failed: ${message}`);
      return { ok: false, error: message };
    }
  }

  function clear() {
    try {
      if (!storage?.removeItem) throw new Error("storage.removeItem is unavailable");
      storage.removeItem(key);
      storage.removeItem(backupKey);
      diagnostics.lastLoadSource = "none";
      diagnostics.lastSavedAt = null;
      diagnostics.lastError = "";
      return { ok: true, error: "" };
    } catch (error) {
      const message = errorMessage(error);
      diagnostics.lastError = message;
      warn(`Local state clear failed: ${message}`);
      return { ok: false, error: message };
    }
  }

  function getDiagnostics() {
    return { ...diagnostics };
  }

  function readAndNormalize(storageKey, normalize) {
    try {
      if (!storage?.getItem) throw new Error("storage.getItem is unavailable");
      const raw = storage.getItem(storageKey);
      if (!raw) return { ok: false, state: null, error: "" };
      const parsed = JSON.parse(raw);
      const payload = isEnvelope(parsed) ? parsed.state : parsed;
      if (!payload || typeof payload !== "object") throw new Error("stored state is not an object");
      return { ok: true, state: normalize(payload), error: "" };
    } catch (error) {
      return { ok: false, state: null, error: errorMessage(error) };
    }
  }

  function warn(message) {
    if (typeof logger?.warn === "function") logger.warn(`[state-repository] ${message}`);
  }

  return { load, save, clear, getDiagnostics };
}

function isEnvelope(value) {
  return Boolean(
    value
    && typeof value === "object"
    && Number(value.formatVersion) >= 1
    && value.state
    && typeof value.state === "object"
  );
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error || "unknown storage error");
}
