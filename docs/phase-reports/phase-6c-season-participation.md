## Phase completed

Phase 6 is not complete. This report closes the bounded Phase 6C iteration:
canonical local Season/Boss participation and server-authority validation.
Branch: `codex/phase-6c-season-participation`.

## Scope actually completed

- Added an immutable local participation state keyed by Season ID/revision with
  join time, completed day set and one Boss participation timestamp.
- Added a repository boundary committing participation metadata and its
  canonical v2 event in one SQLite transaction.
- Added a coordinator for `season_joined`, `season_day_completed` and
  `boss_participated` with local idempotency, day availability, active package,
  immutable revision, Boss schedule and route checks.
- Repeated join/day/Boss actions are no-ops and cannot duplicate events or
  client sequence numbers.
- A changed active Season revision blocks further transitions instead of
  silently applying old participation to new content.
- Added server-side Season event validation inside `ingest_events_v2`:
  server-owned active Season/revision, bounded offline grace, day availability,
  prior join, server-created Boss identity/content revision, route existence and
  advanced-route safety approval.
- Added `season_day_completions` as the per-day server idempotency boundary;
  `season_participation.completed_days` is derived from those unique rows.
- `artifact_unlocked` submitted by a client is always rejected as
  `invalid_transition`. Founder reward issuance remains server-authoritative.
- Added focused local transaction/transition tests and static Supabase contract
  assertions.
- Re-audited the completed slice before continuation and corrected two concrete
  fail-closed gaps: cached participation now verifies its embedded Season ID,
  and server Season mutations run only after generic assignment validation.
- Server participation additionally rejects events timestamped before the
  user's recorded join and rejects Season events carrying assignment/attempt
  identities before applying any projection mutation.

## Files changed

- `mobile/lib/features/season/domain/season_participation_state.dart`: typed
  immutable local state.
- `mobile/lib/features/season/domain/season_participation_repository.dart`:
  atomic commit contract.
- `mobile/lib/features/season/application/season_participation_coordinator.dart`:
  join/day/Boss transition policy and canonical events.
- `mobile/lib/infrastructure/sqlite/sqlite_season_participation_repository.dart`:
  metadata plus event-log transaction.
- `mobile/lib/infrastructure/sqlite/sqlite_vnext_store.dart`: participation
  adapter exposure.
- `supabase/migrations/202607130005_vnext_backend.sql`: per-day completion table,
  RLS, grants and restrictions.
- `supabase/migrations/202607130006_vnext_rpc.sql`: Season/Boss authority helper
  integrated into v2 ingestion.
- `tests/supabase-vnext-contract.test.mjs`: server-authority source assertions.
- `mobile/test/features/season/season_participation_coordinator_test.dart`:
  transition, idempotency, revision and rollback coverage.
- `docs/phase-reports/phase-6c-season-participation.md`: this report.

## Architecture decisions

Season participation remains an optimistic local event flow, but reward and
authority do not move to the client. The client records only participation
facts bound to a validated server package. The server independently resolves
the active Season/Boss and rejects identities, revisions, routes or schedules
that do not match server-owned rows.

Local state and canonical event append share one transaction. A failed event
insert rolls the metadata update back. Server day rows use a composite primary
key and Boss participation retains its existing unique key, so a second event
ID cannot inflate completion or participation counts.

Founder artifact unlock is deliberately absent from the local coordinator and
rejected by ingestion. A future server projection/reward contract must issue it.
This avoids turning a visible reward into a client-generated claim.

The Phase 5 Supabase migrations are still repository-only and have never been
applied to an external environment, so their source was extended before first
deployment. If any environment applies those versions, subsequent changes must
move to a new additive migration rather than modifying applied files.

## Data/migration impact

- SQLite schema remains version `6`; participation state uses the versioned key
  `season.participation.<seasonId>` in `app_metadata`.
- Local state reset continues to clear participation through the existing full
  metadata reset.
- Cloud source adds `season_day_completions(season_id,user_id,day)` with RLS and
  no authenticated direct writes.
- Server updates `completed_days` from unique completion rows instead of client
  payload counters.
- No artifact ownership table or social aggregate mutation was added.
- No remote migration was executed.

## UI/motion result

No UI, motion or media changes were made. The coordinator is not connected to
production presentation and Phase 6 capabilities remain unadvertised.

## Dependencies and environment mutations

- `pubspec.yaml`/lockfile changes: none.
- `pub get` executed: no.
- System tools, SDKs and packages installed: none.
- Xcode, Android SDK, Docker, Supabase CLI, PostgreSQL and standalone
  `impellerc`: not installed or invoked.
- External credentials/services used: none.

## Tests run

- `dart format lib test` - 217 files, clean.
- `dart analyze` - no issues.
- Targeted locked Flutter suite for all Phase 6 Season and sync coordinator
  contracts - 21 passed.
- `node --test tests/supabase-vnext-contract.test.mjs` - 5 passed.
- `git diff --check` - clean.
- Full Flutter/Node regression suites were intentionally not rerun to preserve
  the user-requested weekly budget. No current full-suite result is claimed.

## Feature flags and safe defaults

All production defaults remain false. Season, Boss and social capability
revisions are still absent from `MayhemRemoteCapabilities.current`; no remote
response can activate them. No composition root exposes the participation
coordinator to production UI. New Feed and remote content behavior is unchanged.

## Gates

### Software gate

Closed only for the Phase 6C local transition and repository-source server
validation slice. Local atomicity/idempotency, cache identity validation and
side-effect ordering have green focused coverage. Full Phase 6 and live SQL
acceptance remain open.

### Manual/device gate

Open and non-blocking. No participation UI, accessibility, lifecycle or
physical-device performance check was performed.

### External-service gate

Open and non-blocking. PostgreSQL has not parsed or applied the modified source.
RLS, helper execution privileges, offline grace, concurrent duplicate events
and deployed ingestion behavior require disposable Supabase E2E.

### Asset/content gate

Open and non-blocking. No real Season/Boss rows, reviewed routes, Founder art or
Social Reset content were published.

## Known limitations

- Artifact issuance and ownership projection are not implemented.
- Boss participation does not yet update a thresholded social aggregate.
- Server validation is static-source tested only, not PostgreSQL-executed.
- Local Season day availability currently derives day boundaries as UTC
  24-hour offsets from the Season start; product timezone policy still requires
  external content/device acceptance.
- No presentation, recovery prompt for revision replacement or historical
  Season archive exists.
- Complete project regression remains required before Phase 6 completion.

## Next phase readiness

The next bounded slice can implement server-issued artifact ownership and
thresholded social aggregation/projection, still without enabling UI. After
that, a disposable Supabase deployment should compile migrations and exercise
concurrent join/day/Boss ingestion before any Phase 6 capability is advertised.
