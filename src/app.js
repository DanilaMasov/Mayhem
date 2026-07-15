import {
  BOSS_QUESTS,
  MODIFIERS,
  QUESTS,
  STAT_HINTS,
  STAT_LABELS,
  getGuideForQuest,
  getNpcDialogForQuest
} from "./data.js";
import {
  STORAGE_KEY,
  deferQuest,
  acknowledgeBoundaries,
  calculateRewardXp,
  canStartQuest,
  clearAllProgress,
  completeNpcTraining,
  completeQuest,
  createDefaultState,
  dailyQuestKey,
  getBossParticipants,
  getDiceAllowance,
  getEnergyStatus,
  getLevelProgress,
  getStatShare,
  getTotalXp,
  normalizeState,
  openQuestGuide,
  refreshDailyQuests,
  rollModifier,
  setPro,
  startQuest,
  syncPendingEvents,
  updateEnergy
} from "./game.js";
import { createMaintenanceLoop } from "./application/maintenance-loop.js";
import { createQuestCatalog } from "./domain/quest-catalog.js";
import { createBrowserStateRepository } from "./infrastructure/state-repository.js";

const app = document.querySelector("#app");
const DEBUG_UI = new URLSearchParams(window.location.search).has("debug");
const questCatalog = createQuestCatalog({
  quests: QUESTS,
  bosses: BOSS_QUESTS,
  modifiers: MODIFIERS
});
const stateRepository = createBrowserStateRepository({ key: STORAGE_KEY });
let persistenceWarningShown = false;

let state = loadState();
let ui = {
  view: "today",
  selectedQuestId: null,
  selectedVariant: "normal",
  selectedReflectionId: null,
  selectedNpcNodeId: null,
  guideOpenQuestId: null,
  scrollTopAfterRender: false,
  toast: ""
};

const maintenanceLoop = createMaintenanceLoop({
  getState: () => state,
  setState: (next) => {
    state = next;
  },
  refreshState: (current, now) => updateEnergy(current, now),
  hasPendingWork: (current) => current.events.some((event) => !event.synced),
  syncState: (current, now) => syncPendingEvents(current, QUESTS, BOSS_QUESTS, now),
  persistState: (current) => persist(current),
  shouldRender: () => ui.view === "today" || ui.view === "settings",
  render: () => render(),
  scheduler: window
});

state = refreshDailyQuests(state, QUESTS, BOSS_QUESTS);
persist();
render();
maintenanceLoop.start();

app.addEventListener("click", (event) => {
  const target = event.target.closest("[data-action]");
  if (!target) return;

  const action = target.dataset.action;
  const id = target.dataset.id;

  try {
    if (action === "view") {
      ui.view = target.dataset.view || "today";
      ui.selectedQuestId = null;
      ui.selectedReflectionId = null;
      ui.selectedNpcNodeId = null;
      ui.guideOpenQuestId = null;
      ui.toast = "";
      queueScrollTop();
      render();
    }

    if (action === "acknowledge") {
      ui.view = "today";
      queueScrollTop();
      mutate((current) => acknowledgeBoundaries(current));
    }

    if (action === "openQuest") {
      ui.selectedQuestId = id;
      ui.selectedVariant = target.dataset.variant || "normal";
      ui.selectedNpcNodeId = null;
      ui.guideOpenQuestId = null;
      ui.view = "quest";
      ui.toast = "";
      queueScrollTop();
      render();
    }

    if (action === "openGuide") {
      const quest = findQuest(id);
      const guide = getGuideForQuest(quest);
      ui.selectedQuestId = id;
      ui.selectedNpcNodeId = null;
      ui.guideOpenQuestId = id;
      ui.view = "quest";
      ui.toast = "";
      queueScrollTop();
      mutate((current) => openQuestGuide(current, quest, guide));
    }

    if (action === "selectVariant") {
      ui.selectedVariant = target.dataset.variant || "normal";
      render();
    }

    if (action === "startQuest") {
      const quest = findQuest(id);
      mutate((current) => startQuest(current, quest), "Вызов принят.");
    }

    if (action === "trainQuest") {
      const quest = findQuest(id);
      const dialog = getNpcDialogForQuest(quest);
      ui.selectedQuestId = id;
      ui.selectedNpcNodeId = dialog.startNodeId;
      ui.view = "npcTraining";
      ui.toast = "";
      queueScrollTop();
      render();
    }

    if (action === "chooseNpcOption") {
      const quest = findQuest(id);
      const dialog = getNpcDialogForQuest(quest);
      const nextNodeId = target.dataset.next;
      const nextNode = dialog.nodes[nextNodeId];
      if (!nextNode) throw new Error("Сценарий тренировки не найден.");

      if (nextNode.success) {
        ui.view = "quest";
        ui.selectedNpcNodeId = null;
        queueScrollTop();
        mutate((current) => completeNpcTraining(current, quest), "Репетиция зачтена. XP +10%.");
      } else {
        ui.selectedNpcNodeId = nextNodeId;
        render();
      }
    }

    if (action === "rollDice") {
      mutate((current) => rollModifier(current, id, MODIFIERS).state, "Модификатор выпал.");
    }

    if (action === "reflectQuest") {
      ui.selectedQuestId = id;
      ui.view = "reflection";
      ui.toast = "";
      queueScrollTop();
      render();
    }

    if (action === "deferQuest") {
      const quest = findQuest(id);
      ui.view = "today";
      queueScrollTop();
      mutate((current) => deferQuest(current, quest), "Попытка закрыта. Вызов остаётся доступен.");
    }

    if (action === "skipReflection") {
      const quest = findQuest(id);
      const isBoss = isBossQuest(quest.id);
      ui.view = "profile";
      ui.selectedQuestId = null;
      queueScrollTop();
      mutate((current) => completeQuest(current, quest, null, {
        variant: isBoss ? ui.selectedVariant : "normal",
        skipReflection: true
      }), "XP начислен. Reflection пропущен.");
    }

    if (action === "openReflection") {
      ui.selectedReflectionId = id;
      ui.selectedNpcNodeId = null;
      ui.view = "reflectionDetail";
      ui.toast = "";
      queueScrollTop();
      render();
    }

    if (action === "togglePro") {
      mutate((current) => setPro(current, !current.profile.pro), state.profile.pro ? "PRO отключен." : "PRO активен.");
    }

    if (action === "resetProgress") {
      if (confirm("Удалить локальный прогресс MAYHEM?")) {
        stateRepository.clear();
        state = clearAllProgress();
        ui = { view: "today", selectedQuestId: null, selectedVariant: "normal", selectedReflectionId: null, selectedNpcNodeId: null, guideOpenQuestId: null, scrollTopAfterRender: true, toast: "Прогресс удален." };
        persist();
        render();
      }
    }
  } catch (error) {
    showToast(error.message || "Что-то пошло не так.");
  }
});

