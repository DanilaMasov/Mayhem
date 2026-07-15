# Development Log

## 2026-07-09 - Stage 1 prototype hardening

### Starting point

- Current app is a dependency-free web/PWA prototype, not the Flutter + SQLite + Supabase MVP from PRD v3.1.
- Previous audit is documented in `mayhem_audit_and_fix_plan.md`.
- No local Git repository is available in this workspace, so this file records recoverable implementation context.

### Scope for this iteration

Bring the existing prototype closer to PRD behavior before a larger Flutter migration:

1. Canonicalize event names toward the PRD analytics/event-log vocabulary.
2. Fix onboarding order so the first quest is accessible before the medical disclaimer gate.
3. Add Reflection skip while still granting XP.
4. Fix navigation scroll carry-over and toast overlap.
5. Move the prototype visual language toward PRD dark mode.
6. Tighten quest-pool validation and remove reused IDs from the PRD deleted list.
7. Update tests and README to make prototype scope explicit.

### Decision notes

- The current code stores history in `state.reflections`; a larger split into `completed_quests` and `quest_reflections` belongs to the Flutter/SQLite migration. For this prototype, skipped reflection creates a history record marked `reflectionSkipped: true`, but no `reflection_submitted` event.
- Event names are updated in-place, with normalization for old localStorage events where feasible.

### Implemented changes

- Updated domain events:
  - `quest_abandoned` -> `quest_failed` with `failReason: "escape"`.
  - `modifier_rolled` -> `dice_rolled` with `isPro`.
  - Added `reflection_submitted` for submitted reflections.
  - Added `boss_raid_participated` for Boss Raid completion.
- Changed onboarding order:
  - Fresh users now land directly on Today/first quest.
  - Not-medical disclaimer gate appears after the first offline quest completion.
- Added Reflection skip:
  - XP is still granted.
  - History marks the item as `reflectionSkipped`.
  - No `reflection_submitted` event is emitted for skipped reflection.
- Added navigation scroll reset and cleared stale toasts when moving between screens.
- Reworked the prototype visual theme toward PRD dark mode.
- Removed reused IDs from the PRD deleted quest list and fixed quest-pool balance:
  - Total levels: 18 level-1, 22 level-2, 10 level-3.
  - Offline stat distribution: 15 Charisma, 12 Boldness, 10 Networking.
  - 13 Shadow quests retained.
- Updated README, manifest theme color, and CSS cache version.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Static checks:
  - No deleted v2 quest IDs are reused in `src/data.js`.
  - No light-mode `color-scheme` remains.
  - Quest level / energy invariants pass for offline quests.
- Browser checks:
  - Mobile viewport `390x844`: no horizontal overflow, first screen opens Today without disclaimer gate, Reflection skip visible, post-first-quest disclaimer gate appears, stale toast no longer follows into Reflection.
  - Desktop viewport `1280x720`: no horizontal overflow, dark phone-frame layout renders.
  - Browser console errors/warnings: none.

### Visual artifacts

- `artifacts/stage1-today-dark-mobile.png`
- `artifacts/stage1-reflection-dark-mobile.png`
- `artifacts/stage1-today-dark-desktop.png`

## 2026-07-09 - Stage 1B guide and NPC hardening

### Scope

Reduce two remaining prototype mocks without pretending that production content is complete:

1. Quest Guide should open as an explicit user action and log `guide_opened`.
2. Guide should collapse after a quest type has already been completed.
3. NPC training should become a small node/options simulator instead of one click granting +10% XP.

### Decision notes

- PRD requires 50 fully curated guides. That is a content-production task, not a code shortcut. This iteration adds the correct data shape and curated overrides for key onboarding/boss-thanks scenarios, plus category-specific fallback content. The production content track still needs a full xlsx/JSON source.
- NPC dialogs are structured in `src/data.js` as `startNodeId` + `nodes` + `options`, matching the PRD direction without introducing a backend or SQLite yet.

### Implemented changes

- Added guide metadata and curated guide overrides for `q_c_001` and `boss_thanks_barista`.
- Added category-specific guide steps for gratitude, recommendations, light compliments, clarifying questions, small talk, and Shadow.
- Added `openQuestGuide()` domain mutation with `guide_opened` event.
- Added `NPC_DIALOGS` and `getNpcDialogForQuest()`.
- Replaced one-click NPC training with a dedicated `npcTraining` screen and choice buttons.
- Kept `npc_training_completed` as the reward/buff event after a successful dialog path.
- Added a compact guide state in quest detail; card-level `Как выполнить?` opens the full guide.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Added tests for:
  - guide shape and `guide_opened` event.
  - NPC dialog start node/options.
  - `npc_training_completed` event and `npcTrained` flag.
- Browser checks:
  - Mobile viewport `390x844`: curated guide opens from Today, has no horizontal overflow, starts at top of screen, shows phrases and `curated` marker.
  - NPC training flow screenshots were captured during the implementation pass.
  - Browser console errors/warnings: none.

### Visual artifacts

- `artifacts/stage1b-guide-mobile.png`
- `artifacts/stage1b-npc-start-mobile.png`
- `artifacts/stage1b-npc-done-mobile.png`

## 2026-07-09 - Stage 1C event log and preparation-state hardening

### Scope

Move the prototype away from fake sync while staying honest about the missing production backend:

1. Add a local MVP sync contract for append-only events.
2. Add client sequence, event schema fields, validation status, and sync counters.
3. Add idempotent duplicate handling for retried event IDs.
4. Stop treating NPC training and dice rolls as implicit `quest_started`.
5. Require a real started quest before `quest_completed` or `quest_failed`.

### Decision notes

- Implementing a pretend Supabase server inside the static prototype would hide the real production gap. The better prototype step is a deterministic local sync contract that mirrors the PRD MVP rules: append-only, dedupe, basic validation, and incremental counters.
- Preparation actions now live in `state.prep`, not `state.activeQuest`. `startQuest()` attaches prepared NPC training/modifier to the actual active attempt. This keeps analytics truthful: `dice_rolled` and `npc_training_completed` are preparation events, not starts.
- Shadow quests also require pressing Start before Reflection. This matches the event-log rule that `quest_completed` must have a preceding `quest_started`.

### Implemented changes

- Added event fields:
  - `eventType`
  - `clientSequence`
  - `modifierId`
  - `xpDelta`
  - `energyDelta`
  - `metadata`
  - `syncStatus`
  - `syncError`
- Added `syncPendingEvents()` with:
  - known event type validation;
  - quest ID validation;
  - `quest_completed` requires `quest_started` in the last 24 hours;
  - XP delta validation against quest pool and Boss/NPC multipliers;
  - non-negative `energyAfter` validation;
  - duplicate event ID dedupe.
- Replaced app-level `simulateSync()` with `syncPendingEvents()`.
- Added `state.prep.npcTrainedByQuestId` and `state.prep.modifiersByQuestId`.
- Updated quest detail buttons so `Выполнено` and `Сбежать` stay disabled until the quest is actually started.
- Added sync status / accepted event counters in Settings.
- Bumped CSS cache version to `v=8`.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Syntax checks:
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/app.js`
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/game.js`
- Browser checks:
  - Mobile viewport `390x844` with `qa-seed.html`: Today renders with no horizontal overflow.
  - Level-2 quest detail before Start: NPC and cube are available; Start is available; `Выполнено` and `Сбежать` are disabled.
  - Browser console errors/warnings: none.
  - Browser locator-click on the cube button timed out inside the browser automation runtime; the dice preparation behavior is covered by unit tests and the pre-start UI state was visually captured.

### Visual artifacts

