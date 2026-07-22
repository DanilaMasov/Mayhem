# MAYHEM — Current Recovery & Completion Specification v1.2

**Status date:** 2026-07-15
**Audited source checkpoint:** `9a61caa feat(season): present server-owned artifacts`
**Audited branch:** `codex/phase-6e-artifact-presentation`
**Purpose:** replace fragmented phase reports with one current execution contract for Codex.

---

## 0. Authority, scope, and non-negotiable boundaries

This document is the current source of truth for further Mayhem development. Where an older PRD, phase report, README, ADR, execution plan, or development log conflicts with this document, this document wins unless a later explicitly versioned specification supersedes it.

### 0.1 Production target

- The production application is the Flutter application under `mobile/`.
- The root web implementation is legacy/reference material only.
- Do not add new product functionality to the legacy web application.
- Do not rewrite the existing Flutter architecture merely to make it stylistically different.

### 0.2 Kira is not part of Mayhem

Kira and `.hatch-pets/` are personal Codex tooling/assets and are completely outside the Mayhem product scope.

Codex must:

- never import Kira assets into `mobile/`;
- never interpret Kira as the Mayhem companion;
- never use Kira files as design references or product requirements;
- never delete the user's local `.hatch-pets/` directory;
- keep `.hatch-pets/` ignored by Git;
- ensure Kira blobs are absent from the new clean Mayhem Git baseline.

The existing `companion_enabled` product flag, if retained, must remain disabled and must not be connected to Kira. No companion work is authorized in this execution cycle.

### 0.3 Evidence policy

A gate may be marked complete only when the required evidence exists.

Do not claim:

- physical-device acceptance without physical-device runs;
- live-backend acceptance from source-contract tests alone;
- release readiness from debug builds;
- migration safety from mocked database tests alone;
- production auth/sync readiness when the adapters are not composed into the app;
- a phase complete when its user-visible states or failure recovery are missing.

When an environment cannot execute a required test, record the exact missing capability and leave the gate open. Do not fabricate substitutes.

---

## 1. Current accepted baseline

The following work is accepted and must be preserved unless a concrete defect is demonstrated:

- Flutter local-first runtime under `mobile/`;
- SQLite schema v5/v6 and forward migrations from legacy v4;
- append-only local event model;
- idempotent Feed impression/open/skip/accept/result handling;
- Feed preparation, guide, rehearsal, active challenge, result, reflection, and reward loop;
- XP, traits, Momentum, ranks, Journey, You, onboarding, history, and local reset;
- bundled content validation and deterministic local fallback;
- repository boundaries and domain-oriented abstractions;
- Supabase SQL migration files and source-contract tests;
- anonymous-auth interfaces;
- exact-ACK sync contracts;
- remote-content and remote-feature-flag contracts;
- Season package, participation, Boss-event, artifact-ownership, reconciliation, and privacy-thresholded social-proof domain logic;
- existing passing repository tests.

At the audited checkpoint, independently available checks passed:

- 22/22 Node tests;
- content export validation;
- mobile migration generation;
- real SQLite fresh-install migration;
- real SQLite v4-to-v6 upgrade;
- rollback test;
- Supabase seed validation;
- `git diff --check`.

Flutter tests were not independently re-run in the audit environment because Flutter/Dart were unavailable there. GitHub CI must provide the next independent Flutter verification.

---

## 2. Actual blockers discovered in the audit

Codex was not blocked from writing ordinary application code. It correctly refused to pretend that environment-dependent gates were complete.

The previously reported blockers were:

- incomplete Flutter engine cache, including missing `impellerc` behavior for ordinary test/asset paths;
- missing DWDS/web-preview capability;
- no `simctl`;
- no connected Android device/usable `adb`;
- no physical iOS or Android device;
- no live PostgreSQL/Supabase environment;
- no Docker/Supabase CLI in the execution environment;
- no Xcode/CocoaPods capability in that environment.

These limitations leave the following gates open:

1. physical-device performance, lifecycle, accessibility, haptics, thermal, and migration acceptance;
2. live Supabase SQL parsing, RLS, grants, RPC, concurrency, deletion, and auth acceptance;
3. production secure-session storage;
4. real production composition of auth, sync, remote flags, remote content, Feed assignments, Season/Boss, account actions, and lifecycle triggers;
5. release signing and store configuration.