app.addEventListener("input", (event) => {
  if (event.target.matches("input[type='range']")) {
    const output = app.querySelector(`[data-output='${event.target.name}']`);
    if (output) output.textContent = event.target.value;
  }
});

app.addEventListener("submit", (event) => {
  event.preventDefault();
  const form = event.target;
  if (!form.matches("[data-form='reflection']")) return;

  const quest = findQuest(ui.selectedQuestId);
  const formData = new FormData(form);
  const reflection = {
    fear: Number(formData.get("fear") || 5),
    mood: Number(formData.get("mood") || 6),
    repeat: formData.get("repeat") === "yes",
    note: formData.get("note") || ""
  };
  const isBoss = isBossQuest(quest.id);

  try {
    ui.view = "profile";
    ui.selectedQuestId = null;
    queueScrollTop();
    mutate((current) => completeQuest(current, quest, reflection, {
      variant: isBoss ? ui.selectedVariant : "normal"
    }), "Reflection сохранен. XP начислен.");
  } catch (error) {
    showToast(error.message || "Не удалось завершить квест.");
  }
});

function loadState() {
  const loaded = stateRepository.load({
    createDefault: createDefaultState,
    normalize: normalizeState
  });
  if (loaded.recovered) {
    console.warn(`[app] Local state recovered from ${loaded.source}.`);
  }
  return loaded.state;
}

function persist(stateToSave = state) {
  const result = stateRepository.save(stateToSave);
  if (!result.ok && !persistenceWarningShown) {
    persistenceWarningShown = true;
    console.error(`[app] Progress is running in memory because persistence failed: ${result.error}`);
    if (ui) ui.toast = "Не удалось сохранить прогресс на устройстве.";
  }
  if (result.ok) persistenceWarningShown = false;
}

function mutate(updater, message) {
  state = updater(state);
  state = refreshDailyQuests(normalizeState(state), QUESTS, BOSS_QUESTS);
  if (message) ui.toast = message;
  persist();
  render();
}

function showToast(message) {
  ui.toast = message;
  render();
}

function queueScrollTop() {
  ui.scrollTopAfterRender = true;
}

function render() {
  state = refreshDailyQuests(normalizeState(state), QUESTS, BOSS_QUESTS);

  if (state.onboarding.done && !state.onboarding.notMedicalAcknowledged) {
    app.innerHTML = renderBoundaryGate();
    flushQueuedScroll();
    return;
  }

  const content = renderCurrentView();
  app.innerHTML = `
    ${renderTopBar()}
    <main class="screen-content">${content}</main>
    ${renderBottomNav()}
    ${ui.toast ? `<div class="toast ${ui.view === "quest" ? "above-actions" : ""}" role="status">${escapeHtml(ui.toast)}</div>` : ""}
  `;
  if (ui.toast) {
    window.clearTimeout(render.toastTimer);
    render.toastTimer = window.setTimeout(() => {
      ui.toast = "";
      render();
    }, 2400);
  }
  flushQueuedScroll();
}

