> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Phase 5 - Backend vNext, anonymous auth, sync and remote content. Branch:
`codex/phase-5-v1-1`.

## Scope actually completed

- Added additive Supabase vNext schema and RPC source for installations,
  immutable content revisions, versioned manifests, Feed batches and
  assignments, attempts, append-only events, progress, difficulty, Momentum,
  seasons, Boss participation, thresholded social proof, capability-gated
  flags and idempotent deletion receipts.
- Added authenticated RPC contracts for installation registration, bootstrap,
  progress, active season, Feed batch, content manifest/revisions, v2 event
  ingestion and Delete Everywhere.
- Added a typed Supabase REST transport and fake HTTP boundary. Anonymous signup
  and refresh are implemented without adding an SDK package; external identity
  linking remains delegated to an approved platform handler.
- Added a secure-session interface which explicitly forbids SQLite/plaintext
  implementations, anonymous-session reuse/refresh and remote identity-drift
  protection.
- Added durable v2 queue loading, ACK/rejection persistence, quarantine,
  bounded exponential retry with jitter and lifecycle coalescing for cold
  start, foreground and terminal-result sync.
- Added server projection reconciliation over still-pending optimistic events,
  stale-revision rejection, longest-Momentum preservation and deterministic
  exactly-once correction notices.
- Added capability-aware cached remote flags. Unknown, absent, malformed,
  duplicated or unsupported remote values resolve to false.
- Added SHA-256 content verification, typed remote manifests/revisions,
  complete-download validation and atomic local activation with bundled
  fallback and retained revisions for rollback.
- Added shared reward, difficulty, rank and Momentum golden fixtures used by
  mobile tests and asserted against server policy revisions.
- Added Delete Everywhere ordering: confirmed server deletion receipt first,
  then secure-session and local-data clearing. Failures before confirmation
  preserve the local session and data.

## Files changed

- `contracts/v1/policy_golden.json`: shared development-policy fixture.
- `supabase/migrations/202607130005_vnext_backend.sql`: additive tables, indexes,
  RLS, immutable triggers and write restrictions.
- `supabase/migrations/202607130006_vnext_rpc.sql`: server policy functions and
  authenticated vNext RPC surface.
- `mobile/lib/core/auth/`: remote session, secure-store abstraction, anonymous
  session and account-linking coordinators.
- `mobile/lib/core/crypto/sha256.dart`: dependency-free SHA-256 verification.
- `mobile/lib/core/feature_flags/remote_feature_flag_resolver.dart`: strict
  capability-aware fail-closed resolution.
- `mobile/lib/features/sync/`: backend DTOs, sync/reconciliation contracts,
  coordinator, checksum and remote-content refresh.
- `mobile/lib/features/settings/application/delete_everywhere_coordinator.dart`:
  receipt-gated cloud/local deletion ordering.
- `mobile/lib/infrastructure/supabase/`: anonymous Auth REST and typed vNext RPC
  adapters; hardened URI, array-response and error-redaction handling.
- `mobile/lib/infrastructure/sqlite/`: durable v2 queue, projection correction,
  cached flags, identity binding and remote-manifest activation.
- `mobile/test/`, `tests/supabase-vnext-contract.test.mjs`: policy, auth,
  privacy, transport, sync, reconciliation, content and SQL source coverage.
- `docs/adr/0003-authenticated-sync-and-content-manifests.md`: durable Phase 5
  architecture rationale and open validation boundary.

## Architecture decisions

ADR 0003 records the accepted boundaries. Local identity and local-first state
remain independent from Supabase anonymous auth. A remote user may be bound to
the current local identity but cannot replace or drift from it. Tokens are not
stored in SQLite; the concrete platform secure store is intentionally deferred
instead of adding an unapproved dependency.

The server projection is authoritative only at a monotonically increasing
projection revision. Reconciliation starts from that server base, reapplies
still-pending optimistic events, preserves longest Momentum and commits the
server revision plus projection atomically before exposing a correction notice.

Immutable content and rollback are separated correctly: content revisions never
change, while an active versioned manifest selects the published set. Feed batch
creation uses that same active manifest and fails instead of returning a partial
batch. Remote operations additionally require a local production gate, so a
server flag alone cannot activate this repository-only implementation.

## Data/migration impact

- Added cloud migrations `202607130005` and `202607130006`; legacy cloud
  migrations and tables are not rewritten or dropped.
- Added global manifest tables and an idempotent deletion-receipt tombstone.
  User-owned cloud rows remain RLS-scoped and cascade from `auth.users`.
- `user_events` and `content_item_revisions` are append-only/immutable.
  Authenticated clients have no direct write grants to server-owned tables.
- Delete Everywhere temporarily enables event deletion only inside the
  authenticated account-deletion transaction, verifies `auth.users` deletion
  and returns a stable receipt.
- SQLite remains schema version `6`; no local migration was added. Existing
  `event_log_v2`, `event_quarantine`, `projection_checkpoints`,
  `feature_flags_cache`, `content_item_revisions` and `app_metadata` rows provide
  the local Phase 5 persistence boundary.
