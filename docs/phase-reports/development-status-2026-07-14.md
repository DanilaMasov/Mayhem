# Mayhem: consolidated development report

Date: 2026-07-14

Production target: `mobile/`

Current branch: `codex/phase-6c-season-participation`

Specification source: `MAYHEM_MASTER_PRODUCT_DESIGN_TECH_SPEC_v1.1.md`.
Phases 0-3 were retained and delta-audited against v1.1; they were not rebuilt.

## Executive status

The repository has progressed from a legacy local Today experience to a tested,
local-first mobile architecture with an additive vNext Feed domain, design
system, onboarding, Journey/You surfaces, authenticated Supabase contracts,
durable exact-ACK synchronization, remote-content activation rules and the
first three Season 0 slices.

Phases 0-5 have repository software gates closed for their declared scope.
Phase 6A and 6B are committed. Phase 6C is implemented and its focused software
checks are green. A continuation audit additionally corrected cache-identity
validation and server side-effect ordering before its checkpoint. No Phase 6
production capability is enabled.

The application is not ready for production or internal beta. The remaining
blockers are deliberately visible: live Supabase/PostgreSQL verification,
concrete platform secure storage, completed Season/Boss product slices,
reviewed production content/assets and physical-device
performance/accessibility acceptance.

## How the work was performed

1. The specification was treated as the source of truth and the existing app
   was audited before architecture changes were made.
2. Risky changes were introduced additively beside legacy Today, with safe
   feature-flag defaults and rollback points.
3. Product rules were moved into typed domain policies and repository ports;
   widgets do not own reward, rank, Momentum, sync or Season authority.
4. Local-first behavior was implemented before remote behavior. Missing auth,
   secure storage or backend services were not replaced with fake success.
5. Every completed slice received focused unit/widget/contract coverage, and
   broader suites were run at phase gates.
6. No system SDK, platform toolchain, service, package or standalone shader
   compiler was installed. Existing locked project dependencies were used.
7. Manual/device, external-service and content gates were kept separate from
   repository software gates so unavailable infrastructure did not encourage
   false completion claims.

## Phase 0 - baseline and repository boundary

### What was done

- Read and audited the complete 5278-line master specification and the Flutter
  bootstrap, legacy state/engine, SQLite, events, sync, content, tests, Android
  manifest and current visual baseline.
- Created a green rollback checkpoint, commit `d3c6580`, and tag
  `pre-feed-redesign-baseline`.
- Added repository hygiene rules, local-equivalent CI, Android Internet
  permission, the Feed-first ADR and a phased migration plan.
- Explicitly marked the root web prototype as legacy/supporting material and
  `mobile/` as the production target.
- Removed local pet-authoring output from the Git index while preserving it on
  disk.

### Why

The project already contained useful behavior and user data contracts. A tagged
baseline and explicit production boundary made it possible to build vNext
without rewriting or silently breaking the working Today path.

### Verification

13 Node tests, 32 Flutter tests, analyzer, formatter, content/seed generation,
Android XML and CI YAML validation passed at the Phase 0 gate.

## Phase 1 - domain vNext and safe migration

### What was done

- Added injected clock contracts and immutable models for content revisions,
  Feed assignments, attempts/results, progress, four traits, Momentum,
  difficulty, rank, reflections, Season and media.
- Added narrow repository ports and legal challenge transitions, including
  penalty-free defer/resume and distinct Attempted/Completed outcomes.
- Added versioned reward, difficulty, rank and Momentum policies. Energy no
  longer blocks challenge acceptance.
- Added canonical event envelope v2, installation sequence allocation and
  recursive rejection of private-note bodies.
- Added additive SQLite v5 schema, legacy import, stable local identity,
  checkpoints, bounded tail replay and corrupt-event quarantine.
- Added a real SQLite migration harness for fresh install, v4 upgrade and
  rollback safety.

### Why

This isolates durable product rules from UI and legacy controllers, preserves
existing data, and makes replay/sync deterministic. Private reflections remain
local by construction instead of relying on UI discipline.

### Verification

15 Node tests, 50 Flutter tests, analyzer, formatter, generated migration checks
and real SQLite fresh/upgrade/rollback scenarios passed.

## Phase 2 - design system and Motion Lab

### What was done

- Added centralized color, spacing, radius, typography, material, shadow,
  duration, spring, haptic and accessibility tokens.
- Added reusable scaffold, text, icon, pressable, buttons, Hold action, glass
  controls, adaptive navigation, sheets, dialogs, toasts and state surfaces.
- Added Momentum Core, rank sigils, layered Feed fixture, Reward Stage and an
  internal Motion Lab.
- Implemented Reduce Motion and Reduce Transparency behavior, Dynamic Type
  checks and deterministic goldens.