function flushQueuedScroll() {
  if (!ui.scrollTopAfterRender) return;
  ui.scrollTopAfterRender = false;
  window.requestAnimationFrame(() => window.scrollTo({ top: 0, left: 0, behavior: "auto" }));
}

function renderCurrentView() {
  if (ui.view === "quest") return renderQuestDetail();
  if (ui.view === "npcTraining") return renderNpcTraining();
  if (ui.view === "reflection") return renderReflection();
  if (ui.view === "reflectionDetail") return renderReflectionDetail();
  if (ui.view === "profile") return renderProfile();
  if (ui.view === "settings") return renderSettings();
  if (ui.view === "pro") return renderPaywall();
  return renderToday();
}

function renderBoundaryGate() {
  return `
    <main class="gate">
      <section class="brand-panel">
        <div class="brand-mark">M</div>
        <div>
          <p class="eyebrow">MAYHEM // SOCIAL CHALLENGE</p>
          <h1>Действуй под социальным давлением</h1>
        </div>
      </section>

      <section class="plain-section">
        <h2>Правила площадки</h2>
        <p>MAYHEM тренирует действие в неловкой социальной ситуации. Это не терапия, диагностика или медицинский продукт.</p>
        <p>Запрещены унижение, сексуальные провокации, скрытая съёмка и давление после отказа. Из любой попытки можно выйти. В кризисной ситуации нужна профессиональная помощь.</p>
        <button class="primary full" data-action="acknowledge">${icon("check")} Понял. Войти</button>
      </section>

      <section class="quest-card featured">
        <div class="quest-topline">
          <span>Кодекс</span>
          <span>01</span>
        </div>
        <h2>Риск берёшь на себя</h2>
        <p>Твоя задача — выдержать возможность отказа. Другой человек ничего тебе не должен.</p>
      </section>
    </main>
  `;
}

function renderTopBar() {
  const levelProgress = Math.round(getLevelProgress(state) * 100);
  const status = getEnergyStatus(state);
  const totalXp = getTotalXp(state);
  return `
    <header class="topbar">
      <div class="identity">
        <div class="brand-mark small">M</div>
        <div class="wordmark">
          <strong>MAYHEM</strong>
          <span>SOCIAL CHALLENGE</span>
        </div>
      </div>
      ${DEBUG_UI ? `<button class="ghost compact" data-action="view" data-view="pro">${state.profile.pro ? "PRO" : "Free"}</button>` : ""}
    </header>
    <section class="status-band">
      <div class="energy-meter">
        <span class="metric-icon">${icon("bolt")}</span>
        <div>
          <span>Энергия</span>
          <strong>${state.energy.value}%</strong>
        </div>
      </div>
      <div class="status-copy">
        <div class="status-line">
          <span>${status.label}</span>
          <strong>${totalXp} XP</strong>
        </div>
        <div class="progress-track" aria-label="Прогресс уровня">
          <span style="width:${levelProgress}%"></span>
        </div>
      </div>
    </section>
  `;
}

function renderToday() {
  const status = getEnergyStatus(state);
  const localQuests = state.daily.localQuestIds.map(findQuest).filter(Boolean);
  const bossQuest = findQuest(state.daily.bossId);
  const showShadow = status.blocked || state.energy.value < 20;
  const shadowQuests = QUESTS.filter((quest) => quest.isShadow).slice(0, 3);

  return `
    <section class="page-heading">
      <div>
        <p class="eyebrow">DAILY DROP // ${formatDate(dailyQuestKey())}</p>
        <h1>Вызов дня</h1>
      </div>
      <div class="drop-clock">
        <span>СБРОС UTC</span>
        <strong>${formatUtcResetCountdown()}</strong>
      </div>
    </section>

    ${status.key === "recluse" ? `<div class="notice danger">Энергия на нуле. Обычные квесты вернутся после восстановления до 20%.</div>` : ""}
    ${status.key === "recovering" ? `<div class="notice">Сейчас лучше Shadow-квесты: они возвращают энергию и сохраняют привычку.</div>` : ""}

    ${bossQuest ? `
      <section class="quest-group shared-quest-group">
        <div class="group-heading">
          <strong>DROP // ${challengeCode(bossQuest.id)}</strong>
          <span>главная попытка</span>
        </div>
        <div class="quest-list">
          ${renderQuestCard(bossQuest, true)}
        </div>
      </section>
    ` : ""}

    <section class="quest-group local-quest-group">
      <div class="group-heading">
        <strong>BACKUP RUNS</strong>
        <span>ещё ${localQuests.length}</span>
      </div>
      <div class="quest-list">
        ${localQuests.map((quest) => renderQuestCard(quest)).join("")}
      </div>
    </section>

    ${showShadow ? `
      <section class="quest-group recovery-group">
        <div class="group-heading">
          <strong>RESET RUNS</strong>
          <span>вернуть ресурс</span>
        </div>
        <div class="quest-list">
          ${shadowQuests.map((quest) => renderQuestCard(quest)).join("")}
        </div>
      </section>
    ` : ""}
  `;
}