- Remote content is staged inactive, checksum-validated and activated in one
  local transaction. Bundled content and old remote revisions remain available
  for fallback/rollback.

## UI/motion result

Phase 5 adds no new production UI or motion. The one-time correction notice,
Delete Everywhere and account-linking application boundaries are implemented
but are not exposed while their remote/platform gates are open. Legacy Today
remains the default surface and vNext Feed stays behind its existing flag.

## Dependencies and environment mutations

- `pubspec.yaml`/lockfile changes: none.
- `pub get` executed: no.
- Flutter/Dart packages downloaded or updated: none.
- System tools installed: none.
- Xcode, Android SDK, simulators, Docker, Supabase CLI, PostgreSQL and standalone
  `impellerc`: not installed or invoked.
- External credentials/services used: none.
- Anonymous Auth, CAPTCHA and RPC behavior were tested through local fakes only.

## Tests run

- `dart format lib test` - 206 files, clean.
- `dart analyze` - no issues.
- `flutter test --no-pub --no-test-assets -j 1` - 143 passed across the full
  unit, widget, accessibility and golden suite.
- Targeted auth/privacy/transport tests - 22 passed.
- Targeted flag/lifecycle/reconciliation persistence tests - 14 passed.
- `node --test tests/*.test.mjs` - 20 passed, including four vNext
  schema/RPC source contracts.
- `node scripts/export_mobile_content.mjs --check` - 50 quests, 5 bosses, 55
  guides, 29 dialogs and 5 modifiers verified.
- `node scripts/export_mobile_migrations.mjs --check` - v5 17 statements and v6
  2 statements verified.
- `python3 scripts/test_mobile_migration.py` - fresh, v4 upgrade and rollback
  verified on real SQLite.
- `git diff --check` - clean.
- `pubspec.yaml`/lockfile diff and executable `impellerc` source scan - empty.

## Feature flags and safe defaults

Every production/release default remains false. Release builds still ignore
debug overrides. The v2 coordinator also requires explicit local
`remoteOperationsEnabled`; it is not wired true in the application composition.

`remote_content_enabled`, `account_linking_enabled`, `new_feed_enabled`, social,
season, notification and advanced-motion flags remain disabled. A remote true
is accepted only when the record names a positive capability revision supported
by the current client. Missing, malformed, unknown, duplicated, expired or
unsupported records resolve to false, including values restored from cache.

Frozen policy revisions remain `reward_policy_dev_v1`,
`difficulty_model_dev_v1`, `rank_config_dev_v1` and
`momentum_policy_dev_v1`.

## Gates

### Software gate

Closed for the repository-only Phase 5 scope. Typed contracts, deterministic
policies, local persistence, auth/session privacy, exact ACK validation,
reconciliation, fail-closed flags, content integrity/atomic activation and
deletion ordering have green local coverage. The cloud source is additive and
statically checked, but this closure does not claim a live database deployment.

### Manual/device gate

Open and non-blocking for Phase 6. No physical iOS/Android device was connected.
Secure storage, background/foreground lifecycle, network interruption, account
linking, deletion recovery, VoiceOver/TalkBack and physical performance remain
mandatory manual acceptance. Simulator/emulator results will not close the
physical-device performance gate.

### External-service gate

Open and non-blocking. No disposable Supabase/PostgreSQL environment, Docker,
CLI or credentials were available. Migrations have not been parsed/applied by a
live PostgreSQL instance; RLS isolation, RPC transaction behavior,
`auth.users` deletion, anonymous signup/refresh, CAPTCHA/rate limits and live
idempotency/reconciliation E2E are not claimed. Related production flags remain
false.

### Asset/content gate

Open and non-blocking. No remote manifest, production content revision, season,
Boss, legal copy or media asset was published. The publisher must calculate
revision checksums and atomically switch one active manifest per locale. Bundled
reviewed content remains the only enabled source.

## Known limitations

- `SecureSessionStore` has no concrete Keychain/Keystore implementation yet;
  remote operations therefore remain outside production composition.
- External account linking requires an approved platform identity handler and
  provider setup. It deliberately throws when no handler is supplied.
- Supabase SQL is source- and contract-tested only. Live PostgreSQL compile,
  RLS adversarial tests and deployed Auth behavior remain in the external gate.
- The remote content publisher/admin workflow is not implemented; only the
  immutable storage, manifest and client activation contract exists.
- Delete Everywhere recovery across a failure between secure-session clearing
  and local SQLite clearing still needs physical/manual fault-injection review.
- The inherited vNext Feed presentation still lacks the full
  Accept/Attempt/Reward action loop, although its Phase 3 domain coordinators
  remain covered.
- Physical-device performance acceptance remains open and cannot be closed by
  these tests.

## Next phase readiness

Phase 6 repository work may proceed under section 1.2.2. Season, Boss, social
proof and remote-content implementations can build on the typed Phase 5 API,
but their production flags must remain false while external-service,
asset/content and manual/device gates are open. Before internal beta or enabling
remote operations, complete disposable Supabase migration/RLS/RPC E2E, select a
platform secure-store implementation, validate anonymous-auth abuse controls
and complete the physical-device performance gate.
