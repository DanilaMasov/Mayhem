> **Historical, non-authoritative plan.** Use `MAYHEM_CURRENT_SPEC_v1.2.md` and
> `CURRENT_STATUS.md` for current work.

# MAYHEM Feed vNext execution plan

This plan implements the July 2026 master specification in phases. The reviewed
source has SHA-256
`ed92f43c0d8cb8a36a8e4e55e95224c412ef04a0e84f6dbbe7322a768b6ed24e`.
The Flutter application in `mobile/` is the only production target. Root web
files are a frozen reference prototype and content migration input.

## Baseline assessment

### Preserve

- Flutter iOS/Android shell and portrait mobile target.
- Domain/application/infrastructure separation already present.
- SQLite snapshot, append-only event journal and atomic reflection writes.
- Stable quest IDs, 50 regular quests, 5 bosses, 55 guides and 29 rehearsals.
- Preparation, low-pressure routes, safe exit and local-only note behavior.
- Event sync batching, partial acknowledgements and exponential retry.
- Existing Node, content, domain, widget and transport tests as regressions.

### Replace or isolate

- `TodayController` as the product root.
- `GameState` as the future Feed/Rank/Momentum/Season aggregate.
- Today/Daily Drop dashboard as the home screen.
- Deterministic local Daily Boss as the production assignment model.
- Energy as an action gate and modifier dice as a core Feed mechanic.
- `src/data.js` as the production content source.
- Current theme and Material-card composition as the new design base.

### P0 engineering gaps

1. No immutable content revision in current events or active quest state.
2. No transactional per-installation client sequence.
3. Event parsing is all-or-nothing; one corrupt row can block bootstrap.
4. The snapshot is repaired from a full replay, not used as a tail checkpoint.
5. No vNext identity, assignments, attempts, projections or Momentum tables.
6. Sync is not connected to bootstrap/lifecycle and has no reconciliation base.
7. No secure anonymous auth session implementation.
8. Android production manifest previously lacked `INTERNET`.
9. UI strings are embedded in widgets and there is no locale architecture.
10. No typed Feed state, declarative tab shell or deep-link-ready routing.

## Phase 0: baseline and repository boundary

Existing files touched:

- root ignore/readme/package metadata;
- Android production manifest;
- mobile README.

New files:

- `.github/workflows/ci.yml`;
- `docs/adr/0001-feed-first-migration.md`;
- this execution plan;
- a phase report.

Risks:

- accidentally committing generated artwork or secrets;
- making CI depend on an unpinned Flutter release;
- rewriting Git history while preserving a baseline tag.

Gate:

- local baseline checks green;
- baseline commit and tag exist;
- generated pet work is not tracked in the active tree;
- production target and legacy web boundary are explicit.

## Phase 1: Domain vNext and safe local migration

Existing files touched:

- `mobile/lib/main.dart` only through a later bootstrap adapter;
- SQLite connection/migration code;
- legacy engine only to remove the hard Energy block;
- test fakes and migration fixtures.

New modules:

- `core/clock` and deterministic timezone-aware clock contracts;
- `features/feed/domain` content revisions, batches and assignments;
- `features/challenge/domain` attempts, outcomes and legal transitions;
- `features/progress/domain` traits, XP and rank projections;
- `features/streak/domain` Momentum and shield policy;
- repository ports and SQLite vNext adapters;
- event envelope v2, sequence allocator, checkpoint and quarantine.

Migration risks:

- losing legacy XP or reflections;
- double-importing completion events;
- attaching history to the wrong content revision;
- partial schema creation on upgrade;
- timezone differences between legacy noon boundaries and Momentum days.

Required tests:

- fresh schema and upgrade from database v4;
- rollback on failed validation;
- deterministic legacy stat mapping;
- reflection preservation;
- sequence uniqueness under concurrent writes;
- corrupt event quarantine and checkpoint tail replay;
- legacy Today regression tests.

## Phase 2: design system and Motion Lab

Create centralized tokens, typography, pressable/hold controls, selective glass,
motion preferences, Core and Sigil fixtures, Feed paging physics and a dev-only
Motion Lab. Validate 360x800, 390x844, 430x932 and 412x915 with text scale up to
1.6. No production Feed business logic is coupled to visual prototypes.

Status on 2026-07-13:

- **Software/design-system gate: passed.** Analyzer, unit/widget/golden checks,
  required viewport coverage, Dynamic Type and reduced-motion/transparency
  variants are green on the available host.
- **Physical-device performance gate: deferred and open.** It requires frame
  timings, haptics, thermal behavior and interaction checks on representative
  physical iOS and Android devices before `new_feed_enabled` becomes the default
  or an internal beta is distributed.

Simulator/emulator runs are functional and visual checks only. They do not
satisfy physical-device performance acceptance. The open performance gate does
not block Phase 3 implementation behind the disabled feature flag.

The project does not invoke or depend on a standalone `impellerc` binary. Shader
and asset compilation stays on Flutter's standard pipeline. The current host
SDK cache issue may require `--no-test-assets` for local tests, but it is not a
project dependency or a reason to install/repair system tooling in this task.

## Phase 3: local-first vertical slice

Introduce typed state management and declarative routing after dependency and
license review. Build bundled vNext content, local batch selection, full-screen
Feed items, impressions, skip reasons, Hold Accept, persistent active capsule,
attempt/completion, optional reflection, optimistic progress/Momentum and reward
sequence. Kill/restart and duplicate-callback tests are release gates.

All Phase 3 work remains behind `new_feed_enabled = false`; legacy Today is the
production default. Run every available locked analyze/unit/widget/golden/
integration check. Functional simulator/emulator coverage should be added when
available, but only physical-device evidence can close performance acceptance.

## Phase 4: onboarding, Journey and You

Implement calibration, safety revision, initial profile, the Feed/Journey/You
shell, trait constellation, Momentum calendar, history with note retrieval,
rank progression, profile presence, settings, localization and accessible
motion/transparency preferences. Migrated users keep their history and do not
repeat onboarding without a versioned reason.

## Phase 5: backend vNext

Build and test disposable Supabase migrations, anonymous auth, secure session
storage, installation registration, bootstrap/feed APIs, event ingestion v2,
server projections, reconciliation, remote versioned content, account linking
and cloud deletion. The first render remains local and private note bodies are
never uploaded by default.

## Phase 6: Season 0 and live feed

Add the seven-day Social Reset package, server-defined Boss routes, real
collective aggregates with thresholds, Founder artifact and bounded media
lifecycle. No social number renders without a real qualifying sample.

## Phase 7: launch hardening

Finalize identifiers/signing, policy URLs, crash and analytics vendors,
notification timing, icons/splash/store assets, migration QA, backend limits,
real-device performance/accessibility and rollback flags. Legacy Today is
removed only after migration confidence and a recovery window.

## Dependency discipline

No system package is installed by this plan. Project dependencies are added only
in the phase that needs them, recorded in the lockfile, and checked for license,
maintenance and platform fallback. Secure tokens will not be simulated with a
plain SQLite implementation to avoid a false security claim.

Xcode, Android SDK components, simulators, emulators and other system tooling
require a separate explicit user request. Missing device tooling never triggers
an automatic installation or blocks feature-flagged local implementation.