function renderQuestCard(quest, isBoss = false) {
  const completed = isCompletedToday(quest.id);
  const isShadow = Boolean(quest.isShadow);
  const reward = calculateRewardXp(quest);
  const status = canStartQuest(state, quest);
  const disabled = !status.ok && !completed;
  const participantCopy = isBoss && DEBUG_UI
    ? `<span>${getBossParticipants(state, quest).toLocaleString("ru-RU")} · mock</span>`
    : "";
  const typeLabel = isBoss ? "ГЛАВНЫЙ ВЫЗОВ" : isShadow ? "RESET RUN" : `RUN // L${quest.level}`;
  const statClass = `stat-${quest.statType}`;
  const questIcon = isBoss ? "globe" : isShadow ? "moon" : {
    charisma: "message",
    boldness: "bolt",
    networking: "users"
  }[quest.statType] || "target";
  const openLabel = disabled ? status.reason : `Открыть квест: ${quest.questText}`;

  return `
    <article class="quest-row ${statClass} ${isBoss ? "boss" : ""} ${isShadow ? "shadow" : ""} ${completed ? "completed" : ""}">
      <div class="quest-row-icon" aria-hidden="true">${icon(questIcon)}</div>
      <div class="quest-row-copy">
        <div class="quest-row-kicker">
          <span>${typeLabel}</span>
          <span>${isShadow ? "+5 энергии" : `−${quest.energyCost}%`}</span>
        </div>
        <h2>${escapeHtml(quest.questText)}</h2>
        <div class="quest-row-meta">
          <span>${escapeHtml(STAT_LABELS[quest.statType])}</span>
          <span>${reward} XP</span>
          ${participantCopy}
          ${completed ? "<span class=\"done-label\">ЗАКРЫТО</span>" : ""}
        </div>
      </div>
      <div class="quest-row-actions">
        <button class="icon-button" data-action="openGuide" data-id="${quest.id}" aria-label="Как выполнить квест" title="Как выполнить">
          ${icon("book")}
        </button>
        <button class="icon-button open-button" data-action="openQuest" data-id="${quest.id}" ${disabled ? "disabled" : ""} aria-label="${escapeHtml(openLabel)}" title="${escapeHtml(openLabel)}">
          ${icon("chevron")}
        </button>
      </div>
    </article>
  `;
}

function renderQuestDetail() {
  const quest = findQuest(ui.selectedQuestId);
  if (!quest) return emptyState("Квест не найден.");

  const isBoss = isBossQuest(quest.id);
  const guide = getGuideForQuest(quest);
  const active = state.activeQuest?.questId === quest.id;
  const prepared = state.prep || {};
  const trained = Boolean((active && state.activeQuest?.npcTrained) || prepared.npcTrainedByQuestId?.[quest.id]);
  const modifier = active ? state.activeQuest?.modifier : prepared.modifiersByQuestId?.[quest.id] || null;
  const dice = getDiceAllowance(state, quest.id);
  const allowed = canStartQuest(state, quest);
  const reward = calculateRewardXp(quest, { npcTrained: trained });
  const guideExpanded = ui.guideOpenQuestId === quest.id;
  const guideCompletedBefore = hasCompletedQuestEver(quest.id);
  const statClass = `stat-${quest.statType}`;
  const typeLabel = isBoss ? `DROP // ${challengeCode(quest.id)}` : quest.isShadow ? "RESET RUN" : `RUN // L${quest.level}`;

  return `
    <section class="quest-detail">
      <div class="detail-nav">
        <button class="icon-button back-button" data-action="view" data-view="today" aria-label="Назад к квестам" title="Назад">${icon("back")}</button>
        <span>${typeLabel}</span>
      </div>
      <article class="quest-brief ${statClass} ${isBoss ? "boss" : ""} ${quest.isShadow ? "shadow" : ""}">
        <div class="quest-brief-kicker">
          <span>${escapeHtml(quest.category)}</span>
          <span>${escapeHtml(STAT_LABELS[quest.statType])}</span>
        </div>
        <h1>${escapeHtml(quest.questText)}</h1>
        <p>${escapeHtml(STAT_HINTS[quest.statType])}</p>
        <div class="quest-brief-metrics">
          <span>${icon("bolt")} ${quest.isShadow ? "+5 энергии" : `${quest.energyCost}% энергии`}</span>
          <span>${reward} XP</span>
        </div>
        ${isBoss ? renderVariantSelector(quest) : ""}
        ${modifier ? `<div class="modifier"><strong>${escapeHtml(modifier.title)}</strong><span>${escapeHtml(modifier.text)}</span></div>` : ""}
      </article>

      ${guideExpanded ? renderGuideSection(guide, guideCompletedBefore) : renderGuideCollapsed(quest, guideCompletedBefore)}

      <section class="preparation-grid">
        ${quest.level >= 2 && !quest.isShadow ? `<button class="secondary" data-action="trainQuest" data-id="${quest.id}" ${trained ? "disabled" : ""}>${icon("message")} ${trained ? "Репетиция готова" : "Репетиция"}</button>` : ""}
        <button class="secondary" data-action="rollDice" data-id="${quest.id}" ${dice.canRoll ? "" : "disabled"}>${icon("dice")} Условие · ${escapeHtml(dice.label)}</button>
      </section>
      <section class="quest-action-bar ${active ? "active-attempt" : ""}">
        ${active
          ? `<button class="success" data-action="reflectQuest" data-id="${quest.id}">${icon("check")} Закрыть</button>
             <button class="secondary" data-action="deferQuest" data-id="${quest.id}">${icon("x")} Сойти</button>`
          : `<button class="primary full" data-action="startQuest" data-id="${quest.id}" ${allowed.ok ? "" : "disabled"}>${icon("play")} ${allowed.ok ? "Принять вызов" : escapeHtml(allowed.reason)}</button>`}
      </section>
    </section>
  `;
}

