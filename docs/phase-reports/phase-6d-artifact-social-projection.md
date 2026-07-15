## Phase completed

Phase 6 is not complete. This report closes the bounded Phase 6D repository
slice: server-issued Founder artifact ownership and privacy-thresholded Boss
social projection. Branch: `codex/phase-6d-artifact-social-projection`.

## Scope actually completed

- Added server-owned artifact records keyed by artifact and user, bound to the
  exact Season revision and Boss event that issued them.
- A valid, accepted Boss participation issues every unique artifact from the
  server-owned Season package. Client-authored `artifact_unlocked` remains
  rejected.
- Artifact ownership is returned in the authoritative progress projection, so
  sync ACK and bootstrap can restore it without a second client event or RPC.
- Added a typed mobile `RemoteOwnedArtifact` contract with strict identity,
  revision, timestamp and duplicate validation.
- Added a cumulative social aggregate updated only by a newly inserted unique
  Boss participation. Replays are idempotent and cannot inflate the count.
- Fixed the privacy boundary: authenticated clients no longer receive direct
  table access to raw Season, Boss or social rows. `get_active_season()` removes
  publisher-provided social values and injects only a server aggregate that is
  inside its window and has reached the minimum threshold.
- Closed inherited default-PUBLIC execution on the internal security-definer
  Momentum mutation and arbitrary-user projection helpers. Only authenticated
  identity-bound endpoint RPCs remain client-executable.
- Enforced a minimum social threshold of 20 and bound each aggregate to one
  Season revision, Boss event, window and key under an advisory lock.
- All package and aggregate validation happens before participation, ownership
  or aggregate writes.

## Files changed

- `supabase/migrations/202607130005_vnext_backend.sql`: artifact ownership,
  aggregate identity, RLS and privilege boundaries.
- `supabase/migrations/202607130006_vnext_rpc.sql`: sanitized Season read,
  server reward issuance, idempotent aggregate mutation and projection output.
- `mobile/lib/features/sync/domain/backend_models.dart`: typed remote artifact
  ownership model and projection parsing.
- `mobile/test/infrastructure/supabase_transport_test.dart`: sync ACK ownership
  contract coverage.
- `tests/supabase-vnext-contract.test.mjs`: authority, ordering, privacy,
  threshold and idempotency source assertions.
- `docs/phase-reports/phase-6d-artifact-social-projection.md`: this report.
- `docs/phase-reports/development-status-2026-07-14.md`: consolidated status.
- `DEVELOPMENT_LOG.md`: implementation checkpoint.

## Architecture decisions

Artifact unlock is a server projection, not a synthetic client event. The
accepted Boss event remains the canonical participation fact; the ownership row
is a deterministic server side effect and appears in the same sync response.
This preserves installation sequence semantics and supports cross-device
recovery.

Social proof is a cumulative non-identifying metric. Account deletion removes
the user's participation and artifact rows through foreign-key cascades, while
the anonymous aggregate may remain as allowed by the deletion contract. Future
participation increments the materialized total instead of recomputing it from
personal rows that may have been deleted.

Raw Season payload is not a safe public transport because publisher data can
contain an unqualified social value. Direct authenticated reads were removed;
the security-definer RPC now strips that field and reconstructs it only from a
qualified server row. Mobile feature flags remain a second presentation gate,
not the privacy boundary.

## Data/migration impact

- Added `user_artifacts(artifact_id,user_id,season_id,season_revision,
  boss_event_id,unlocked_at)` with own-row read policy and no client writes.
- Extended `social_proof_aggregates` with Season revision and Boss identity;
  threshold must be at least 20.
- Removed authenticated direct SELECT grants for `seasons`, `boss_events` and
  `social_proof_aggregates`; approved data is exposed through RPCs.
- Revoked default PUBLIC execution from internal security-definer projection
  and Momentum helpers, preventing UUID-parameter access across users.
- SQLite remains at schema version 6 and no local rows are migrated.
- The vNext cloud migrations are still repository-only and were edited before
  first deployment. Once applied anywhere, later changes must use new
  forward-only migrations.

## UI/motion result

No UI, motion, media or navigation was changed. Artifact and social data are
typed but not presented. Season/Boss/social capabilities remain unavailable in
the production composition.

## Dependencies and environment mutations

- `pubspec.yaml` and lockfiles: unchanged.
- Package resolution or dependency updates: none.
- SDKs, system packages, Xcode, Android SDK, Docker, Supabase CLI and standalone
  `impellerc`: not installed or invoked.
- Bundled Codex Node and the existing Flutter/Dart SDK were used. Flutter test
  telemetry was redirected to `/private/tmp`; no SDK cache was modified.
- External credentials, services and network calls: none.

## Tests run

- `dart format` on changed Dart files: clean.
- `dart analyze`: no issues.
- Focused locked Flutter regression for transport, reconciliation and all
  Season slices: 30 passed.
- Full locked Flutter suite: 170 passed.
- Full Node suite: 22 passed, including 6 vNext Supabase contracts.
- Content, migration and Supabase seed exports: deterministic and current.
- Real SQLite harness: fresh v6, v4 upgrade and rollback passed.
- `git diff --check`: clean.
- PostgreSQL execution is not claimed; no database runtime is available.

## Feature flags and safe defaults

All production defaults remain false. Season, Boss and social capability
revisions are still absent from `MayhemRemoteCapabilities.current`. The new
Feed default and legacy Today behavior are unchanged. No server response can
activate this Phase 6 presentation path in the current release composition.

## Gates

### Software gate

Closed for the Phase 6D repository slice. Authority ordering, typed projection,
idempotent replay behavior, minimum threshold and raw-data privilege boundary
have focused green coverage. The complete Phase 6 software gate remains open
for production presentation and full regression.

### Manual/device gate

Open and non-blocking. No Season/Boss/artifact screen, accessibility pass,
lifecycle test or physical-device performance acceptance was performed.

### External-service gate

Open and non-blocking. PostgreSQL has not parsed or applied the migrations.
Disposable Supabase tests must verify RLS, security-definer ownership,
concurrent Boss events, advisory locking, deletion and aggregate visibility.

### Asset/content gate

Open and non-blocking. No production Season/Boss rows, reviewed routes,
Founder artwork or social copy were published.

## Known limitations

- Artifact ownership is not yet persisted into a dedicated local presentation
  store or shown in You/Journey.
- The Phase 6 production composition and all related capabilities are disabled.
- Static SQL contracts cannot prove PostgreSQL syntax, RLS behavior or
  concurrency semantics.
- No historical Season archive or expired reward presentation exists.
- A new full regression is required after the remaining Feed presentation
  wiring; the current repository checkpoint is fully green.

## Next phase readiness

The server-authority prerequisite for a gated Season/Boss/artifact UI is now in
place. The next repository P0 is the remaining Feed visibility/open/typed-skip
and preparation presentation loop, followed by a full regression. Live
Supabase, physical-device and asset/content gates stay open and continue to
block production capability enablement, not repository development.