- `artifacts/stage1c-prep-before-start-mobile.png`

## 2026-07-09 - Stage 1D daily-window timing

### Scope

Align prototype calendar behavior with PRD timing rules:

1. Local daily quests refresh at `12:00` local time, not at local midnight.
2. Boss Raid participation is keyed by UTC day.
3. UI date and completed-state use the same active daily window key.

### Decision notes

- `todayKey()` remains a plain local calendar helper for dice and formatting.
- New `dailyQuestKey()` represents the active quest window: before noon it returns the previous local date; at noon and later it returns the current local date.
- Boss selection already used `utcDayKey()`. Participation dedupe now uses the same UTC key, avoiding local-date drift around midnight/time zones.

### Implemented changes

- Added `dailyQuestKey()`.
- Updated daily state initialization and `refreshDailyQuests()` to use the noon-based key.
- Updated `completeQuest()` and `isCompletedToday()` to store/read local quest completion by `dailyQuestKey()`.
- Updated Boss Raid local participation storage and participant count bump to use `utcDayKey()`.
- Updated Today header date to show the active daily window.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Syntax checks:
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/app.js`
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/game.js`
- Added tests for:
  - no local daily refresh before `12:00`;
  - daily switch at `12:00`;
  - stable quest IDs across the pre-noon continuation window;
  - Boss Raid participation keyed by UTC day.

## 2026-07-10 - Stage 2A state integrity and debug UI isolation

### Scope

Close state-corruption and reward-forging paths before adding more features, then separate the user-facing prototype from internal product mocks:

1. Refresh local quests and the shared quest on their independent clocks without losing cooldown or dice state.
2. Prevent a second quest from overwriting the active attempt.
3. Validate completion prerequisites, canonical rewards, and energy transitions during local sync.
4. Keep debug-only PRO, sync, pending, and participant mocks out of the normal experience.
5. Keep primary quest actions visible above the mobile bottom navigation.

### Decision notes

- The old refresh rebuilt the entire `daily` object whenever either clock changed. That coupled unrelated state and could clear cooldown/dice data. Local daily selection and the UTC shared quest now refresh independently; cooldown is top-level state.
- Reward multipliers are server/domain facts, not UI input. Boss identity is stored on canonical boss records, while the NPC bonus requires recorded preparation. `completeQuest()` no longer trusts caller-provided `isBoss` or `npcTrained` flags.
- A static frontend cannot provide real anti-cheat or cloud authority. The local validator is intentionally a deterministic contract prototype, not a substitute for Supabase Edge Functions and database constraints.
- Fake global participant counts and local billing/sync controls are useful for QA but misleading in a user test. They now require `?debug=1`; the normal UI uses the honest label `Общий квест`.

### Implemented changes

- Raised state schema to v2 and migrated legacy `daily.cooldownUntil` to top-level `cooldownUntil`.
- Added independent `daily.bossDate`; local quests refresh at local noon and the shared quest at UTC midnight.
- Preserved cooldown and dice state across daily refreshes.
- Added active-attempt guards to `startQuest()`.
- Hardened `validateEventForSync()`:
  - completion/failure requires a prior start for the same quest;
  - Boss identity must match the canonical quest map;
  - NPC bonus requires a prior `npc_training_completed` event within 24 hours;
  - XP is recomputed from canonical data;
  - energy before/delta/after transitions are validated.
- Added canonical `isBoss: true` to Boss quest records and removed caller authority over Boss/NPC reward flags.
- Moved Start, Done, and Escape into a sticky mobile action bar above bottom navigation.
- Reduced normal navigation to Today, Profile, and More; debug mode retains the PRO tab and internal controls.
- Updated `qa-seed.html` to enter `?debug=1` explicitly and bumped CSS cache to `v=9`.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Added regression tests for:
  - independent UTC Boss refresh;
  - cooldown survival across local noon refresh;
  - active quest overwrite prevention;
  - forged Boss and NPC reward rejection;
  - valid NPC training reward and sync sequence;
  - caller-provided Boss/NPC flags being ignored by domain completion.
- Syntax checks:
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/app.js`
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/game.js`
- Browser checks:
  - Mobile viewport `390x844` in debug mode: no horizontal overflow; Start, Done, and Escape remain fully visible above navigation.
  - Mobile viewport `390x844` in normal mode: three navigation items, no horizontal overflow, no PRO/sync/pending controls, no mock participant count, and the user-facing `Общий квест` label is present.
  - Normal Settings contains no local sync or PRO controls.
  - Desktop layout evaluation at `1280x720`: no horizontal overflow; the 430px app shell and navigation are centered with visible DOM geometry. The embedded browser's screenshot capture stayed clipped to its 333px host pane after viewport emulation, so the desktop result is geometry/DOM-verified rather than accepted from the blank clipped image.
  - Browser console errors/warnings: none.

## 2026-07-10 - Stage 2B safe defer policy

### Scope

Replace the punitive Empathic Fail contract across product, state, events, UI, analytics, and documentation:

1. Remove the double energy charge and global one-hour cooldown.
2. Replace the user-facing Escape action with a neutral Defer action.
3. Preserve completed NPC preparation and rolled modifiers after deferral.
4. Keep old `quest_failed` events recoverable while introducing truthful `quest_deferred` analytics.
5. Prevent the new sticky action bar and toast from overlapping on mobile.

### Decision notes

- The v3.1 fail rule contradicted the product's right-to-refuse and calm-tone principles: declining a difficult social action cost more energy than completing it and blocked every other quest. For the target audience this creates avoidable shame/churn risk and contaminates `fail_rate` with voluntary pauses.
- v3.2 treats "not now" as a reversible state transition, not a failure. Energy and access remain unchanged, while attempt duration still provides a useful quest-difficulty signal.
- `quest_failed` remains in the accepted event set for timeout/system/legacy records. This preserves append-only history and allows pending v2 events to sync under their original 2x-energy contract.

### Implemented changes

- Updated the source PRD from v3.1 to v3.2 across core loop, energy rules, SQL schemas, event validation, analytics, roadmap prompts, ethical boundaries, and version history.
- Raised local state schema to v3 and removed both top-level and legacy `daily.cooldownUntil` during normalization.
- Replaced `abandonQuest()` with `deferQuest()`:
  - no energy delta;
  - no cooldown;
  - active attempt is released;
  - NPC training and modifier preparation are preserved;
  - immediate restart is allowed.
- Added `quest_deferred` with `deferReason`, `attemptDurationSeconds`, `hadNpcTraining`, `modifierId`, and energy transition metadata.
- Extended local sync validation to require:
  - prior `quest_started` within 24 hours;
  - canonical `not_now` reason;
  - duration matching the preceding start timestamp;
  - zero energy delta.
- Kept legacy `quest_failed` energy validation for recovery compatibility.
- Replaced `Сбежать` with `Отложить` for regular, Boss, and Shadow attempts.
- Added a pause icon and made Shadow attempts safely closable.
- Moved quest-view toasts above the sticky action bar and bumped CSS cache to `v=11`.
- Updated README and the audit/fix plan to reflect current prototype status.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Added regression tests for:
  - zero-cost defer and immediate restart;
  - preservation of NPC/modifier preparation;
  - schema v2 cooldown removal;
  - regular and Shadow deferral;
  - accepted valid defer sync;
  - rejected forged defer energy/duration;
  - accepted legacy penalized fail sync.
- Mobile browser checks at `390x844`:
  - `Выполнено` and `Отложить` are fully visible above navigation;
  - no `Сбежать` copy remains in normal mode;
  - energy stays at 100% after defer and the quest can be opened again;
  - no horizontal overflow;
  - final toast/action gap is 19.95px; action/navigation gap is 53.05px.