function renderGuideCollapsed(quest, completedBefore) {
  return `
    <section class="plain-section guide-collapsed">
      <div>
        <p class="eyebrow">РАЗБОР</p>
        <h2>${completedBefore ? "Разбор свёрнут" : "Разобрать вызов"}</h2>
        <p>${completedBefore ? "Ты уже проходил этот тип давления. Разбор доступен по кнопке." : "Маршрут, рабочая фраза, усложнение и чистый выход."}</p>
      </div>
      <button class="ghost compact" data-action="openGuide" data-id="${quest.id}" aria-label="Открыть разбор">${icon("book")}</button>
    </section>
  `;
}

function renderGuideSection(guide, completedBefore) {
  return `
    <section class="plain-section">
      <div class="section-head compact-head">
        <div>
          <p class="eyebrow">${escapeHtml(guide.title)}${guide.curated ? " · curated" : ""}</p>
          <h2>${completedBefore ? "Повторить разбор" : "Маршрут"}</h2>
        </div>
      </div>
      <ol class="steps">
        ${guide.steps.map((step) => `<li>${escapeHtml(step)}</li>`).join("")}
      </ol>
      <div class="phrase-row">
        ${guide.phrases.map((phrase) => `<span>${escapeHtml(phrase)}</span>`).join("")}
      </div>
      <div class="variant-box">
        <strong>Другой маршрут</strong>
        <p>${escapeHtml(guide.lowPressureVariant)}</p>
      </div>
      <div class="variant-box">
        <strong>Усложнение</strong>
        <p>${escapeHtml(guide.advancedVariant)}</p>
      </div>
      <div class="variant-box">
        <strong>Выход</strong>
        <p>${escapeHtml(guide.refusalScript)}</p>
      </div>
    </section>
  `;
}

function renderNpcTraining() {
  const quest = findQuest(ui.selectedQuestId);
  if (!quest) return emptyState("Квест не найден.");

  const dialog = getNpcDialogForQuest(quest);
  const node = dialog.nodes[ui.selectedNpcNodeId] || dialog.nodes[dialog.startNodeId];

  return `
    <section class="npc-screen">
      <button class="text-button" data-action="openQuest" data-id="${quest.id}">${icon("back")} Квест</button>
      <div class="section-head">
        <div>
          <p class="eyebrow">${escapeHtml(dialog.title)}</p>
          <h1>Репетиция</h1>
        </div>
      </div>
      <article class="npc-card">
        <p class="eyebrow">${node.speaker === "npc" ? "NPC" : "Coach"}</p>
        <h2>${escapeHtml(node.text)}</h2>
      </article>
      <div class="npc-options">
        ${node.options.map((option) => `
          <button class="secondary full" data-action="chooseNpcOption" data-id="${quest.id}" data-next="${option.next}">
            ${icon("message")} ${escapeHtml(option.label)}
          </button>
        `).join("")}
      </div>
    </section>
  `;
}

function renderVariantSelector(quest) {
  const normalActive = ui.selectedVariant === "normal";
  const lowActive = ui.selectedVariant === "low_pressure";
  return `
    <div class="segment" role="group" aria-label="Маршрут вызова">
      <button data-action="selectVariant" data-variant="normal" class="${normalActive ? "active" : ""}">Основной</button>
      <button data-action="selectVariant" data-variant="low_pressure" class="${lowActive ? "active" : ""}">Другой маршрут</button>
    </div>
    <p class="variant-copy">${escapeHtml(lowActive ? quest.lowPressureVariant : quest.questText)}</p>
  `;
}

