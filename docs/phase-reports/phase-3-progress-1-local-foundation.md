> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

# Phase 3 progress 1: local-first Feed foundation

Date: 2026-07-13

Branch: `codex/feed-vertical-slice`

Production target: `mobile/`

Status: in progress. This is not a Phase 3 gate sign-off.

## Scope delivered

- Bundled vNext adapter with 11 challenges, 4 micro-trainings, 3 scenarios and
  2 Season placeholders. Every revision is safety-reviewed, immutable and has
  a low-pressure route.
- Deterministic 20-item local batch policy with a challenge first, bounded
  early intensity, type diversity, no duplicate content and 24-hour expiry.
- Offline Feed session bootstrap that imports bundled revisions, reuses a
  usable batch, regenerates an expired batch and restores an active attempt.
- Idempotent impression, open and typed skip-reason commits. The local timestamp
  and canonical event are one transaction.
- Unique assignment attempt invariant in additive SQLite v6.
- Framework-neutral challenge coordinator for Accept, Attempted, Completed,
  optional reflection, XP, trait progress, Difficulty, Momentum and Rank.
- Atomic resolution: attempt, private reflection, progress, Momentum and event
  sequence commit together or roll back together.
- Cold restoration and duplicate callback handling. Repeating a resolution is
  a no-op and cannot apply reward twice.
- Private note bodies remain in `private_reflections`; event validation rejects
  note text at any payload depth.
- Persisted `active` content state and a revision checksum that includes safety
  metadata, preventing stale activation and silent safety mutation.

## Architecture decisions

- UI state and persistence are separated. Feed/challenge coordinators depend on
  repository ports and can be wrapped by Riverpod without moving rules into a
  widget or provider.
- Feature-scoped SQLite adapters own content, Feed, challenge, progress,
  Momentum and reflection ports. A shared `SqliteVNextContext` keeps
  multi-feature transitions on one connection and transaction, while
  `SqliteVNextStore` remains a 32-line composition root.
- `VNextDatabase` keeps the transaction boundary testable without adding a
  second SQLite runtime package.
- Attempted and Completed share one resolution pipeline. The outcome changes
  reward/count semantics, but both are valid terminal results and both may earn
  one Momentum day.
- Rank policy and ID generation are injected. Thresholds therefore remain
  replaceable by remote configuration and tests remain deterministic.
- Missing content or an incomplete stored batch fails explicitly. The app does
  not invent fallback assignments or duplicate content to appear healthy.
- No Riverpod, router, FFI test database or other dependency was installed in
  this pass. Existing `pubspec.yaml` and lockfiles remain unchanged.

## Verified behavior

- Accept persists an active attempt and canonical event before UI success.
- A new store instance restores the same active attempt.
- One assignment cannot create two attempts.
- Attempted earns 60% base XP and continues Momentum.
- Completed earns 100% base XP.
- Optional reflection adds at most the configured 10% bonus.
- A repeated result callback leaves XP, Momentum and events unchanged.
- An injected event-write failure rolls back attempt state, projection,
  reflection and interaction timestamps.
- Inactive revisions are excluded from the local Feed query.
- Private note text is retrievable locally and absent from every event payload.

## Verification

- Dart analyzer: no issues.
- Flutter: 82 tests passed with `--no-pub --no-test-assets -j 1`.
- Node: 16 tests passed.
- Generated migrations: v5 has 17 statements; v6 has 2 statements.
- Real SQLite: fresh schema, v4 upgrade, uniqueness and rollback passed.
- `git diff --check`: clean.

## Still open for Phase 3

1. Complete dependency/license review, then add Riverpod and a declarative
   router as required by the master specification.
2. Wire the vNext composition root and new Feed shell behind
   `new_feed_enabled`; keep legacy Today as the default until the gate passes.
3. Build production Feed item presentations for Challenge, training, scenario
   and Season fixture using the Phase 2 design system.
4. Connect visibility thresholds to impression commits and present typed skip
   reasons in the premium sheet.
5. Add preparation adapter for existing guide/rehearsal content.
6. Build Hold Accept, persistent Active Challenge Capsule, result entry,
   optional reflection and standard Reward sequence.
7. Return to the correct Feed position with updated Progress and Momentum.
8. Add widget/integration/golden coverage for the complete offline flow,
   app-kill restoration, duplicate callback and Reduce Motion.
9. Run simulator/emulator functional and visual smoke when tooling is available.
10. Before enabling Feed by default or internal beta, close the separate
    physical iOS/Android performance gate with real-device evidence.

The current production UI is intentionally unchanged, so this progress report
makes no visual-quality or end-to-end user-flow claim.