- Desktop geometry at `1280x720`:
  - app shell and navigation are centered at x=425 with width=430;
  - no horizontal overflow.
- Browser console errors/warnings: none.

## 2026-07-10 - Stage 2C visual system rebuild

### Scope

Pause the feature roadmap and rebuild the reference UI around product clarity and repeated daily use:

1. Make quests horizontal, compact, and scannable.
2. Put the shared quest first and separate it from personal quests without turning it into a promotional hero.
3. Remove repeated large cards, rings, and full-width CTA stacks.
4. Carry one visual system through Today, quest detail, Profile, and Settings.
5. Verify long Russian content and fixed actions across narrow, standard, intermediate, and desktop widths.

### Audit findings

- The old Today screen spent most of the viewport on two local cards and repeated `Открыть` / `Как выполнить?` text buttons. The shared quest was below them and often outside the first viewport.
- Dark green was used for the page, shell, cards, buttons, progress, and accents, so hierarchy depended mostly on borders and size.
- Profile repeated three large ring cards plus another summary card; Settings framed long legal copy as another card.
- Quest detail repeated the same oversized card and could push the primary Start action below the initial viewport.
- The old mobile CSS contained a duplicated malformed `.topbar` rule and forced content cards to `100vw - 64px`.

### Design decisions

- Adopt a neutral graphite base instead of a green monochrome theme. Mint is reserved for primary progress/actions; gold identifies the shared quest; coral and blue distinguish stats.
- Use solid surfaces and restrained borders. No decorative gradients, orbs, marketing hero, fake social proof, or exaggerated product copy.
- Quest rows use a stable three-column layout: semantic icon, flexible text, and two icon actions with accessible labels/tooltips.
- The shared quest is the first list group and has a small gold separation band; personal quests remain visually equal choices below it.
- Primary quest actions are fixed inside the app shell above navigation, while content reserves enough bottom space.

### Implemented changes

- Rebuilt `src/styles.css` as a single coherent design system and removed the malformed mobile rule.
- Reworked the top HUD into a compact horizontal energy/XP band.
- Replaced vertical quest cards with horizontal `quest-row` blocks.
- Moved the shared quest before local quests and added explicit shared/personal grouping.
- Replaced two large text CTAs per row with guide/open icon buttons and accessible names.
- Added stat-specific icon/color tokens for Charisma, Boldness, and Networking.
- Rebuilt quest detail as a concise quest brief with persistent Start/Done/Defer actions.
- Replaced Profile rings/cards with one summary and flat stat progress rows.
- Rebuilt Settings as flat safety/data sections instead of stacked cards.
- Added focus-visible treatment, reduced-motion handling, and stable shell-relative action widths.
- Bumped CSS cache version to `v=14`.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node tests/game.test.mjs`
  - Result: `All game rules passed.`
- Syntax check:
  - `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --check src/app.js`
- Browser QA:
  - `320x720`: quest rows remain within 288px content width; no horizontal overflow; long rows grow vertically instead of clipping text.
  - `390x844`: shared quest appears first; all three daily quests are visible in the initial viewport; shell and navigation use the full width without overflow.
  - `439x844`: 390px shell is centered; fixed action bar aligns to its 16px content inset.
  - `1280x720`: shell/navigation are centered at x=425 with width=430; quest rows stay within the 388px content width.
  - Active Boss attempt: Done and Defer fit side by side; action bar ends at y=770 and navigation begins at y=771.
  - Browser console errors/warnings: none.
- Static visual scan:
  - no gradient/orb rules;
  - no duplicate `.topbar` block;
  - no horizontal overflow in tested viewports.

## 2026-07-11 - Stage 2D MAYHEM direction and Daily Drop rebuild

### Trigger

The graphite rebuild fixed hierarchy but still communicated a cautious self-care tracker. The product needed a harder challenge contract and a stronger first-viewport identity without becoming a prank app or using workers and random bystanders as reaction props.

### Product decisions

- Repositioned the prototype as `MAYHEM // SOCIAL CHALLENGE`: a daily social-courage challenge, not a therapy companion.
- Made one global `Daily Drop` the primary ritual and renamed the two local choices `Backup Runs`.
- Defined hardness as initiative, a real possibility of refusal, taking a position, entering a group, and ending a contact deliberately.
- Rejected sexual/profane shock prompts, hidden recording, humiliation, pressure after refusal, and challenges aimed at captive workers.
- Kept a penalty-free exit from an active attempt. This protects consent and recovery without softening the challenge itself.
- Preserved challenge IDs and event contracts so existing local progress remains recoverable.

### Implemented changes

- Added `mayhem_brand_and_challenge_direction_v1.md` with category, competitor scan, safety boundaries, visual rules, monetization hypothesis, and pilot metrics.
- Rebranded document title, web manifest, onboarding gate, top bar, navigation, settings, and README to MAYHEM.
- Added a deterministic Daily Drop code and a live countdown to the next UTC reset.
- Replaced pastel graphite accents with a black/white, signal-red, safety-yellow, and cyan system; reduced radii to 1–3px and removed translucent blur styling.
- Rewrote all five global Boss challenges around group entry, direct invitations, clear opinions, deliberate contact, and explicit requests to join.
- Rewrote the first run plus every level 2 and level 3 backup challenge to remove service-worker scripts and require player initiative.
- Changed post-first-completion backup selection from levels 1+2 to levels 2+3.
- Replaced joke modifiers with pressure constraints: start within five seconds, no apology preamble, two-minute contact, one-sentence delivery, and clean exit.
- Renamed user-facing `Low-pressure`, `Advanced`, `Quest Guide`, `NPC training`, Start/Done/Defer language to another route, escalation, analysis, rehearsal, Accept/Close/Leave.
- Added content regression checks preventing sexual shock and captive-worker targeting from entering the global Daily Drop pool.
- Bumped the CSS cache version to `v=15`.

### Verification

- Unit tests: `/Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --test tests/game.test.mjs`
  - Result: pass, no failed or skipped tests.
- Browser QA:
  - `320x720`: no horizontal overflow; title wraps cleanly; Daily Drop remains first; fixed CTA and three-item navigation remain visible.
  - `390x844`: the entire daily stack renders in a single coherent hierarchy; no clipped challenge text.
  - `1280x900`: 430px app shell and navigation are centered at x=425; no page overflow.
  - Normal mode hides PRO, mock participants, and sync controls.
  - Route switch changes the displayed challenge copy.
  - Accept changes actions to Close/Leave; Leave returns to Today, keeps energy at 100%, and shows the recovery toast.
  - Browser console errors/warnings: none.

## 2026-07-11 - Stage 2E architecture hardening

### Scope

Freeze visual iteration and improve the reference prototype's module boundaries, data recovery, event-log complexity, content integrity, and honesty about production scalability.

### Audit findings

- `app.js` owned browser storage and the minute maintenance timer directly, making a future SQLite adapter unnecessarily invasive.
- `syncPendingEvents()` scanned all accepted events for every completion/defer/failure prerequisite. Large offline journals therefore approached O(N²).
- Pending events were validated in array order; a merged or restored batch could reject a valid completion placed before its start in the array.
- Quest records were consumed directly from arrays with no runtime schema validation before daily selection.
- The prior architecture audit had become historical and contained already-fixed gaps.
- Two hard-content rewrites could be read as sitting down next to strangers, conflicting with the PRD's explicit boundary against unsolicited table intrusion.

### Implemented changes