function renderReflection() {
  const quest = findQuest(ui.selectedQuestId);
  if (!quest) return emptyState("Квест не найден.");

  return `
    <section class="reflection-screen">
      <button class="text-button" data-action="openQuest" data-id="${quest.id}">${icon("back")} Квест</button>
      <div class="section-head">
        <div>
          <p class="eyebrow">Reflection</p>
          <h1>Как прошло?</h1>
        </div>
        <button class="ghost compact" data-action="skipReflection" data-id="${quest.id}">Пропустить</button>
      </div>
      <form class="reflection-form" data-form="reflection">
        <label class="slider-row">
          <span>Страх до действия</span>
          <strong data-output="fear">5</strong>
          <input name="fear" type="range" min="1" max="10" value="5" />
        </label>
        <label class="slider-row">
          <span>Состояние после</span>
          <strong data-output="mood">6</strong>
          <input name="mood" type="range" min="1" max="10" value="6" />
        </label>
        <fieldset class="choice-row">
          <legend>Хочу повторить?</legend>
          <label><input type="radio" name="repeat" value="yes" checked /> Да</label>
          <label><input type="radio" name="repeat" value="no" /> Нет</label>
        </fieldset>
        <label class="note-field">
          <span>Заметка для себя</span>
          <textarea name="note" rows="4" maxlength="240" placeholder="Что помогло, что было лишним, что попробовать позже"></textarea>
        </label>
        <button class="primary full" type="submit">${icon("check")} Сохранить</button>
      </form>
    </section>
  `;
}

function renderProfile() {
  const history = state.reflections;
  const totalXp = getTotalXp(state);

  return `
    <section class="page-heading">
      <div>
        <p class="eyebrow">РЕЗУЛЬТАТ</p>
        <h1>Твоя статистика</h1>
      </div>
    </section>

    <section class="profile-hero">
      <div class="profile-total">
        <span>Всего</span>
        <strong>${totalXp}</strong>
        <span>XP</span>
      </div>
      <div class="profile-summary">
        <div>
          <span>${state.energy.value}%</span>
          <p>Энергия</p>
        </div>
        <div>
          <span>${history.length}</span>
          <p>Квестов</p>
        </div>
      </div>
    </section>

    <div class="group-heading profile-group-heading">
      <strong>Характеристики</strong>
      <span>распределение XP</span>
    </div>
    <section class="stats-list">
      ${Object.keys(STAT_LABELS).map((stat) => renderStatCard(stat)).join("")}
    </section>

    <div class="group-heading history-heading">
      <strong>История</strong>
      <span>${history.length ? `${history.length} записей` : "пока пусто"}</span>
    </div>

    <div class="history-list">
      ${history.length ? history.map(renderHistoryItem).join("") : emptyState("История появится после первого выполненного квеста.")}
    </div>
  `;
}

function renderStatCard(stat) {
  const share = getStatShare(state, stat);
  const xp = state.stats[stat] || 0;
  const statIcon = {
    charisma: "message",
    boldness: "bolt",
    networking: "users"
  }[stat] || "target";
  return `
    <article class="stat-row stat-${stat}">
      <div class="stat-icon">${icon(statIcon)}</div>
      <div class="stat-copy">
        <div class="stat-line">
          <h2>${escapeHtml(STAT_LABELS[stat])}</h2>
          <strong>${xp} XP</strong>
        </div>
        <div class="stat-track"><span style="width:${share}%"></span></div>
      </div>
      <span class="stat-share">${share}%</span>
    </article>
  `;
}

function renderHistoryItem(item) {
  const reflectionCopy = item.reflectionSkipped ? "reflection пропущен" : `страх ${item.fear}/10`;
  return `
    <article class="history-item">
      <div>
        <p class="eyebrow">${new Date(item.createdAt).toLocaleDateString("ru-RU")}</p>
        <h2>${escapeHtml(item.questText)}</h2>
        <p>${escapeHtml(STAT_LABELS[item.statType])} · ${item.xpGained} XP · ${escapeHtml(reflectionCopy)}</p>
      </div>
      <button class="icon-button" data-action="openReflection" data-id="${item.id}" aria-label="Открыть reflection" title="Открыть">${icon("chevron")}</button>
    </article>
  `;
}