### Why

The old dashboard visual language was not a viable base for the new product.
The design system gives later screens a coherent, testable vocabulary without
coupling visual components to `GameState` or SQLite.

### Verification

67 Flutter tests and 15 Node tests passed. Layout checks covered four phone
viewports and text scales 1.3/1.6. Two golden baselines and a token-literal audit
passed. The software/design-system gate closed; physical performance stayed
open.

## Phase 3 - local-first Feed foundation

### What was done

- Added a reviewed bundled vNext catalog and deterministic 20-item local Feed
  batch with bounded intensity, diversity, expiry and no duplicate content.
- Added offline bootstrap, active-attempt restoration and idempotent impression,
  open and typed-skip commits.
- Added additive SQLite v6 assignment/attempt invariants.
- Added an atomic challenge coordinator for Accept, Attempted, Completed,
  reflection, XP, traits, Difficulty, Momentum and Rank.
- Added duplicate-callback protection, rollback tests and content checksum/
  safety activation rules.

### Why

The complete gameplay transition must succeed as one local transaction before
the UI celebrates or remote sync begins. This prevents double rewards, partial
state and startup dependence on a network session.

### Verification

82 Flutter tests and 16 Node tests passed, with analyzer, migration generation,
real SQLite migration/rollback and diff checks. The vertical slice remained
behind `new_feed_enabled = false` with legacy Today as default.

### Local Feed software completion

- Connected the 600 ms foreground impression threshold, open and typed skip to
  canonical idempotent events.
- Added Guide and branching Rehearsal preparation from the existing reviewed
  55-guide/29-dialogue catalogs.
- Balanced launch content across all four traits and three safe difficulty
  levels.
- Added exact bundled activation and stale-batch fail-forward recovery.
- Tightened server interaction validation and added lifecycle, Dynamic Type,
  persistence, funnel-order and golden coverage.

The complete local Feed software path now passes 175 Flutter tests and remains
behind `new_feed_enabled = false`. Physical-device performance, live Supabase
and production content acceptance remain open gates.

## v1.1 delta gate for Phases 0-3

### What was corrected

- Split gate taxonomy into software, manual/device, external-service and
  asset/content gates.
- Made every production capability fail closed and release overrides inert.
- Kept local identity separate from Supabase anonymous identity.
- Froze the development reward, difficulty, rank and Momentum revisions and
  corrected neutral difficulty/rank behavior.
- Clarified local-only versus everywhere deletion ordering and identity reseed.
- Kept physical-device performance acceptance explicitly open.
- Confirmed that standalone `impellerc` is not a project dependency.

### Verification

90 Flutter tests and 16 Node tests passed, plus analyzer, formatter, content,
migration and real SQLite checks. Only real v1.1 incompatibilities were changed;
no architectural rewrite was introduced.

## Phase 4 - onboarding, Journey and You

### What was done

- Added fresh, migrated and stale-safety onboarding with calibration and safety
  revision acceptance.
- Added a three-tab local-first shell with persistent nested navigation stacks.
- Added Feed restoration, Journey projections/history/private reflection access,
  profile presence, settings, privacy, accessibility and diagnostics.
- Added Russian localization and an atomic local reset that rotates identities
  and disables cached capabilities.
- Kept Delete Everywhere visibly unavailable until the authenticated Phase 5
  contract existed.

### Why

The app needed a complete personal product shell before remote services. Local
identity and data remain useful offline, while destructive actions communicate
their real scope.

### Verification

105 Flutter tests and 16 Node tests passed. Analyzer, formatter, generated
content/migrations, real SQLite, localization scan, 1.6x text scale and three
390x844 golden surfaces passed.

## Phase 5 - backend, auth, sync and remote content

### What was done

- Added additive Supabase schema, RLS and security-definer RPC contracts for
  canonical events, projections, installations, content, Season/Boss data and
  deletion.
- Added typed anonymous-auth/session boundaries without conflating cloud user ID
  with local identity.
- Added a secure-session port, token-safe HTTP client, exact-ACK ingestion,
  bounded retry/backoff/quarantine and reconciliation.
- Added immutable remote-content revisions, checksums and atomic manifest
  activation with bundled fallback.
- Added receipt-gated Delete Everywhere ordering and shared client/server policy
  revision assertions.

### Why

The server must validate canonical events and ownership, while the app must keep
working from SQLite. Exact acknowledgement and fail-closed composition avoid
lost events, false sync success and accidental remote activation.

### Verification

143 Flutter tests and 20 Node tests passed at the Phase 5 gate, including focused
auth/privacy/transport, flags/lifecycle/reconciliation and migration tests.
This verifies repository contracts only; SQL has not been applied to a live
PostgreSQL instance.