- Added `src/infrastructure/state-repository.js`:
  - versioned storage envelope;
  - legacy raw-state loading;
  - previous-state backup;
  - `primary -> backup -> default` recovery;
  - non-throwing storage failure results and privacy-safe diagnostics;
  - primary + backup deletion.
- Removed direct `localStorage` reads/writes from `app.js`; UI now uses repository `load/save/clear` boundaries.
- Added `src/application/maintenance-loop.js` with injected clock, scheduler, state refresh, sync, persistence and render decisions.
- Replaced the inline UI `setInterval` with the testable maintenance service.
- Reworked event sync:
  - chronological sort by timestamp, client sequence and ID;
  - O(1) prior-event lookup through a `questId + eventType` index;
  - valid out-of-array-order offline batches are processed correctly;
  - total local complexity is O(N log N), dominated by sorting.
- Added `src/domain/quest-catalog.js`:
  - structural validation for quests, bosses and modifiers;
  - duplicate ID checks;
  - level/stat/energy/variant validation;
  - indexed quest and Boss lookup.
- Corrected three challenge routes to require an explicitly open event context instead of sitting with strangers.
- Added `mayhem_architecture_review_v2.md` and marked the older audit as historical.
- Updated `npm test` to execute every `*.test.mjs` suite.

### Verification

- Full suite: `node --test tests/*.test.mjs`.
- Added tests for:
  - legacy storage migration into a versioned envelope;
  - backup recovery after corrupt primary JSON;
  - graceful quota/write failure;
  - maintenance loop scheduling and dependency orchestration;
  - catalog lookup and invalid payload rejection;
  - reversed 10,000-event offline journal.
- Load result on the current machine: 10,000 events validated and marked synced in roughly 26 ms.
- Existing game-rule regression suite remains green.
- Browser smoke after migration:
  - legacy local state reloads through the repository adapter;
  - opening a guide creates and persists a new event;
  - a full page reload restores the Today screen;
  - Daily Drop and bottom navigation render without horizontal overflow;
  - browser console errors/warnings: none.

## 2026-07-11 - Stage 3A Flutter mobile foundation

### Direction

The production target is now explicitly iOS/Android. The root web app remains a reference prototype; new product implementation lives in `mobile/`.

### Toolchain

- Installed Flutter 3.44.6 and Dart 3.12.2; disabled Flutter analytics.
- Created an official Flutter project with generated Android and iOS runners.
- Added `sqflite`, `path` and `uuid`.
- Installed and configured OpenJDK 21 without a system-level sudo symlink.
- Installed Android command-line tools.
- Did not accept the Google Android SDK license on the user's behalf. API 36, platform-tools and build-tools remain pending explicit user approval.
- iOS device build remains blocked by incomplete Xcode and missing CocoaPods on the machine.

### Implemented mobile vertical slice

- Added a versioned mobile content asset at `mobile/assets/content/quest_catalog.json`.
- Added strict quest parsing and catalog validation before app startup.
- Added pure Dart models for quests, daily selection, active attempt, state and canonical events.
- Added a deterministic `GameEngine` with:
  - local-noon and UTC daily keys;
  - first-use L1+L2 and progressed L2+L3 selection;
  - energy regeneration in complete ten-minute ticks;
  - 20% regular-challenge gate;
  - Accept, Defer and Complete transitions;
  - Boss ×2 XP, reset energy reward and one-completion-per-day protection;
  - `normal / low_pressure` route persistence;
  - attempt duration metadata.
- Added the `GameStore` domain port.
- Added `SqfliteGameStore` with a state snapshot and append-only `quest_events` table.
- State and emitted events are committed in a single SQLite transaction; event IDs are idempotent primary keys.
- Added `TodayController` as the application boundary between widgets and domain/storage.
- Replaced the generated counter with native Flutter Today and Quest Detail screens.
- Added working main/alternate route control and Accept/Complete/Leave actions.
- Added a safe bootstrap failure screen instead of leaving a blank app on catalog/SQLite startup failure.
- Set Android/iOS display name to MAYHEM and locked the first slice to portrait phone orientation.