function renderReflectionDetail() {
  const item = state.reflections.find((reflection) => reflection.id === ui.selectedReflectionId);
  if (!item) return emptyState("Reflection не найден.");
  return `
    <section class="reflection-detail">
      <button class="text-button" data-action="view" data-view="profile">${icon("back")} Профиль</button>
      <article class="quest-card">
        <div class="quest-topline">
          <span>${new Date(item.createdAt).toLocaleString("ru-RU", { dateStyle: "medium", timeStyle: "short" })}</span>
          <span>${item.xpGained} XP</span>
        </div>
        <h1>${escapeHtml(item.questText)}</h1>
        <div class="profile-summary">
          <div><span>${item.reflectionSkipped ? "—" : `${item.fear}/10`}</span><p>Страх</p></div>
          <div><span>${item.reflectionSkipped ? "—" : `${item.mood}/10`}</span><p>Состояние</p></div>
          <div><span>${item.reflectionSkipped ? "—" : item.repeat ? "Да" : "Нет"}</span><p>Повторить</p></div>
        </div>
        ${item.reflectionSkipped ? `<p class="note-preview">Reflection был пропущен. XP всё равно начислен.</p>` : ""}
        ${item.note ? `<p class="note-preview">${escapeHtml(item.note)}</p>` : ""}
      </article>
    </section>
  `;
}

function renderSettings() {
  const lastSync = state.sync.lastSyncAt
    ? new Date(state.sync.lastSyncAt).toLocaleString("ru-RU", { dateStyle: "short", timeStyle: "short" })
    : "еще нет";
  const syncStatus = {
    idle: "ожидает",
    ok: "ok",
    partial: "есть ошибки"
  }[state.sync.lastSyncStatus] || state.sync.lastSyncStatus || "ожидает";

  return `
    <section class="page-heading">
      <div>
        <p class="eyebrow">Аккаунт</p>
        <h1>Настройки</h1>
      </div>
    </section>

    <section class="settings-copy">
      <div class="settings-icon">${icon("shield")}</div>
      <div>
        <h2>Безопасная рамка</h2>
        <p>MAYHEM не является медицинским продуктом и не заменяет терапию. Разбор нужен для личной рефлексии, не для диагностики.</p>
        <p>Из любой попытки можно выйти без объяснений. В кризисной ситуации нужна профессиональная помощь.</p>
      </div>
    </section>

    ${DEBUG_UI ? `<section class="settings-panel">
      <div class="group-heading"><strong>Локальный sync</strong><span>debug</span></div>
      <div class="settings-row"><span>События в очереди</span><strong>${state.sync.pendingCount || 0}</strong></div>
      <div class="settings-row"><span>Последняя синхронизация</span><strong>${lastSync}</strong></div>
      <div class="settings-row"><span>Статус проверки</span><strong>${escapeHtml(syncStatus)}</strong></div>
      <div class="settings-row"><span>Принято событий</span><strong>${state.sync.acceptedCount || 0}</strong></div>
      ${state.sync.lastSyncError ? `<p class="fineprint error-copy">${escapeHtml(state.sync.lastSyncError)}</p>` : ""}
      <p class="fineprint">В production этот слой отправляет append-only события в Supabase и обновляет cloud stats.</p>
    </section>` : ""}

    <section class="settings-panel destructive-panel">
      <div>
        <h2>Локальные данные</h2>
        <p>Удаляет прогресс и историю на этом устройстве.</p>
      </div>
      <button class="danger compact" data-action="resetProgress">${icon("trash")} Удалить</button>
    </section>
  `;
}

function renderPaywall() {
  return `
    <section class="section-head">
      <div>
        <p class="eyebrow">PRO</p>
        <h1>${state.profile.pro ? "PRO активен" : "Личный прогресс+"}</h1>
      </div>
    </section>

    <section class="pro-hero">
      <div class="brand-mark">${icon("spark")}</div>
      <h2>Больше подготовки, та же безопасная рамка</h2>
      <p>PRO не добавляет публичность, рейтинги или давление. Только личные инструменты.</p>
    </section>

    <div class="feature-list">
      <article><strong>Кубик</strong><span>3 броска в день + 1 reroll на квест.</span></article>
      <article><strong>Репетиции</strong><span>Расширенные сценарии перед сложными вызовами.</span></article>
      <article><strong>Weekly review</strong><span>Сводка прогресса без сравнений с другими.</span></article>
      <article><strong>Статистика</strong><span>Больше личных трендов и распределение XP.</span></article>
    </div>

    <button class="primary full" data-action="togglePro">${state.profile.pro ? "Отключить локальный PRO" : "Активировать локальный PRO"}</button>
  `;
}

function renderBottomNav() {
  const items = [
    ["today", "Drop", "target"],
    ["profile", "Результат", "chart"],
    ...(DEBUG_UI ? [["pro", "PRO", "spark"]] : []),
    ["settings", "Меню", "gear"]
  ];
  return `
    <nav class="bottom-nav" aria-label="Основная навигация">
      ${items.map(([view, label, iconName]) => `
        <button class="${ui.view === view ? "active" : ""}" data-action="view" data-view="${view}">
          ${icon(iconName)}
          <span>${label}</span>
        </button>
      `).join("")}
    </nav>
  `;
}