## Phase 6A - strict Season package contract

### What was done

- Added a strict seven-day Season 0 package and Boss-route domain contract.
- Added fail-closed remote mapping for invalid revisions, dates, routes and
  unsupported payloads.
- Added privacy-safe, thresholded social-proof representation and artifact
  descriptors without granting client authority.

### Why

Remote seasonal content must be rejected as a whole when incomplete or unsafe.
Partially rendered Season data would be harder to recover from than showing the
known-good local product.

### Verification

Five focused mapper tests, analyzer and formatter passed. The full Phase 6 gate
remained open.

## Phase 6B - cache and activation

### What was done

- Added atomic SQLite Season cache replacement and restoration.
- Added local and remote kill switches; both must permit activation.
- Stripped social aggregate data before persistence unless its capability is
  explicitly active.
- Added optional, non-blocking Season bootstrap so failure cannot delay the
  local Feed.

### Why

Season is an enhancement, not a startup dependency. Independent gates and cache
clearing prevent stale or remotely disabled social/seasonal data from lingering
on device.

### Verification

Focused cache, activation, sanitization and sync-isolation tests passed with
analyzer and formatter. Commit: `1097988`.

## Phase 6C - participation authority

### What was done

- Added local Season participation state and a coordinator with explicit legal
  transitions.
- Added atomic local persistence of participation plus canonical events.
- Extended server contracts to validate active Season/Boss identity and unique
  day completion.
- Rejected client-authored artifact ownership and kept social aggregate mutation
  outside this slice.

### Why

Local participation must survive offline use, but rewards, Boss eligibility and
artifacts cannot trust client assertions. The split keeps UX responsive while
preserving server authority.

### Verification and repository state

- `dart analyze`: no issues.
- 21 focused Flutter tests across Phase 6A-6C and sync: passed.
- `node --test tests/supabase-vnext-contract.test.mjs`: 5 passed.
- `git diff --check`: clean.

The continuation audit also verifies that embedded cached Season identity
matches its metadata key, that events cannot predate the recorded join, and
that rejected assignment-bearing Season events cannot mutate server state.

## Architecture assessment

### Strengths

- Local-first first render: SQLite is the operational source on startup.
- Legacy isolation: vNext is additive and production defaults remain on Today.
- Clear boundaries: domain policies, ports, adapters, coordinators and widgets
  have distinct responsibilities.
- Transactional consistency: reward/progress/Momentum/events and Season
  participation do not partially commit.
- Replayability: canonical sequence, checkpoints, quarantine and immutable
  revisions support recovery and diagnostics.
- Privacy by construction: private-note bodies are excluded from canonical
  events and remote transport.
- Server authority: RLS/RPC contracts validate ownership and canonical policy
  instead of trusting client XP, Boss or artifact claims.
- Fail-closed delivery: local and remote flags, manifests and capabilities
  default false and can clear unsafe cached state.
- Replaceable integrations: auth, secure storage, transport, content and Season
  sources sit behind narrow interfaces.

### Remaining architectural risks

- SQL validity and concurrency are source-tested, not database-executed.
- `SecureSessionStore` has no production Keychain/Keystore adapter.
- Feed software is complete locally, but its performance, accessibility and
  lifecycle behavior still need representative physical-device acceptance.
- Season artifact/social authority is source-complete, but still needs live
  PostgreSQL/RLS/concurrency acceptance. Active ownership presentation is
  gated and local; Season/Boss participation screens remain incomplete.
- Some important recovery behavior, especially deletion/session interruption,
  can only be accepted with platform fault injection.

The current architecture is modular and suitable for the expected product
scale. A framework rewrite or premature service split would add cost without
addressing the actual blockers above. The next value comes from closing real
integration and product loops.

## Data and migration status

- Mobile SQLite moved additively from v4 to v5 and v6. No migration drops legacy
  tables or resets user data.
- Fresh install, v4 upgrade and rollback are covered by a real SQLite harness.
- Supabase migrations are additive and protected by RLS/RPC contracts, but the
  current vNext SQL has not been compiled or applied by PostgreSQL.
- Phase 6C-6D modify the not-yet-deployed vNext migrations in place. This is safe
  only while they remain undeployed; after first deployment, all changes must be
  new forward-only migrations.
- Local reset and Delete Everywhere are distinct contracts. Cloud deletion must
  be acknowledged before local/session teardown claims global completion.

## Feature flags and production safety

All production/release capability defaults remain false. In particular:

- `new_feed_enabled`: false; legacy Today remains default.
- advanced motion: false.
- remote content: false.
- cloud sync/auth composition: unavailable without approved runtime/session
  composition.