These are not reasons to abandon the implementation. They define the next integration sequence.

---

## 3. Highest-priority repository recovery

### 3.1 Problem

The audited local branch and the current GitHub `origin/main` do not share a usable merge base. The local branch has no upstream. The old local Git history also contains large Kira blobs from an early commit even though `.hatch-pets/` is no longer tracked.

Do not blindly push the current local history to `main`.

### 3.2 Required recovery method

Create a clean baseline based on the current remote `main`, importing only the tracked files from the audited Mayhem `HEAD`.

Before changing anything:

1. Preserve the old repository as a Git bundle.
2. Export the tracked current tree with `git archive`.
3. Clone the GitHub repository into a separate sibling directory.
4. Import the archived tree into the clean clone.
5. Commit it on a branch based on `origin/main`.
6. Push that branch and open a pull request.
7. Keep the old repository and ZIP until the new branch is verified and merged.

Recommended commands, executed from the old Mayhem repository:

```bash
git status
git bundle create ../mayhem-pre-clean.bundle --all
git archive --format=tar HEAD > ../mayhem-current-tree.tar

cd ..
git clone https://github.com/DanilaMasov/-Mayhem.git mayhem-clean
tar -xf mayhem-current-tree.tar -C mayhem-clean

cd mayhem-clean
git switch -c codex/current-baseline
git add .
git commit -m "chore: import clean Mayhem baseline"
git push -u origin codex/current-baseline
```

Then open a pull request from `codex/current-baseline` into `main`.

Do not run `git clean -fdX` in the old working copy because it can delete ignored local Kira files.

### 3.3 Repository acceptance criteria

Repository recovery is complete only when:

- the new working repository is based on `origin/main`;
- `git merge-base HEAD origin/main` returns a commit;
- `.hatch-pets/` is absent from the tracked tree;
- Kira blobs are absent from the new branch history;
- the branch has an upstream;
- GitHub CI runs;
- Flutter format, analyze, and tests are green in CI;
- the old local repository remains backed up until merge verification;
- the clean baseline is merged through a reviewed pull request or deliberately promoted after review.

---

## 4. Documentation consolidation

Create these files in the clean repository:

### 4.1 `AGENTS.md`

It must tell every future Codex session:

- `mobile/` is the only production target;
- root web code is legacy/read-only;
- Kira and `.hatch-pets/` are out of scope and must not be touched;
- this specification is authoritative;
- no gate may be declared complete without evidence;
- one vertical slice per branch/commit;
- do not edit a migration already applied to any shared environment;
- use new forward-only migrations for fixes;
- do not add dependencies, install system software, or alter developer-machine configuration silently;
- preserve local-first behavior and offline launch;
- never make network availability a prerequisite for opening the core app;
- update the current status document after each completed slice.

### 4.2 `docs/CURRENT_STATUS.md`

Replace contradictory append-only status prose with a compact structured status:

- current branch and commit;
- completed capabilities;
- active work item;
- open software gates;
- open live-backend gates;
- open device gates;
- known release blockers;
- exact test commands and latest results;
- next authorized slice.

### 4.3 Documentation cleanup

- Update README to reflect the actual Flutter implementation.
- Mark outdated PRDs, audits, and phase reports as historical.
- Do not delete useful historical evidence, but clearly label it non-authoritative.
- Add a link from README and `AGENTS.md` to this specification.
- Remove stale claims that Phase 6C is uncommitted or that the project is still only at an earlier branch.

Acceptance criterion: a fresh Codex session can identify the production target, current state, next task, and open gates without reconstructing them from conflicting reports.

---

## 5. Phase R1 — Production composition root

### 5.1 Objective

Turn the existing disconnected backend/domain components into one real, testable application runtime while preserving offline-first launch and keeping rollout flags fail-closed.

### 5.2 Required architecture

Introduce a clear production composition root, either by extending `VNextRuntime` or adding an `AppCompositionRoot`. It must own or construct:

- local database/store;
- bundled content source;
- feature-flag cache and resolver;
- mutable/effective feature-flag state exposed to UI;
- secure session store;
- anonymous auth gateway;
- backend gateway;
- sync coordinator;
- remote-content refresh service;
- remote Feed assignment service;
- Season participation coordinator;
- artifact reconciliation;
- delete-everywhere coordinator;
- account-link coordinator only when providers are configured;
- lifecycle-triggered orchestration;
- telemetry interface with a no-op development implementation.

Avoid global singletons that hide lifecycle or make tests stateful.

### 5.3 Secure session storage

Implement a production `SecureSessionStore` using:

- iOS Keychain;
- Android Keystore-backed encrypted storage.

A suitable maintained Flutter package may be added, but the dependency and its purpose must be recorded in the commit/report.

Requirements:

- never store refresh/access tokens in SQLite, plain preferences, logs, or source files;
- support read, atomic write, clear, and corrupted-entry recovery;
- namespace keys per environment;
- never log tokens;
- include adapter tests where possible and device verification later.

### 5.4 Bootstrap sequence

The app must launch the local experience immediately. Remote bootstrap must be non-blocking.

Required sequence:

1. initialize local database and recover local state;
2. render the app from local data;
3. load cached effective flags;
4. restore or create an anonymous session;
5. register/refresh the installation with backend;
6. fetch server capabilities and flags;
7. validate and apply effective remote flags;
8. refresh remote content metadata/content;
9. sync pending local events with exact ACK;
10. reconcile server-owned artifacts and Season state;
11. request remote Feed assignments when enabled;
12. refresh affected local projections;
13. expose recoverable remote errors without breaking local use.

Use timeouts, bounded retries, exponential backoff with jitter, and cancellation on disposal.

### 5.5 Feature flags

The current immutable startup-only flag behavior is insufficient.

Implement a runtime flag controller/state object that:

- starts from safe release defaults;
- can use valid cached server decisions;
- accepts a newly fetched server snapshot;
- publishes changes to interested UI/services;
- validates capability revisions;
- enforces expiry;
- fails closed on invalid, absent, expired, or incompatible data;
- keeps debug overrides available only in debug builds;
- never permits a debug override to leak into release.

Remote flags must actually control the UI/runtime. Merely caching them is not acceptance.

Add missing capability revisions for Season, Boss, artifact, social-proof, remote-content, and remote-Feed behaviors that the server may enable.

### 5.6 Sync triggers

Attempt sync on:

- successful remote bootstrap;
- app foreground;
- terminal Feed result/reflection completion;
- Season/Boss terminal action;
- explicit user retry;
- before account deletion where appropriate.

Do not sync on every keystroke or intermediate animation state.

Guarantees:

- local writes complete before network work;
- retries are idempotent;
- only exactly acknowledged event IDs become synced;
- partial ACK leaves unacknowledged events pending;
- duplicate server submissions do not duplicate rewards or participation;
- process death does not lose accepted local actions.

### 5.7 Remote content and remote Feed

Wire existing backend methods into production.

Remote content:

- validate schema/revision before activation;
- activate atomically;
- keep last known good content;
- fall back to bundled content when unavailable or invalid;
- never leave no usable content.

Remote Feed:

- request server assignments only when the corresponding capability and flag are enabled;
- persist assignment identity so repeated launches are stable;
- preserve server ordering and eligibility;
- deduplicate against local accepted/completed/skipped state;
- fall back to deterministic local generation when remote assignments are unavailable;
- never block Feed opening on network.

### 5.8 Settings and account actions

Wire Settings to real capabilities:

- `Reset data on this device` remains local-only and clearly worded;
- `Delete account and data everywhere` is enabled only with a valid remote session and backend capability;
- deletion requires explicit destructive confirmation;
- on confirmed server success, clear secure session and local user data;
- on partial/network failure, do not falsely report deletion;
- account linking remains hidden or disabled until at least one provider is configured and tested;
- notifications remain unavailable unless an actual implementation exists.

### 5.9 R1 acceptance criteria