function findQuest(id) {
  return questCatalog.getQuest(id);
}

function isBossQuest(id) {
  return questCatalog.isBoss(id);
}

function isCompletedToday(id) {
  return Boolean(state.completedQuestIdsByDate[dailyQuestKey()]?.includes(id));
}

function hasCompletedQuestEver(id) {
  return state.reflections.some((item) => item.questId === id);
}

function formatDate(dateKey) {
  return new Date(`${dateKey}T12:00:00`).toLocaleDateString("ru-RU", {
    day: "numeric",
    month: "long"
  });
}

function formatUtcResetCountdown(now = new Date()) {
  const nextReset = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1);
  const remainingMinutes = Math.max(0, Math.floor((nextReset - now.getTime()) / 60_000));
  const hours = Math.floor(remainingMinutes / 60);
  const minutes = remainingMinutes % 60;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
}

function challengeCode(id) {
  let hash = 0;
  for (const char of String(id)) hash = (hash * 31 + char.charCodeAt(0)) % 1000;
  return String(hash).padStart(3, "0");
}

function emptyState(text) {
  return `<div class="empty-state">${escapeHtml(text)}</div>`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function icon(name) {
  const paths = {
    spark: "<path d='M12 2l1.7 5.1L19 9l-5.3 1.9L12 16l-1.7-5.1L5 9l5.3-1.9L12 2z'/><path d='M19 15l.9 2.6L22 18.5l-2.1.8L19 22l-.9-2.7-2.1-.8 2.1-.9L19 15z'/>",
    check: "<path d='M20 6L9 17l-5-5'/>",
    chevron: "<path d='M9 18l6-6-6-6'/>",
    back: "<path d='M15 18l-6-6 6-6'/>",
    bolt: "<path d='M13 2 3 14h9l-1 8 10-12h-9l1-8z'/>",
    globe: "<circle cx='12' cy='12' r='9'/><path d='M3 12h18'/><path d='M12 3a14 14 0 0 1 0 18'/><path d='M12 3a14 14 0 0 0 0 18'/>",
    users: "<path d='M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'/><circle cx='9' cy='7' r='4'/><path d='M22 21v-2a4 4 0 0 0-3-3.87'/><path d='M16 3.13a4 4 0 0 1 0 7.75'/>",
    moon: "<path d='M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z'/>",
    shield: "<path d='M20 13c0 5-3.5 7.5-8 9-4.5-1.5-8-4-8-9V5l8-3 8 3v8z'/><path d='m9 12 2 2 4-4'/>",
    trash: "<path d='M3 6h18'/><path d='M8 6V4h8v2'/><path d='M19 6l-1 15H6L5 6'/><path d='M10 11v6'/><path d='M14 11v6'/>",
    dice: "<rect x='4' y='4' width='16' height='16' rx='3'/><circle cx='9' cy='9' r='1'/><circle cx='15' cy='15' r='1'/><circle cx='15' cy='9' r='1'/><circle cx='9' cy='15' r='1'/>",
    play: "<path d='M8 5v14l11-7z'/>",
    pause: "<path d='M8 5v14'/><path d='M16 5v14'/>",
    x: "<path d='M18 6L6 18'/><path d='M6 6l12 12'/>",
    target: "<circle cx='12' cy='12' r='8'/><circle cx='12' cy='12' r='3'/>",
    chart: "<path d='M5 19V5'/><path d='M5 19h14'/><path d='M9 16v-5'/><path d='M13 16V8'/><path d='M17 16v-3'/>",
    gear: "<circle cx='12' cy='12' r='3'/><path d='M19 12a7 7 0 0 0-.1-1l2-1.5-2-3.4-2.4 1a7.9 7.9 0 0 0-1.7-1L14.5 3h-5l-.4 3.1a7.9 7.9 0 0 0-1.7 1l-2.4-1-2 3.4 2 1.5a7 7 0 0 0 0 2l-2 1.5 2 3.4 2.4-1a7.9 7.9 0 0 0 1.7 1l.4 3.1h5l.4-3.1a7.9 7.9 0 0 0 1.7-1l2.4 1 2-3.4-2-1.5c.1-.3.1-.7.1-1z'/>",
    book: "<path d='M4 5.5A2.5 2.5 0 0 1 6.5 3H20v17H6.5A2.5 2.5 0 0 1 4 17.5v-12z'/><path d='M8 7h8'/><path d='M8 11h8'/><path d='M6.5 20A2.5 2.5 0 0 1 4 17.5'/>",
    message: "<path d='M4 5h16v11H8l-4 4V5z'/>"
  };
  return `<svg aria-hidden="true" viewBox="0 0 24 24">${paths[name] || paths.spark}</svg>`;
}
