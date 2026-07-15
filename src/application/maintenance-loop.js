export function createMaintenanceLoop({
  getState,
  setState,
  refreshState,
  hasPendingWork,
  syncState,
  persistState,
  shouldRender = () => false,
  render = () => {},
  clock = () => new Date(),
  scheduler = globalThis,
  intervalMs = 60_000
}) {
  const dependencies = { getState, setState, refreshState, hasPendingWork, syncState, persistState };
  for (const [name, dependency] of Object.entries(dependencies)) {
    if (typeof dependency !== "function") throw new Error(`Maintenance loop requires ${name}.`);
  }
  if (!scheduler?.setInterval || !scheduler?.clearInterval) {
    throw new Error("Maintenance loop requires setInterval and clearInterval.");
  }

  let timerId = null;

  function tick(now = clock()) {
    let next = refreshState(getState(), now);
    if (hasPendingWork(next)) next = syncState(next, now);
    setState(next);
    persistState(next);
    if (shouldRender()) render();
    return next;
  }

  function start() {
    if (timerId !== null) return timerId;
    timerId = scheduler.setInterval(() => tick(clock()), intervalMs);
    return timerId;
  }

  function stop() {
    if (timerId === null) return;
    scheduler.clearInterval(timerId);
    timerId = null;
  }

  function isRunning() {
    return timerId !== null;
  }

  return { tick, start, stop, isRunning };
}