- app opens offline with all remote services unavailable;
- valid cached state renders before remote bootstrap completes;
- anonymous session survives restart through secure storage;
- remote flags visibly affect the intended runtime behavior;
- invalid/expired flags fail closed;
- pending events sync with exact ACK;
- partial ACK and retries are tested;
- remote content activates atomically and falls back safely;
- remote Feed is consumed when enabled and local fallback remains available;
- Delete Everywhere is no longer a dead placeholder when backend capability exists;
- no secrets or tokens appear in repository, logs, SQLite, or plain preferences;
- unit/integration tests cover success, offline, timeout, malformed payload, auth refresh, partial ACK, and process-restart recovery.

The new Feed must remain disabled by default in release until the live-backend and physical-device gates are complete.

---

## 6. Phase R2 — Live Supabase acceptance

### 6.1 Objective

Prove that the SQL and Dart contracts work against a disposable real Supabase/PostgreSQL environment.

Source-text tests are not sufficient.

### 6.2 Environment

Use an isolated development project or local disposable Supabase stack.

Do not point destructive tests at production.

Record:

- project/environment identifier without secrets;
- migration command;
- seed command;
- test command;
- migration versions applied;
- result summary.

### 6.3 Migration policy

- Apply all migrations from zero in order.
- Never edit a migration after it has been applied to a shared environment.
- Fix discovered issues with new forward-only migrations.
- Verify rerun/idempotency expectations where designed.
- Test upgrade from the earliest supported backend schema where relevant.

### 6.4 Required live tests

Authentication and identity:

- anonymous signup;
- session refresh;
- installation registration;
- ownership isolation between two anonymous users;
- account-link preparation if enabled.

Security:

- RLS denies cross-user reads/writes;
- direct table writes are denied where RPC is required;
- grants and revokes match intent;
- `security definer` functions have safe `search_path`;
- private reflection text is not exposed through social queries.

Sync:

- valid event batch accepted;
- exact ACK returned;
- malformed event rejected safely;
- duplicate event submission idempotent;
- partial success behavior matches client contract;
- refresh/retry after expired access token.

Season/Boss:

- join eligibility;
- duplicate join idempotency;
- daily progress rules;
- Boss-window validation;
- duplicate Boss participation;
- concurrent Boss submissions;
- advisory lock or equivalent correctness;
- expired/closed Season rejection;
- server-authoritative completion.

Artifacts and social proof:

- artifact issuance only after valid server-owned criteria;
- duplicate issuance prevented;
- reconciliation returns only owned artifacts;
- aggregate count hidden below privacy threshold;
- aggregate shown at/above threshold;
- no identities or private text leaked.

Deletion:

- delete user data everywhere;
- associated installations, events, participation, artifacts, and account data removed or anonymized according to contract;
- auth identity removed when designed;
- retry/failure behavior is explicit;
- one user cannot delete another user.

### 6.5 R2 acceptance criteria

- migrations parse and apply from zero;
- all required live tests pass;
- failures produce a written issue and forward migration, not silent edits;
- client bootstrap/auth/sync succeeds against the same environment;
- no service-role secret is shipped to the client;
- a reproducible backend acceptance report is committed.

---

## 7. Phase R3 — Complete Season and Boss product flow

### 7.1 Objective

Turn the existing Season/Boss domain foundation into a complete user-visible, recoverable flow.

### 7.2 Required state model

Model explicit states rather than inferring everything from nullable fields:

- feature disabled;
- loading cached state;
- loading remote state;
- unavailable;
- offline with cached state;
- not joined;
- joining;
- join failed/retryable;
- active Season day;
- day challenge available;
- day challenge in progress;
- day completed;
- Boss locked;
- Boss upcoming with time window;
- Boss open;
- Boss participation submitting;
- Boss already participated;
- Boss completed;
- Season expired;
- Season completed;
- server state conflict requiring refresh;
- malformed/incompatible package;
- generic recoverable error.

### 7.3 UX requirements

- show clear current Season identity and day;
- explain what joining means before mutation;
- never fake participation locally as server-confirmed;
- permit offline viewing of last known state;
- queue only actions that are explicitly safe to queue;
- provide retry for network/server failure;
- avoid infinite spinners;
- display server time-window state consistently;
- reflect completion in Journey/Profile without duplicate rewards;
- display owned validated artifacts;
- do not show social proof below privacy threshold;
- never show fabricated participant counts;
- include accessibility labels and large-text-safe layouts;
- maintain reduced-motion behavior.

