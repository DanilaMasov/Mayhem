> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Phase 6 is not complete. This report closes the bounded Phase 6B iteration:
offline Season package cache and fail-closed bootstrap activation. Branch:
`codex/phase-6b-season-activation`.

## Scope actually completed

- Added a narrow `SeasonPackageStore` contract for loading an active validated
  package, saving a remote snapshot and clearing it through a kill switch.
- Added a `SeasonBootstrapActivator` requiring an explicit local gate plus both
  `season_zero_enabled` and `boss_raid_enabled` before any package is cached.
- Social aggregate payload is removed before persistence unless
  `social_proof_enabled` is also true.
- Added SQLite persistence in the existing `app_metadata` table. Every read
  reconstructs the Phase 5 snapshot and reruns the strict Phase 6A mapper.
- Corrupt cached JSON is deleted fail-closed. Expired/future packages are not
  returned as active.
- Invalid replacement snapshots fail before the transaction and cannot
  overwrite the previous valid package.
- Added an optional Season activation hook to v2 bootstrap sync. Season failure
  is logged by runtime type and cannot block event upload, ACK or projection
  reconciliation.
- Added focused tests for local/remote kill switches, social stripping,
  qualified social persistence, schedule expiry, corrupt cache, atomic invalid
  replacement and non-blocking sync behavior.

## Files changed

- `mobile/lib/features/season/application/season_package_store.dart`: cache
  boundary.
- `mobile/lib/features/season/application/season_bootstrap_activator.dart`:
  local/remote gate policy and social sanitization.
- `mobile/lib/infrastructure/sqlite/sqlite_season_package_store.dart`: validated
  snapshot persistence through `app_metadata`.
- `mobile/lib/infrastructure/sqlite/sqlite_vnext_store.dart`: feature-scoped
  adapter exposure without application activation.
- `mobile/lib/features/sync/application/vnext_sync_coordinator.dart`: optional,
  non-blocking bootstrap hook.
- `mobile/test/features/season/season_bootstrap_activation_test.dart`: cache and
  activation tests.
- `mobile/test/features/sync/vnext_sync_coordinator_test.dart`: Season failure
  isolation test.
- `docs/phase-reports/phase-6b-season-activation.md`: this report.

## Architecture decisions

The cache stores the original typed remote snapshot rather than a second Season
economy/model. A read must decode and pass the strict Phase 6A mapper again, so
cached data cannot bypass current safety or threshold validation.

Activation uses two independent boundaries. The local gate must be explicitly
true, then capability-resolved Season and Boss flags must both be true. A false
gate clears the existing cache rather than merely hiding it. No Phase 6
capability revision is advertised yet, so production remote flags still cannot
activate this path.

Social proof is sanitized before persistence when its separate flag is false.
Season activation is optional to core sync and catches only at the integration
boundary, ensuring malformed seasonal content cannot delay canonical gameplay
event synchronization.

## Data/migration impact

- SQLite schema remains version `6`; no migration was added.
- One versioned metadata key is introduced: `season.active_package.v1`.
- Cache replacement and deletion use existing SQLite transactions.
- Supabase migrations and remote schemas are unchanged.
- Existing local identity, content, event and projection rows are untouched.

## UI/motion result

No UI, motion or media changes were made. No composition root supplies a
`SeasonBootstrapActivator`, and no Phase 6 capability is advertised. Season,
Boss, social proof and artifacts remain absent from production screens.

## Dependencies and environment mutations

- `pubspec.yaml`/lockfile changes: none.
- `pub get` executed: no.
- System tools, SDKs and packages installed: none.
- Xcode, Android SDK, Docker, Supabase CLI and standalone `impellerc`: not
  installed or invoked.
- External credentials/services used: none.

## Tests run

- `dart format lib test` - 212 files, clean.
- `dart analyze` - no issues.
- Targeted locked Flutter suite for Season mapper, activation/cache and sync
  coordinator - 15 passed.
- `git diff --check` - clean.
- The complete Flutter/Node regression suites were intentionally not rerun to
  preserve the user-requested weekly budget. The Phase 5 full-suite baseline is
  not claimed as a current Phase 6B result.

## Feature flags and safe defaults

All production defaults remain false. Activation requires the local gate,
`season_zero_enabled` and `boss_raid_enabled`. Social data additionally requires
`social_proof_enabled`. No Season/Boss/social capability revision was added to
`MayhemRemoteCapabilities.current`, so a server response cannot resolve these
flags true in the current client. New Feed and remote content defaults are
unchanged.

## Gates

### Software gate

Closed only for the Phase 6B cache/activation slice. Atomic replacement,
fail-closed corruption handling, kill switches, social sanitization and core
sync isolation have focused green coverage. The full Phase 6 software gate is
open.

### Manual/device gate

Open and non-blocking. No UI is wired and no physical-device lifecycle,
accessibility, background execution or performance acceptance was performed.

### External-service gate

Open and non-blocking. No live Supabase bootstrap, Season publication, Boss
participation, social aggregation or artifact reward was exercised.

### Asset/content gate

Open and non-blocking. Social Reset copy, production Boss routes, Founder art
and bounded media assets remain unapproved and unpublished.

## Known limitations

- The production composition root does not instantiate the activator.
- Phase 6 capability revisions remain intentionally absent.
- No Season participation, day completion, Boss participation or artifact
  unlock event flow is implemented.
- The cache has no historical Season archive; it stores only one active remote
  snapshot while Journey history remains event-based.
- UI, accessibility semantics and bounded media lifecycle remain outside this
  iteration.
- A complete regression suite is still required before Phase 6 completion.

## Next phase readiness

The next bounded slice can add canonical Season/Boss participation events and
server transport without enabling presentation. Capability advertisement and
composition wiring should happen only after that contract, external-service
tests and reviewed Social Reset content exist. All related flags must remain
false meanwhile.