### Verification

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --no-test-assets -j 1`: 6 tests passed.
- Tests cover:
  - deterministic daily selection and progression;
  - canonical start/defer/complete lifecycle;
  - zero-energy-delta defer;
  - route persistence;
  - Boss reward and daily replay protection;
  - tick-based energy regeneration;
  - the 20% regular-challenge gate;
  - parsing and validation of the bundled mobile catalog asset;
  - a 390×844 widget flow from Today to an accepted Daily Drop.
- Standard `flutter test` currently crashes inside Flutter 3.44.6 `impellerc` while compiling the framework `ink_sparkle.frag` test asset. Running without test assets isolates this tooling failure; the test suite itself passes.
- APK/IPA not built yet because platform toolchain licenses/installations are incomplete, not because of Dart analysis errors.

## 2026-07-11 - Stage 3B mobile Reflection slice

### Constraints

- No new packages, SDKs or platform components were installed.
- Android SDK licenses remain unaccepted.
- Dart analysis cache was redirected to `/private/tmp/mayhem-dart` to avoid writing `.dartServer` state into the user's home directory.

### Implemented

- Added `ReflectionDraft` validation and immutable `QuestReflection` records.
- Added canonical `reflection_submitted` events without placing the private note in analytics payload metadata.
- Extended `GameTransition` to carry reflection records beside state and events.
- Extended `GameStore.commit()` so snapshot, completion events and reflection records share one transaction boundary.
- Raised the mobile SQLite schema to v2.
- Added `quest_reflections` with score constraints, repeat boolean constraint and a v1→v2 migration.
- Added a native Reflection screen with:
  - tension-before score 1–10;
  - state-after score 1–10;
  - repeat yes/no segmented control;
  - optional 240-character private note;
  - top-right skip action;
  - disabled controls while a commit is in progress.
- System back from Reflection keeps the attempt active; Submit or Skip performs completion.
- Skip still grants canonical XP and energy changes but creates no fake reflection row or `reflection_submitted` event.
- Persisted `normal / low_pressure` route and attempt duration remain attached to completion.

### Verification

- Direct Dart analyze with temporary cache: no issues found.
- Flutter tests: 7 passed.
- Added coverage for filled reflection records/events and skipped reflection behavior.
- The 390×844 widget flow now covers Today → Detail → Accept → Reflection → Skip → Today and verifies the Boss energy deduction.

## 2026-07-11 - Stage 3C mobile Quest Guide slice

### Constraints

- No packages, SDKs, licenses or system tools were added.
- Formatting and analysis used the existing Dart SDK with analyzer state redirected to `/private/tmp/mayhem-dart`.

### Implemented

- Added `assets/content/guide_catalog.json` as a separate schema-versioned content source.
- Added 12 guide records covering every quest and Boss in the current mobile seed.
- Each guide contains exactly three steps, 3–5 working phrases, an alternate route, an escalation and a clean exit script.
- Added immutable `QuestGuide` and indexed `GuideCatalog` domain models.
- Added validation for schema version, duplicate guide IDs, duplicate quest links, step/phrase counts and non-empty content.
- Added cross-catalog coverage validation at bootstrap:
  - missing guide for a quest fails startup into the safe bootstrap error screen;
  - guide pointing to an unknown quest also fails validation.
- Added canonical `guide_opened` to the mobile event contract.
- Added a pure `GameEngine.openGuide()` transition that emits an event without mutating game state.
- `TodayController.openGuide()` persists the event before opening presentation.
- Added native Quest Guide UI with numbered route steps, phrase blocks, alternate route, escalation and clean exit.
- Quest Detail now exposes an explicit `ОТКРЫТЬ РАЗБОР` command.

### Verification

- Direct Dart analyze with temporary cache: no issues found.
- Flutter tests: 9 passed.
- Added tests for:
  - parsing the bundled guide asset;
  - exact guide coverage of the mobile quest catalog;
  - canonical `guide_opened` transition with unchanged state;
  - widget navigation Detail → Guide → Detail;
  - persistence of `guide_opened` before guide presentation.

## 2026-07-11 - Stage 3D mobile branching rehearsal

### Constraints

- No packages, SDKs, licenses or system tools were added.
- Existing Dart/Flutter tooling only; analyzer state remained in `/private/tmp`.

### Implemented

- Added `assets/content/dialog_catalog.json` with eight rehearsal graphs covering every current level 2/3 and Boss challenge.
- Added immutable dialog models for speakers, nodes, options and per-quest scenarios.
- Added graph validation:
  - unique dialog and node IDs;
  - existing start node;
  - every option resolves to a real node;
  - non-success nodes cannot be dead ends;
  - success nodes cannot expose further choices;
  - all nodes must be reachable;
  - at least one reachable success node is required.
- Added cross-catalog coverage validation for every rehearsal-eligible mobile quest.
- Raised the mobile `GameState` schema to v2 and added persisted `trainedQuestIds`.
- Added `npcTrained` to the active attempt snapshot.
- Added canonical `npc_training_completed` with dialog ID and 10% buff metadata.
- Rehearsal preparation now:
  - survives Safe Defer;
  - is copied into the next active attempt;
  - grants a rounded +10% XP bonus;
  - clears only after successful completion.
- Added `TodayController` dialog lookup and training completion use case.
- Added native branching Rehearsal UI with NPC/Coach states and explicit successful finish.
- Quest Detail exposes rehearsal only for eligible quests, disables it during an active attempt and shows `РЕПЕТИЦИЯ ГОТОВА` after success.

### Verification

- Direct Dart analyze with temporary cache: no issues found.
- Flutter tests: 11 passed.
- Asset tests parse all dialog graphs and verify exact eligible-quest coverage.
- Domain tests verify event emission, defer persistence, 10% Boss reward (`280 → 308 XP`) and preparation cleanup.
- The 390×844 widget flow now covers Guide → Rehearsal → Accept → Reflection Skip → Today and verifies final energy and XP.

## 2026-07-11 - Stage 3E complete mobile content pipeline

### Constraints

- No packages, SDKs, licenses or system tools were installed or changed.
- Export and web verification used the existing workspace Node runtime.
- Dart analysis kept analyzer state in `/private/tmp/mayhem-dart`; Flutter tests used the existing SDK with asset compilation disabled because of the known framework `impellerc` crash.

### Findings corrected before migration

- The canonical source still used five obsolete Boss IDs whose names described removed v2 content rather than the current challenges. Replaced them with semantic IDs: `boss_group_entry`, `boss_clear_position`, `boss_direct_invite`, `boss_contact_exit` and `boss_join_space`.
- Added state normalization for every obsolete Boss ID across daily selection, active attempts, prepared modifiers/NPC training, dice rerolls, completion history, participant counters, reflections and pending events. Existing local prototype progress therefore remains recoverable.
- `q_c_001` is selected explicitly as the first quest, but had drifted into an event-introduction challenge. Restored the PRD's zero-friction first success: a short, warm thank-you after an already completed ordinary interaction.
- Repaired the stale `q_c_001` and Boss guide overrides so their steps, phrases and exit scripts match the actual quest content.

### Implemented

- Added dependency-free `scripts/export_mobile_content.mjs` as the single deterministic JS → mobile content pipeline.
- Added `npm run content:export` and read-only `npm run content:check` commands.
- Exported all 50 quests, 5 Boss challenges, 55 guide records and 29 rehearsal graphs into schema-versioned mobile JSON.
- Every generated guide and dialog receives a quest-specific stable ID even when its text comes from a shared category template.
- Added exact source/generated equality tests, so manual JSON drift now fails CI.
- Added the bundled schema-v1 release contract at the asset-loader boundary:
  - exactly 50 quests, 5 bosses and 13 Shadow quests;
  - exact PRD level distribution `18 / 22 / 10`;
  - exact offline stat distribution `15 / 12 / 10`;
  - canonical energy, Boss and Shadow invariants.
- Kept the base `QuestCatalog` structurally validated but independent of release counts, preserving small test catalogs and future remote adapters.

### Honest content boundary

- Structural coverage is complete, but editorial curation is not: most guides and rehearsal graphs currently use category-aware templates from the canonical source. A dedicated per-quest copy and safety pass remains before production release.

### Verification

- Deterministic content check: 50 quests, 5 bosses, 55 guides and 29 dialogs verified without file changes.
- Root Node suite: 7 tests passed, including source/mobile equality, legacy Boss-ID migration and the existing 10k-event sync bound.
- Direct Dart analyze: no issues found.
- Flutter tests: 11 passed, including full bundled-contract parsing, exact guide coverage and exact eligible-dialog coverage.

## 2026-07-12 - Stage 3F mobile modifier dice

### Priority decision

- Modifier Dice was selected as the next P0 because it was the only missing preparation mechanic in the local core loop.
- Event-derived snapshot rebuild remains the next P0; modifier state and events were designed now so rebuild will not require a contract rewrite.
- The PRD's literal Capybara/Robot/Echo behavior was not copied into mobile. Those instructions make third parties part of a joke and conflict with Safety by Design. Stable analytics IDs remain, while the canonical project uses safe constraints on the player's own timing, clarity and exit.

### Constraints

- No packages, SDKs, licenses or system tools were installed or changed.
- The existing Node, Dart and Flutter runtimes were used; Flutter tests continued with `--no-test-assets` because of the known framework shader compiler crash.

### Implemented

- Added a schema-versioned five-record `modifier_catalog.json`, generated from the canonical JS source and included in deterministic content equality checks.
- Added immutable `QuestModifier` and indexed `ModifierCatalog` domain models with bundled release validation.
- Raised mobile `GameState` to schema v3 with backward-compatible v2 loading.
- Added persisted calendar-day dice state and per-quest prepared modifier IDs.
- Active attempts now pin `modifierId`; NPC preparation updates preserve it.
- Added the canonical `dice_rolled` event with `modifierId` and `isPro: false`.
- Free users receive exactly one roll per local calendar day. Rolls are blocked after attempt start, on completed quests and for Shadow quests.
- Modifier preparation survives Safe Defer, is restored into the next attempt and clears only after successful completion.
- `quest_started`, `quest_deferred` and `quest_completed` now carry the same modifier ID for analytics and future event-log rebuild.
- Quest Detail now renders the selected constraint, daily allowance and stable disabled states without layout shifts or double-submit races.

### Verification

- Deterministic content check: 50 quests, 5 bosses, 55 guides, 29 dialogs and 5 modifiers.
- Root Node suite: 7 tests passed.
- Direct Dart analyze: no issues found.
- Flutter tests: 16 passed.
- New coverage verifies v2→v3 migration, daily reset, second-roll rejection, Shadow rejection, UI persistence, defer survival and completion cleanup.

## 2026-07-12 - Stage 3G event-derived mobile recovery

### Priority decision

- Snapshot recovery was the second P0 because append-only storage is not a source of truth until the application can actually rebuild from it.
- The snapshot remains a transactional UI cache. When the journal contains events, bootstrap deterministically rebuilds domain state and rewrites the cache.

### Implemented

- Extended `GameStore` with ordered event-journal loading and implemented it in SQLite and the test adapter.
- Added strict database-row parsing for event type, identifiers, timestamp and JSON payload. Unknown event types or malformed payloads fail explicitly instead of being silently ignored.
- Added a pure `GameStateRebuilder` domain service with deterministic `createdAt + id` ordering.
- Rebuild now restores:
  - XP and energy;
  - completion counts and per-day completion IDs;
  - active attempt, selected route and start time;
  - NPC preparation and its +10% flag;
  - prepared/active modifier ID and calendar-day dice allowance.
- Completion is semantically idempotent per quest/day, preventing a distinct duplicate event ID from applying XP or energy twice locally.
- Added `completionKey` and `diceDate` to new event payloads so local-calendar decisions survive UTC persistence exactly.
- Bootstrap now exposes a diagnostic `loadSource`: `fresh`, `snapshot`, `event_log`, `event_log_recovery` or `failed`.
- A malformed snapshot no longer loses progress when a valid journal exists: controller rebuilds, logs `[mayhem-recovery]`, refreshes deterministic daily selection and atomically repairs the snapshot.

### Boundaries

- Local rebuild covers the current mobile event contract. Multi-device conflict resolution, server acknowledgements and detection of a partially missing journal remain part of the Supabase sync P1.
- Existing journals without the new explicit local date fields use deterministic timestamp fallbacks; all newly emitted events preserve the exact keys.

### Verification

- Direct Dart analyze: no issues found.
- Flutter tests: 20 passed.
- Recovery coverage includes reversed journal ordering, active prepared attempts, duplicate completion protection, broken-snapshot bootstrap and unknown database event rejection.

## 2026-07-12 - Stage 3H guided onboarding and local profile

### Product decisions

- The first screen is now the first action, not a marketing carousel or registration wall.
- Onboarding uses the PRD sequence `q_c_001 → q_b_002 → q_c_002`: warm thanks, neutral question, object compliment.
- The sequence is completion-driven rather than artificially locked to three calendar days. Users can progress at their own pace while the difficulty order remains controlled.
- The required non-medical boundary appears after the first successful action, when it does not block activation but still precedes the rest of the program.
- No fake local account or placeholder auth was introduced. Profile is explicitly a device-local read model until anonymous-to-auth linking exists with backend sync.

### Implemented

- Raised `GameState` to schema v4 with backward-compatible onboarding state.
- Added canonical `onboarding_step_completed` and event-derived restoration of the boundary acknowledgement.
- Added `GameEngine.acknowledgeBoundaries()` with a rule preventing acknowledgement before the first completion.
- Added a root application state router:
  - first three guided quests;
  - mandatory boundary acknowledgement after quest one;
  - normal Today after quest three;
  - existing bootstrap loading/failure states.
- Added a focused onboarding quest screen with stable progress `1/3…3/3`, no modifier complexity and direct access to the existing Quest Detail/Reflection lifecycle.
- Added a permanent boundary screen covering non-medical positioning, Safe Defer, consent and professional-help escalation.
- Rebalanced post-onboarding Daily selection:
  - level 1 + level 2 through the early progression;
  - level 2 + level 3 after eight offline completions.
- Added a local Profile screen opened from the Today header with total XP, three stat progress bars, offline completion count and per-date quest history.

### Verification

- Direct Dart analyze: no issues found.
- Flutter tests: 22 passed.
- The 390×844 onboarding widget flow completes all three quests, acknowledges boundaries, reaches Today and verifies Profile history.
- Domain coverage verifies progression thresholds, pre-completion acknowledgement rejection and schema migration defaults.

## 2026-07-12 - Stage 3I local privacy controls

### Product boundary

- The application still has no backend account, so the UI deliberately says “delete local data”, not “delete account”. Server-side account deletion will be added only with real anonymous-to-auth linking and Supabase storage.
- Settings repeats the permanent non-medical, Safe Defer and consent boundaries required by the PRD.

### Implemented

- Extended the `GameStore` port with `clear()` so presentation remains independent of SQLite.
- SQLite now deletes reflections, append-only events and state snapshots in one transaction.
- Test storage mirrors the same behavior and tracks clear execution.
- Added `TodayController.clearLocalData()`:
  - clears persistence;
  - creates and refreshes a clean schema-v4 state;
  - writes a fresh snapshot;
  - resets recovery diagnostics to `fresh`;
  - returns the application to onboarding through normal state routing.
- Added Settings/About UI from the Profile header with permanent product boundaries and an explicit description of device-local storage.
- Added destructive confirmation with exact data scope and irreversible-action language.
- Successful deletion closes Settings/Profile routes and returns to onboarding step one; storage failures leave the current session visible and show an error.

### Verification

- Direct Dart analyze: no issues found.
- Flutter tests: 23 passed.
- The 390×844 widget flow now covers onboarding → Today → Profile → Settings → confirmation → complete local reset.
- Reset assertions verify zero completions, empty events/reflections, one storage clear and `loadSource: fresh`.
- Event rebuild coverage now also verifies onboarding acknowledgement restoration.

## 2026-07-12 - Stage 3J guide and rehearsal editorial system

### Audit findings

- Structural content coverage hid a serious quality problem:
  - 29 of 55 guides shared one generic step set;
  - 31 guides shared the same three generic phrases;
  - all 29 eligible quests used the same NPC rehearsal body.
- The catalogs were technically valid but not production-quality coaching content.

### Implemented

- Added seven safety-reviewed editorial archetypes: one-to-one conversation, group entry, position/disagreement, request/advice, direct invitation, appreciation and deliberate pause.
- Mapped every current quest category to an explicit archetype; basic level-1 and Shadow categories retain their purpose-specific steps.
- Each archetype now defines:
  - three execution steps;
  - three usable phrases;
  - a clean exit that matches the social situation.
- Replaced the shared NPC fallback with 29 quest-specific dialog graphs.
- Every rehearsal now includes:
  - the exact quest scenario;
  - a suitable opening phrase;
  - a realistic anti-pattern and corrective Coach branch;
  - an NPC response appropriate to the interaction type;
  - a direct-success route;
  - a successful clean-exit route that reinforces consent and boundaries.
- Regenerated all mobile guide/dialog assets through the canonical export pipeline.

### Quality gates

- Added `tests/content-quality.test.mjs` with release-facing checks for:
  - exact step/phrase cardinality;
  - mobile-safe text and option lengths;
  - minimum guide step/phrase diversity;
  - unique personalized rehearsal bodies for all 29 eligible quests;
  - mandatory successful safe-exit and direct-success nodes;
  - banned sexual-shock, identity-imitation, coercive and medicalized language.
- Diversity improved from 9 to 15 guide step sets, from 8 to 14 phrase sets and from 1 to 29 rehearsal bodies.

### Honest boundary

- The system is now individually contextualized and guarded against template regression. A final native-speaker copyedit and pilot feedback pass is still required before a store release; automated checks cannot prove that every phrase feels natural in every locale.

### Verification

- Root Node suite: 9 tests passed, including the new editorial quality gates.
- Deterministic mobile content equality passed after regeneration.
- Direct Dart analyze: no issues found.
- Flutter tests: 23 passed; all 29 bundled dialog graphs satisfy reachability, terminal-state and coverage validation.

## 2026-07-12 - Stage 3K durable event sync queue

### Architecture decision

- Sync orchestration is split into two ports:
  - `EventSyncStore` owns durable queue state;
  - `EventSyncTransport` owns the remote protocol.
- No fake network adapter or periodic background activity was wired before a real endpoint exists. Local events are queued immediately and remain available for the future transport.
- A server response is applied atomically as one accepted/rejected/retry result, preventing partial local acknowledgement if a database write fails midway.

### Implemented

- Added transport-neutral models for pending events, acknowledgements, retry updates and sync reports.
- Added `EventSyncService` with:
  - bounded batches, default 100 events;
  - explicit accepted event IDs;
  - permanent rejection reasons;
  - retry scheduling for IDs omitted from an otherwise valid response;
  - response validation against unknown IDs and accepted/rejected overlap;
  - exponential retry delay from 5 seconds to a 1-hour cap.
- Raised the SQLite database to v3 and added a backward migration for:
  - `sync_status`: pending/synced/rejected;
  - `sync_attempts`;
  - `last_sync_error`;
  - `next_retry_at`;
  - a pending queue index over status, retry time and creation time.
- Existing `synced = 1` rows migrate to the new synced status; old unsynced rows remain pending.
- Added ordered due-event loading, atomic ack application and durable retry updates to `SqfliteGameStore`.
- Updated the memory adapter with equivalent queue behavior for deterministic tests.
- Local data deletion also clears every sync status, retry and error record through the existing event-table transaction.

### Failure semantics

- Transport failure leaves every event pending and advances its retry attempt.
- Missing acknowledgements retry only unresolved events.
- Permanent server rejection exits the queue and preserves the rejection reason for diagnostics.
- A malformed ack retries the complete sent batch without applying foreign or overlapping IDs.
- Sync never mutates the gameplay snapshot, XP, energy or Reflection records.

### Verification

- Direct Dart analyze: no issues found.
- Flutter tests: 27 passed.
- Added coverage for partial ack, permanent rejection, missing ack, batch bounds, two-step exponential backoff and malformed foreign-ID responses.
- No network requests, packages, SDKs or system changes were introduced.

## 2026-07-12 - Stage 3L Supabase event backend contract

### Constraints

- No Supabase project, PostgreSQL server, `psql` or Supabase CLI is configured in this workspace.
- No package, SDK, license or system installation was performed.
- Migrations are covered by static contract tests but still require compilation against a disposable Supabase project before deployment.

### Implemented

- Added ordered Supabase migrations for:
  - the safety-reviewed quest catalog;
  - authenticated installation ownership;
  - append-only cloud events;
  - incremental user stats;
  - server-assigned Daily Boss and unique participation;
  - current-user cloud-data deletion.
- Enabled RLS on every exposed table and limited reads to authenticated catalog/Boss data or rows owned by `auth.uid()`.
- Revoked direct client writes to event, installation and stats tables. Events enter only through the security-definer ingestion RPC.
- Added an append-only trigger. A narrowly scoped transaction-local flag permits only the authenticated deletion RPC to remove the current user's event history.
- Added `ingest_quest_events(installation_id, events)` with:
  - authentication and installation ownership;
  - 100-event and 64-KiB-per-event bounds;
  - per-user advisory transaction lock;
  - UUID, event type, timestamp, quest and modifier validation;
  - `(user_id, id)` idempotency;
  - `quest_started` prerequisite for complete/defer;
  - canonical XP, NPC bonus and energy-delta recalculation;
  - negative-energy prevention;
  - per-quest/day completion protection;
  - trusted server Daily Boss matching and atomic participant increments;
  - per-event savepoints returning `acceptedIds` and `rejectedById` instead of failing the entire valid batch.
- The RPC never lets a client create or select the Daily Boss.
- Added `delete_my_cloud_data()` to remove the current user's cloud gameplay data and compensate Boss participant counters. Deleting `auth.users` remains an Edge Function/service-role responsibility.
- Added `scripts/export_supabase_seed.mjs` and generated a 55-record SQL seed from the canonical JS catalog.
- Added `npm run supabase:seed` and `npm run supabase:seed:check`.
- Added canonical mobile `GameEvent.toSyncPayload()` and strict `EventSyncAck.fromJson()` wire boundaries.
- Added [supabase/README.md](supabase/README.md) with migration order, RPC payload and verification limits.

### Verification

- Root Node suite: 13 tests passed.
- Static backend tests verify RLS, append-only protection, auth ownership, event-name/modifier parity, batch bounds, start/XP/energy validation, trusted Boss assignment and deletion compensation.
- Generated Supabase seed exactly matches all 50 quests and 5 Boss records.
- Direct Dart analyze: no issues found.
- Flutter tests: 28 passed, including mobile request serialization and RPC acknowledgement parsing.

## 2026-07-12 - Stage 3M injected Supabase HTTP transport

### Security and runtime decisions

- Supabase URL and anon key are read from compile-time `SUPABASE_URL` / `SUPABASE_ANON_KEY` configuration; no project values or credentials are committed.
- Access tokens are supplied per request through an injected provider and are never stored in event payloads, sync diagnostics or exception messages.
- The app does not start sync with an anon key alone. The ingestion RPC requires a real authenticated `auth.uid()`, so transport remains dormant until the auth/session lifecycle exists.
- Transport tests use a fake executor. No real network request was made.

### Implemented

- Raised local SQLite to v4 and added `app_metadata` for a durable installation UUID.
- Added `InstallationIdentityStore` and implemented atomic get-or-create behavior in SQLite and memory adapters.
- Bootstrap creates the installation UUID with the existing UUID generator before controller initialization.
- Local data deletion also removes installation identity, ensuring a clean new identity after the user explicitly resets the device.
- Added `SupabaseRuntimeConfig` with strict URL/config validation.
- Added transport-neutral `JsonHttpExecutor` and a `dart:io` implementation with connection, request and response timeouts.
- Added `SupabaseRpcClient` with:
  - injected access-token retrieval;
  - `apikey`, Bearer and JSON headers;
  - bounded sanitized RPC error detail;
  - strict object-response parsing;
  - no token exposure in errors.
- Added `SupabaseEventSyncTransport` mapping the durable installation ID and canonical event payloads to `ingest_quest_events` arguments.
- The transport maps the RPC response through strict `EventSyncAck.fromJson()` before queue state can change.

### Verification

- Direct Dart analyze: no issues found.
- Flutter tests: 32 passed.
- New tests verify exact RPC URL/body/headers, partial acknowledgement parsing, pre-network auth rejection, bounded token-safe errors and installation identity stability/reset.
- No packages, SDKs, system changes or external network calls were introduced.

## 2026-07-13 - Master specification reset and Phase 0

- Reviewed `MAYHEM_MASTER_PRODUCT_DESIGN_TECH_SPEC.md` in full and accepted it
  as the implementation contract for the feed-first migration.
- Captured the green pre-redesign app in commit `d3c6580` and local tag
  `pre-feed-redesign-baseline` on `codex/feed-vnext-foundation`.
- Added CI, repository ignore rules, production Android Internet permission,
  ADR 0001 and the phase-by-phase execution plan.
- Removed `.hatch-pets` work products from the active Git index while preserving
  the local files.
- Reverified 13 Node tests, 32 Flutter tests, content/seed generation, formatter,
  analyzer, Android XML and CI YAML.
- Full report: `docs/phase-reports/phase-0-baseline.md`.
- No package, SDK, license, system installation or user-data migration occurred.

## 2026-07-13 - Phase 1 Domain vNext and SQLite v5

- Added feature-first domain entities and repository ports without extending
  `TodayController` or enabling the new Feed.
- Added Clock, safe-default feature flags, event envelope v2, transactional
  client sequence, projection checkpoints and quarantine.
- Added additive SQLite v5 schema and deterministic SQL-to-Dart generation.
- Added idempotent v4 migration for local identity, exact XP mapping, completion
  history and local-only private reflections.
- Removed hard Energy blocking from the legacy engine.
- Added Momentum/Shield, balanced Rank, Difficulty and reward policies.
- Verified 15 Node tests, 50 Flutter tests, real SQLite fresh/v4/rollback,
  formatter, analyzer and generated migrations.
- Full report: `docs/phase-reports/phase-1-domain-vnext.md`.
- No package, SDK, license or system installation was performed.

## 2026-07-13 - Phase 2 design system and Motion Lab

- Added centralized visual, material, typography and motion primitives under
  `mobile/lib/core/design_system` and made the legacy theme consume them.
- Added accessible pressable/button/hold/glass/navigation/sheet/feedback
  components with reduced-motion and opaque fallbacks.
- Added custom vector glyphs, semantic Momentum Core states, Spark/Mover Rank
  Sigils, vertical Feed fixture physics and a Reward Stage sandbox.
- Added the internal Motion Lab route behind `kDebugMode` plus an isolated dev
  entrypoint; production users cannot resolve the route.
- Added exactly-once Hold tests, semantic action tests, Feed snap coverage,
  viewport tests at 360x800, 390x844, 430x932 and 412x915, text scale 1.3/1.6,
  preference fallback tests and two mobile golden images.
- Verified 15 Node tests, 67 Flutter tests, analyzer, formatter, deterministic
  content/seed/migration exports and real SQLite fresh/v4/rollback behavior.
- No dependency was added and neither `pubspec.yaml` nor `pubspec.lock` changed.
  One dev-server attempt was mistakenly started without `--no-pub`, so Flutter
  resolved the already locked packages and may have refreshed its user pub
  cache before failing on the missing `impellerc`. No SDK repair or system
  installation was attempted.
- iOS simulator, physical iOS and Android performance checks remain open: this
  machine has no `simctl`, connected Android device or `adb` runtime.
- Full report: `docs/phase-reports/phase-2-design-system.md`.

## 2026-07-13 - Phase 3 progress 1: local-first Feed foundation

- Added a safety-reviewed 20-item bundled vNext adapter and deterministic local
  Feed batch generation with challenge-first ordering, diversity and expiry.
- Added offline Feed session bootstrap, active-attempt restoration and atomic,
  idempotent impression/open/skip event commits.
- Added SQLite v6 assignment-attempt uniqueness and persisted content activation
  state. Revision checksums now cover safety metadata.
- Added framework-neutral Feed and challenge coordinators over repository ports,
  plus feature-scoped SQLite adapters sharing one transaction context; no UI
  framework or state package is coupled to domain rules.
- Added atomic Accept and resolution commits covering attempt, private
  reflection, progress, Difficulty, Momentum, Rank and canonical event sequence.
- Proved Attempted 60% reward plus Momentum, Completed full reward, bounded
  reflection bonus, duplicate callback no-op, private-note isolation and
  transaction rollback.
- Verified 82 Flutter tests, 16 Node tests, analyzer, formatter, generated v5/v6
  migrations and real SQLite fresh/v4-upgrade/rollback behavior.
- No package, SDK or system dependency was installed; project dependency files
  were not changed.
- Production Feed UI, Riverpod/router wiring, preparation/capsule/result/
  reflection/reward screens, Reduce Motion integration and hardware gate remain
  open. Phase 3 is not marked complete.
- Full progress report:
  `docs/phase-reports/phase-3-progress-1-local-foundation.md`.

## 2026-07-13 - Gate clarification before Phase 3 UI

- Split the Phase 2 result into a passed software/design-system gate and a
  separate deferred physical-device performance gate.
- Simulator/emulator runs are classified as functional and visual smoke only;
  they cannot close performance acceptance.
- Physical iOS and Android performance evidence is mandatory before enabling
  `new_feed_enabled` by default or distributing an internal beta, but it does
  not block continued Phase 3 implementation behind the disabled flag.
- Audited source, scripts and project configuration: no code directly invokes
  or depends on a standalone `impellerc`. Flutter's standard shader/assets
  pipeline remains authoritative; `--no-test-assets` is a host-only test
  workaround for the incomplete local engine cache.
- Legacy Today remains the production default and the Feed flag safe-default is
  still false.
- The one historical run without `--no-pub` is accepted because dependency
  manifests and lockfiles did not change. Reproducible checks continue with
  locked dependencies and no package updates.
- No Xcode, Android SDK, simulator, emulator or other system component was
  installed or modified.

## 2026-07-14 - Phase 6D server artifact and social projection

- Added server-issued Founder artifact ownership bound to the exact Season
  revision and Boss event; client-authored unlock claims remain rejected.
- Added artifact ownership to the authoritative sync/bootstrap projection with
  strict typed mobile parsing.
- Added idempotent cumulative Boss participation aggregation under a keyed
  advisory lock and enforced a privacy threshold of at least 20.
- Removed direct authenticated access to raw Season/Boss/social tables.
  `get_active_season()` now strips publisher values and returns social proof
  only from a qualified server aggregate inside its active window.
- Revoked inherited PUBLIC execution from internal security-definer Momentum
  and arbitrary-user projection helpers.
- Preserved deletion semantics: personal participation and ownership cascade
  away, while only the non-identifying cumulative aggregate may remain.
- Verified analyzer, 170 full Flutter tests, 22 full Node tests, deterministic
  exports, real SQLite migration paths and `git diff --check` without
  dependency or system changes.
- Full report:
  `docs/phase-reports/phase-6d-artifact-social-projection.md`.

## 2026-07-14 - Local Feed interaction and preparation software gate

- Connected a lifecycle-aware 600 ms visibility threshold to idempotent Feed
  impressions; open, skip and accept also establish the canonical impression
  before their own event.
- Added a typed four-reason skip sheet and persisted skip before page advance.
- Added Guide and interactive branching Rehearsal preparation by adapting the
  existing reviewed guide/dialogue catalogs instead of creating duplicate
  editorial content.
- Replaced the first-eleven launch catalog with a deterministic trait-balanced
  six level-1, four level-2 and one level-3 mix.
- Added exact bundled-catalog activation and stale cached-batch fail-forward
  recovery without deleting historical assignments.
- Tightened server interaction-event assignment/attempt/reason validation.
- Added lifecycle, funnel-order, persistence, 1.6x Dynamic Type and golden
  coverage for the new preparation and skip surfaces.
- Verified 175 full locked Flutter tests. The preceding implementation pass
  also verified analyzer, 22 Node tests, deterministic exports and real SQLite
  fresh/v4-upgrade/rollback paths.
- No dependency, SDK, package, system component or production flag changed.
  The web preview was unavailable because the existing Flutter cache lacks a
  usable DWDS directory; no repair or installation was attempted.
- Full report:
  `docs/phase-reports/feed-interaction-preparation-software-gate.md`.

## 2026-07-14 - Phase 6E server-owned artifact presentation

- Added immutable local Founder ownership and a read repository port.
- Carried server-owned artifacts through fresh projection reconciliation and
  persisted them atomically with projection revision, progress and Momentum.
- Stale projections cannot replace ownership; corrupt snapshots clear
  fail-closed. Snapshot/reconciliation revision mismatch forces authoritative
  recovery on the next sync.
- Added active Season/revision/Boss/catalog matching before presentation.
- Added a post-sync refresh callback for Journey and ownership.
- Removed the unconditional fake artifact placeholder from You.
- Added a real tile visible only behind both disabled Season and Boss gates and
  only for server-issued matching ownership.
- Verified analyzer, 179 Flutter tests, 22 Node tests, deterministic exports,
  clean goldens and real SQLite fresh/v4-upgrade/rollback.
- No package, SDK, dependency, schema migration, system component or production
  flag changed.
- Full report: `docs/phase-reports/phase-6e-artifact-presentation.md`.