### 7.4 Artifact presentation

For internal beta, support:

- current owned artifact;
- provenance/Season label;
- server-validated ownership;
- graceful loading and unavailable states.

A full historical archive may follow as a separate slice, but data modeling must not prevent it.

### 7.5 R3 acceptance criteria

- every state above has deterministic tests;
- join and Boss actions are server-authoritative;
- retries do not duplicate participation/rewards;
- expired and already-participated cases have explicit UX;
- process death during submission recovers correctly;
- offline cached state is distinguishable from confirmed current state;
- social-proof threshold is honored in UI and backend;
- no production state is implemented only in test fixtures.

---

## 8. Phase R4 — Physical-device and manual acceptance

### 8.1 Required devices

Test at minimum:

- one supported physical iPhone representative of the lower performance range;
- one current physical iPhone;
- one supported lower/mid Android device;
- one current Android device.

Simulators/emulators may supplement but do not replace physical-device gates.

### 8.2 Required scenarios

Performance:

- cold start;
- Feed scrolling for a sustained session;
- challenge open/close;
- guide/rehearsal transitions;
- result and rank-up overlays;
- Season/Boss screens;
- memory growth;
- thermal behavior;
- jank/frame timing;
- image/asset decoding behavior.

Lifecycle and resilience:

- background/foreground during every terminal action;
- force-kill before and after local commit;
- force-kill during sync;
- airplane mode;
- unstable connection;
- auth token expiry;
- server timeout;
- low storage where feasible;
- app upgrade from legacy SQLite v4 through v6/current;
- corrupted secure-session entry;
- deletion interrupted by network failure.

Accessibility:

- VoiceOver;
- TalkBack;
- Dynamic Type/font scaling to at least 1.6x;
- Reduce Motion;
- contrast;
- focus order;
- touch targets;
- keyboard visibility and form navigation;
- haptic behavior and no-haptic fallback.

### 8.3 Evidence

Commit a device acceptance report containing:

- device models and OS versions;
- build mode and commit;
- scenarios executed;
- failures and fixes;
- frame/performance evidence where available;
- screenshots or recordings for critical flows;
- explicit pass/fail for each gate.

Only after R4 passes may `new_feed_enabled` be enabled for an internal release cohort.

A preliminary pass on two physical devices may be used to find defects before
R6, but it does not close R4. Any R6 visual or interaction change invalidates
the affected device evidence. The final candidate must repeat the complete R4
matrix on all four required devices before the closed alpha is expanded.

---

## 9. Phase R5 — Release hardening

Before any external beta or store build:

- choose final Android application ID and iOS bundle ID;
- remove Android debug signing from release;
- configure proper signing outside source control;
- replace default Flutter launcher icons;
- reconcile portrait-only runtime with iOS/Android orientation declarations;
- establish version/build-number policy;
- define development, staging, and production environment configuration;
- keep secrets out of the repository;
- add privacy copy for local data, anonymous account, sync, deletion, and social aggregates;
- provide support/contact path;
- verify release builds, not only debug/profile;
- add crash reporting only with an approved privacy-conscious configuration;
- add analytics only after an explicit event/privacy specification;
- remove or hide dead controls and placeholder settings;
- complete store metadata later as a separate deliverable.

No release build may use the debug signing key.

---

## 10. Phase R6 — Visual and interaction refinement

Do this after the composition and core Season flow are working end to end and a
preliminary physical-device pass has exposed obvious platform defects.

Preserve the current product architecture and improve:

- hierarchy and density;
- empty states;
- Feed card emotional impact;
- preparation/rehearsal transitions;
- result/reflection payoff;
- rank and Momentum feedback;
- Journey readability;
- Profile/status presentation;
- Season/Boss anticipation and completion;
- accessibility under large text and reduced motion;
- motion timing, haptics, and sound only where justified.

Do not mask missing product states with animation. Do not begin a wholesale design-system rewrite before R1–R4 evidence exists.

Kira is not a design asset and must not appear in this phase.

### 10.1 User-directed rank and visual amendment — 2026-07-22

This amendment supersedes the local XP-only arena ladder and the experimental
rank-owned style collection introduced after this specification was written.