- account linking: false.
- Season/Boss/social/artifact capabilities: false.
- notifications and other external capabilities: false.

Debug-only explicit overrides do not change release defaults. Open manual,
external or content gates do not block repository work, but they do block the
associated production flag.

## Gate status

### Software gate

- Closed for declared Phase 0-5 repository scope.
- Closed for Phase 6A mapper and Phase 6B cache/activation slices.
- Phase 6C participation and Phase 6D artifact/social authority focused checks
  are green.
- Phase 6E artifact reconciliation/presentation and the full 179-test
  repository regression are green. The complete Phase 6 gate remains open for
  Season/Boss participation screens and external acceptance.

### Manual/device gate - open

Required on representative physical iOS and Android devices:

- sustained Feed frame timings, memory and thermal behavior;
- haptics and reduced-motion behavior;
- VoiceOver/TalkBack and Dynamic Type;
- background/foreground, network loss and process-kill recovery;
- installed v4 -> current database migration;
- secure storage, account linking and deletion fault injection.

Simulator/emulator runs may support functional and visual review but cannot
close physical-device performance acceptance.

### External-service gate - open

- Apply migrations to a disposable PostgreSQL/Supabase environment.
- Run adversarial RLS isolation and RPC authorization tests.
- Verify anonymous signup/refresh, abuse controls and account linking.
- Verify exact ACK, idempotency, retries, reconciliation and concurrent writes.
- Verify cloud deletion, including the privileged `auth.users` step.

### Asset/content gate - open

- Review and publish production challenge/Season/Boss content.
- Produce final Sigil/Core/artifact artwork and media.
- Complete legal/privacy copy and sound/haptic review.
- Validate remote manifests/checksums and rollback publication workflow.

## What remains, in recommended order

### P0 - next repository work

1. Complete the gated Season/Boss participation, failure, expiry and recovery
   presentation.
2. Repeat the complete Flutter/Node/migration gate after that presentation
   integration.

### P0 - integration and release blockers

1. Use a disposable Supabase/PostgreSQL environment to compile/apply SQL and run
   adversarial RLS/RPC/idempotency/concurrency/deletion tests.
2. Select and implement an approved Keychain/Keystore-backed secure session
   adapter, then verify lifecycle and logout/deletion behavior.
3. Run the physical iOS/Android performance, accessibility and migration gate
   before internal beta or enabling the Feed by default.

### P1 - product completion

1. Build historical Season/artifact archive presentation after the active
   Season/Boss flow is accepted.
2. Complete production content, media lifecycle, localization and editorial
   review.
3. Complete account linking, remote-content publishing/rollback and operational
   diagnostics.
4. Perform a focused visual/product pass after the complete interaction loop is
   usable; avoid another architecture rewrite for branding alone.

### P2 - launch readiness

1. Final application ID, signing, store metadata and privacy disclosures.
2. Production observability, crash reporting and privacy-safe analytics.
3. Notification strategy, abuse operations and support/deletion runbooks.

## Cleanup performed on 2026-07-14

Removed only reproducible or editor/OS-generated data:

- `mobile/build/`;
- `mobile/.dart_tool/`;
- old `mobile/flutter_01.log` and `mobile/flutter_02.log`;
- `.DS_Store` files outside protected Git internals;
- `.idea`, `.iml` and Flutter plugin-discovery metadata;
- generated iOS/macOS ephemeral configuration and plugin registrants.

Repository size decreased from approximately 286 MB to 235 MB, reclaiming
about 51 MB. Source code, tests, goldens, migration sources, lockfiles, Gradle
wrapper files and all Phase 6C changes were preserved.

The 128 MB `.hatch-pets/` directory was deliberately retained. Phase 0 records
it as a local authoring archive intentionally removed from Git but preserved on
disk. It should be deleted only by an explicit asset-archive decision, not by a
generic cleanup. Historical Git objects also still contain old authoring data;
history was not rewritten.

## Current Git checkpoint

Committed milestones:

- `d3c6580` - tagged pre-vNext baseline;
- `46df875` - domain vNext foundation;
- `bad4a0f` - design system and Motion Lab;
- `36e2577` / `4191b70` - local Feed foundation and device-gate clarification;
- `59364e3` / `912c2a9` / `ec301bc` - v1.1 corrections and delta gate;
- `d6f978f` / `74efc4b` - Phase 4 and its software gate;
- `049c8f1` / `52582b2` / `dabfab8` - Phase 5 backend, sync and gate;
- `c7adc9d` - Phase 6A;
- `1097988` - Phase 6B.

Uncommitted Phase 6C files are intentionally listed by `git status`; none were
discarded during cleanup. The next development iteration should begin by
reviewing that exact diff and creating its checkpoint before adding Phase 6D.
