# Phases 0-3 v1.1 delta software gate

## Phase completed

Phases 0-3 delta audit against specification v1.1. Branch:
`codex/phase-4-v1-1`.

## Scope actually completed

- Corrected `reward_policy_dev_v1`: Attempted/Completed multipliers, one-time
  reflection bonus, safety-approved advanced bonus, seven-day diminishing
  returns and integer half-up rounding.
- Froze the existing tested difficulty formula as `difficulty_model_dev_v1`
  without substituting the fallback coefficients intended only for an absent
  implementation.
- Added the complete deterministic `rank_config_dev_v1` ladder.
- Corrected legacy progress checkpoint fallback from out-of-range difficulty
  `0.0` to the neutral valid seed `2.0`.
- Corrected computed rank progress so unmet all-trait minimums cannot display a
  false 100% next-rank state.
- Added the Momentum 20-hour anti-double-day rule and a persisted pending
  timezone-review state.
- Made full local reset rotate local identity immediately and restore every
  feature flag to false in the same transaction.
- Recorded the v1.1 product and compatibility decisions in ADR 0002.

No other Phases 0-3 behavior was rebuilt. The audit confirmed that fail-closed
flags, local identity separation, dormant authenticated Supabase transport,
deletion copy, environment policy and the deferred physical-device gate were
already compatible.

## Files changed

- `mobile/lib/features/challenge/domain/reward_policy.dart`: frozen reward
  revision and repeat calculation.
- `mobile/lib/features/challenge/application/challenge_flow_coordinator.dart`:
  rolling history input and policy revision metadata.
- `mobile/lib/features/progress/domain/difficulty_update_policy.dart`: frozen
  revision identifier.
- `mobile/lib/features/progress/domain/development_rank_config.dart`: canonical
  development rank ladder.
- `mobile/lib/features/streak/domain/momentum_state.dart` and
  `momentum_policy.dart`: accepted/pending day metadata and 20-hour guard.
- `mobile/lib/infrastructure/sqlite/sqlite_vnext_mappers.dart`: backwards
  compatible Momentum fields and valid legacy difficulty defaults.
- `mobile/lib/core/identity/local_identity_reset.dart` and
  `mobile/lib/infrastructure/sqlite/sqflite_game_store.dart`: transactional
  identity rotation and fail-closed flag reset.
- Focused policy, coordinator, persistence and identity tests.
- `docs/adr/0002-v1-1-development-policy-baseline.md`: accepted policy baseline.

## Architecture decisions

ADR 0002 freezes reward, difficulty, rank and Momentum revisions and records the
local identity boundary. Existing repositories, transaction coordinator and
JSON checkpoints remain in place; no architectural rewrite was needed.

The advanced reward bonus is fail-safe: an advanced route without explicit
safety approval receives no bonus. Difficulty remains primary-trait based until
context clusters exist. Supabase anonymous auth is intentionally not introduced
before Phase 5.

## Data/migration impact

- SQLite schema version remains `6`; no migration or destructive rewrite.
- Momentum checkpoint JSON gained optional fields. Legacy JSON restores with
  null timestamps, no pending record and `momentum_policy_dev_v1`.
- Existing identity is preserved on normal upgrade and rotated only by explicit
  full local reset.
- Reset clears local history, projections, reflections and caches, then creates
  new local identifiers and sequence zero atomically.
- Fresh schema, v4 upgrade and rollback were revalidated on real SQLite.

## UI/motion result

No Phase 0-3 UI or motion flow was redesigned. Existing widget and Motion Lab
golden tests remain green. Pending Momentum is now available as typed state for
the Phase 4 Journey UI.

## Dependencies and environment mutations

- `pubspec.yaml` changed: no.
- Lockfiles changed: no.
- `pub get` executed: no.
- System tools installed: none.
- External credentials/services used: none.
- Xcode, Android SDK, Docker, Supabase CLI and `impellerc` were not installed or
  invoked.

## Tests run

- Formatter: `dart format lib test` - 149 files checked, no pending changes.
- Analyze: `dart analyze` - no issues.
- Unit/widget/golden: `flutter test --no-pub --no-test-assets -j 1` - 90 passed.
- Content and web regression: `node --test tests/*.test.mjs` - 16 passed.
- Content export: `node scripts/export_mobile_content.mjs --check` - 50 quests,
  5 bosses, 55 guides, 29 dialogs and 5 modifiers verified.
- Migration generation: `node scripts/export_mobile_migrations.mjs --check` -
  v5 17 statements and v6 2 statements verified.
- SQL migration integration: `python3 scripts/test_mobile_migration.py` - fresh,
  v4 upgrade and rollback verified with real SQLite.
- `git diff --check` - clean before report creation.

## Feature flags and safe defaults

Production defaults remain disabled for new Feed, remote content, Season, Boss,
social proof, account linking, companion, advanced motion, rank sharing and
notifications. Missing or malformed values resolve to false. Local reset writes
all flags back as explicit false values.

No debug override exists yet; it is Phase 4 preflight scope and must be visibly
reported in diagnostics. Capability revisions now include
`reward_policy_dev_v1`, `difficulty_model_dev_v1`, `rank_config_dev_v1` and
`momentum_policy_dev_v1`.

## Gates

### Software gate

Closed for the Phases 0-3 v1.1 delta. Formatter, analyzer, Flutter, widget,
golden, content and SQLite regression evidence is green; schema and legacy
checkpoint compatibility are preserved.

### Manual/device gate

Open. Functional/visual smoke and accessibility checks still require available
simulator/emulator or physical devices. Performance acceptance specifically
requires representative physical iOS and Android devices and is not claimed by
goldens or host tests.

### External-service gate

Open and non-blocking. No Supabase project, credentials or authenticated remote
session was used. Server Momentum reconciliation and cloud-wide deletion remain
later-phase work.

### Asset/content gate

Open and non-blocking. Final Sigil/Core artwork, motion tuning, sound, legal copy
and production content approval are not claimed. Related flags remain disabled.

## Known limitations

- The offline client can persist `pending_timezone_review`, but only Phase 5
  server authority can accept a legitimate travel correction.
- Private note bodies remain local-only in application storage; platform-level
  OS backup exclusion still needs implementation and device verification before
  production launch.
- Local reset clears the media cache index. There is no production media file
  cache yet, so file-system cache deletion has no current artifact to verify.
- The rolling repeat lookup is bounded to 500 history rows; this is sufficient
  for the local development slice but should become an indexed query before
  high-volume production history.

## Next phase readiness

Phase 4 may proceed under section 1.2.2 because the software delta gate is
closed. Manual/device, external-service and asset/content gates remain open and
non-blocking. New Feed, remote content, account linking, advanced motion and all
other production flags must remain disabled.