- XP and per-trait XP remain permanent evidence of completed work.
- A separate competitive rating must react to each terminal challenge result
  and may move both upward and downward. Low-pressure routes soften losses and
  repeated content cannot be farmed at full positive value.
- Prestige is presented as sixteen unique named titles rather than three Roman
  numeral levels inside each family. Balanced minimum trait XP may still gate
  promotion so one-trait farming cannot reach the top ladder.
- Promotion celebration is shown only for an actual upward title change.
  Demotion is checkpointed without a false celebration. Reduce Motion must
  reveal the complete final state immediately.
- The rating path must expose the current numeric rating, exact title
  thresholds, the weakest-trait requirement, continuous current-to-next fill,
  and real recent actions. It must remain fully scrollable above floating
  navigation at 1.6x text.
- Rank-owned themes, interface skins, and the selectable style collection are
  retired. Legacy preference fields remain read-compatible but have no release
  UI effect.
- Visual variety belongs to Feed content backgrounds and is selected
  deterministically by immutable content identity; it is not an unlockable
  rank reward.
- Server projections must calculate rating from accepted canonical events and
  return the frozen rating/rank revisions. Client-provided rating totals are
  never authoritative.

---

## 11. Explicit non-goals for the current cycle

Unless a later specification authorizes them, do not spend time on:

- Kira or any pet integration;
- a product companion;
- subscription/billing;
- public profiles;
- public friend graph;
- chat;
- broad social network mechanics;
- push notifications;
- rank sharing;
- heavy media generation;
- expansion of the legacy web app;
- speculative architecture replacement;
- production rollout before gates pass.

---

## 12. Feature rollout policy

All release defaults remain fail-closed.

Recommended enabling order:

1. local new Feed in debug/internal development;
2. anonymous auth and sync in staging after live-backend acceptance;
3. remote content after validation/fallback acceptance;
4. remote Feed after assignment persistence/deduplication acceptance;
5. Season after complete state-machine UX and live tests;
6. Boss after concurrency/time-window/live tests;
7. artifacts after issuance/reconciliation tests;
8. social proof only after privacy-threshold backend and UI acceptance;
9. new Feed for internal release cohort only after physical-device acceptance;
10. broader rollout only after monitored internal stability.

No single umbrella flag should silently enable an unverified dependent capability.

---

## 13. Commit and reporting protocol for Codex

For each slice:

1. inspect the authoritative spec and current status;
2. state the intended vertical outcome;
3. list files/components expected to change;
4. implement the smallest complete vertical slice;
5. run formatting, analysis, unit/integration tests, and relevant contract checks;
6. report exact commands and results;
7. report tests that could not run and why;
8. update `docs/CURRENT_STATUS.md`;
9. commit with a specific conventional message;
10. push the branch and open/update a pull request when GitHub access exists.

Do not combine repository surgery, production composition, Season UX, and visual redesign in one giant commit.

Suggested branch sequence:

- `codex/current-baseline`
- `codex/runtime-composition`
- `codex/live-supabase-gate`
- `codex/season-boss-flow`
- `codex/device-acceptance-fixes`
- `codex/release-hardening`
- `codex/visual-polish`

A phase report must distinguish:

- implemented;
- locally tested;
- CI tested;
- live-backend tested;
- simulator/emulator tested;
- physical-device tested;
- still blocked.

---

## 14. Immediate first assignment for Codex

Do not continue with an invented “Phase 7”.

First complete only **Repository Recovery and Documentation Consolidation**:

1. preserve the old repository with a bundle and tracked-tree archive;
2. create a clean GitHub-based working clone;
3. import the current tracked Mayhem tree without old Kira history;
4. push `codex/current-baseline`;
5. ensure GitHub CI runs;
6. add `AGENTS.md`;
7. add this specification as `docs/MAYHEM_CURRENT_SPEC_v1.2.md`;
8. create accurate `docs/CURRENT_STATUS.md`;
9. update README and mark historical reports non-authoritative;
10. commit and report exact evidence.

Stop after this slice if CI is red. Fix baseline CI before starting production composition.

After a green baseline, proceed to **Phase R1 — Production composition root**.
