# Phase completed

Phase 1 - Domain vNext and safe local migration.

## What changed

- Added injected wall/UTC/monotonic Clock contracts.
- Added immutable vNext content, Feed assignment, challenge attempt/result,
  progress, four-trait, Momentum, difficulty, rank, reflection, Season and media
  domain entities.
- Added separate repository ports for content, Feed, attempts, progress,
  Momentum, reflections and Season.
- Added legal challenge transitions with distinct attempted/completed outcomes,
  penalty-free defer/resume and no Energy dependency.
- Added configurable reward policy: 60% attempted, 100% completed, bounded
  reflection and advanced-route bonuses.
- Added deterministic largest-remainder mapping from Charisma/Boldness/
  Networking to Initiation/Expression/Connection/Presence without XP loss.
- Added rule-based, version-ready Rank, Momentum/Shield and Difficulty policies.
- Added canonical event envelope v2 with immutable content revision,
  per-installation sequence and recursive private-note rejection.
- Added transactional SQLite v2 outbox allocation and bounded tail loading.
- Raised `mayhem.db` from version 4 to 5 with additive tables only.
- Added legacy snapshot/event/reflection import, stable local identity, migration
  marker and safe-default `new_feed_enabled = false`.
- Added projection checkpoint persistence, tail replay and corrupt-event
  quarantine. Legacy journal loading now skips and locally records invalid rows
  instead of blocking startup.
- Removed the hard Energy acceptance gate from the legacy engine. Energy remains
  a compatibility/readiness signal until the Today flow is retired.

## Files changed

- `mobile/lib/core/clock`, `feature_flags`, `sync`, `database`: shared vNext
  contracts, event envelope and projection infrastructure.
- `mobile/lib/content/domain`: immutable content revision and repository.
- `mobile/lib/features/*/domain`: feature-first entities, policies and ports.
- `mobile/database/migrations/005_feed_vnext.sql`: canonical additive schema.
- `mobile/lib/core/database/migrations/*`: generated SQL and Dart migrator.
- `mobile/lib/infrastructure/sqlite/*`: v2 outbox, checkpoints and upgraded legacy
  store.
- `scripts/export_mobile_migrations.mjs`: deterministic SQL-to-Dart export.
- `scripts/test_mobile_migration.py`: real SQLite fresh/upgrade/rollback tests.
- `mobile/test/core`, `mobile/test/features`, `tests/mobile-migration-contract`:
  Phase 1 regression coverage.

## Architecture decisions

- Domain vNext is built beside legacy code; `TodayController` was not expanded.
- SQL has one versioned source and generated Dart output checked by CI, so tests
  and the app cannot silently drift to different schemas.
- Private note text is stored only in `private_reflections`; event v2 rejects
  note-body keys before persistence or transport.
- Legacy rounding uses largest remainder to satisfy both the specified weights
  and exact total-XP preservation.
- One active attempt is enforced locally by a partial unique SQLite index.
- Exact Rank ladder values remain configuration, not widget constants.

## Data/migration impact

- Database version: 4 -> 5.
- Old tables are retained; no `DROP`, destructive `DELETE` or data reset exists
  in the migration.
- Existing installation ID is reused. A stable local user ID and sequence zero
  marker are created transactionally when absent.
- Legacy total XP becomes a progress checkpoint with four trait values.
- Legacy completion events become revision-1 imported attempts; snapshot-only
  completions fill missing history deterministically.
- Reflections are linked to the latest matching imported completion where
  possible and copied with `sync_preference = local_only`.
- A failure in the sqflite upgrade callback rolls back the v5 transaction; the
  real SQLite harness verifies that the v4 snapshot survives rollback.

## UI/motion result

No Feed UI or motion was added in this phase. The legacy UI still launches and
behaves as before, except low Energy no longer blocks Accept. New Feed remains
disabled by default.

## Tests run

- `node --test tests/*.test.mjs`: 15 passed.
- Real SQLite schema: fresh database, v4 upgrade, sequence uniqueness and failed
  migration rollback passed.
- Dart v5 migrator test: XP, attempts, private reflection, identity, feature flag
  and idempotent marker passed.
- `flutter test --no-pub --no-test-assets -j 1`: 50 passed.
- `dart format --output=none --set-exit-if-changed lib test`: clean.
- `dart analyze`: no issues.
- Mobile content and Supabase seed generated checks: unchanged and green.

## Performance/accessibility

- Projection replay applies only the sequence tail after a checkpoint.
- Event reads are bounded and sequence indexed by schema.
- No animation, media or accessibility behavior changed in Phase 1.
- New domain states do not encode meaning through color or motion.

## Known limitations

- The exact schema executes on real SQLite and the Dart data migrator is tested
  independently, but a physical iOS/Android upgrade from an installed v4 build
  still belongs to beta device migration QA.
- A production platform provider for the user's IANA timezone ID is not wired;
  domain code already requires injection and never guesses an ID.
- Checkpoint/outbox adapters are not yet connected to app bootstrap because the
  new Feed flag remains false.
- Legacy imported attempts use explicit revision `1` and require the bundled
  legacy content adapter for historical copy until the versioned content source
  is activated.
- Final full Rank thresholds are deliberately not selected by this phase.
- New server/database DTO code generation is deferred until typed state/routing
  dependencies are reviewed; current files are behavior-focused domain models,
  not transport DTOs.

## Next phase readiness

Phase 2 can build design tokens, primitives and Motion Lab without coupling to
legacy `GameState`. Phase 3 can then consume the tested vNext entities and
repositories for the local-first Feed vertical slice.
