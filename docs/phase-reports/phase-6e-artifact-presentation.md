> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Phase 6 is not complete. This report closes the bounded Phase 6E repository
slice: durable server-owned artifact reconciliation and gated presentation.
Branch: `codex/phase-6e-artifact-presentation`.

## Scope actually completed

- Added a local immutable ownership model and read port for Founder artifacts.
- Carried `ownedArtifacts` from every fresh authoritative server projection
  into the reconciled state.
- Persisted the exact ownership snapshot in the same SQLite transaction as the
  server projection revision, progress and Momentum.
- Stale server revisions cannot replace newer ownership; malformed local cache
  is deleted and returns an empty result. Ownership carries the same projection
  revision, so a missing/mismatched cache invalidates the checkpoint and is
  restored by the next authoritative sync.
- Added an application controller that presents only ownership matching the
  currently active validated Season revision, Boss event and artifact catalog.
- Added a post-reconciliation callback so an open app can refresh Journey and
  artifact presentation without waiting for restart.
- Removed the unconditional fake artifact placeholder from You.
- Added a real artifact tile that appears only when both Season and Boss gates
  are enabled and server-issued matching ownership exists.

## Files changed

- Season artifact ownership domain model, repository port and presentation
  controller.
- Projection reconciliation model/service and SQLite reconciliation store.
- vNext sync coordinator and runtime post-sync refresh boundary.
- You screen and shell feature-gate composition.
- Projection, SQLite, controller, sync, widget and golden tests.
- `phase4_you_390x844.png`: reviewed honest no-artifact baseline.

## Architecture decisions

Ownership is a server projection, not a client event or locally unlockable
reward. The client replaces the exact list only when a newer authoritative
projection is accepted. Progress, Momentum, projection revision and ownership
commit atomically, preventing a UI reward from getting ahead of sync state.

The snapshot uses `app_metadata` rather than a new event/history table. It is
derived server state with one current value, follows the established Season
cache pattern and is cleared by local reset. A schema v7 migration would add
operational cost without improving this single-snapshot contract.

The application controller depends on Season and ownership ports, not Supabase
models or SQLite. It intersects ownership with the validated active package;
historical, unknown, wrong-revision and wrong-Boss rows are not presented.

You no longer advertises a reward that does not exist. Even real cached
ownership remains hidden unless both local Season and Boss gates are enabled.
Current release capabilities cannot enable either gate.

## Data/migration impact

- SQLite remains schema version 6; no migration or user-data rewrite occurred.
- Added `sync.owned_artifacts.v1` as an exact JSON snapshot in `app_metadata`.
- The snapshot embeds its server projection revision; a mismatch makes the
  local reconciliation checkpoint stale instead of silently losing rewards.
- Snapshot writes share the existing projection reconciliation transaction.
- Corrupt snapshot data is deleted fail-closed.
- Local reset already clears `app_metadata`, so ownership cannot cross a local
  identity reset.
- No cloud migration changed in this slice.

## UI/motion result

- Removed the always-visible outlined placeholder from You.
- A real owned artifact uses a compact icon, server package title and success
  boundary only when the full gate and ownership contract are satisfied.
- Empty, expired, disabled or malformed states render no fake reward.
- The updated 390x844 You golden was visually inspected; the full clean golden
  comparison passed.
- No new motion, media or haptic behavior was introduced.

## Dependencies and environment mutations

- Package manifests and lockfiles: unchanged.
- Package resolution, network download and dependency update: none.
- Xcode, Android SDK, simulators, Docker, Supabase CLI, system packages and
  standalone `impellerc`: not installed or invoked.
- Existing locked Flutter/Dart, bundled Codex Node and Python/SQLite runtimes
  were used. Flutter state remained under `/private/tmp`.

## Tests run

- `dart format`: clean.
- `dart analyze --no-pub`: no issues.
- Focused projection, SQLite, Season controller, sync and shell tests: passed.
- Full locked Flutter unit/widget/golden suite: 179 passed.
- Full Node suite: 22 passed.
- Content export: 50 quests, 5 bosses, 55 guides, 29 dialogs, 5 modifiers.
- Migration export: v5 17 statements, v6 2 statements.
- Supabase seed export: 50 quests and 5 bosses.
- Real SQLite: fresh v6, v4 upgrade and rollback passed.
- Clean post-update golden comparison: 3 passed.
- Live PostgreSQL and physical-device runtime are not claimed.

## Feature flags and safe defaults

All production defaults remain false. Artifact presentation additionally
requires both `season_zero_enabled` and `boss_raid_enabled`; release overrides
remain inert and current remote capabilities do not advertise Season/Boss
revisions. `new_feed_enabled` remains false and legacy Today remains default.

## Gates

### Software gate

Closed for Phase 6E ownership reconciliation and gated presentation. Fresh vs
stale server projection, atomic storage, corruption, package matching,
post-sync refresh, disabled state and real widget rendering have green tests.
The complete Phase 6 software gate remains open for Season/Boss participation
screens and failure/expiry UX.

### Manual/device gate

Open and non-blocking. Artifact layout still needs VoiceOver/TalkBack, Dynamic
Type and representative physical iOS/Android review. The general performance,
memory, thermal, lifecycle and migration gate also remains open.

### External-service gate

Open and non-blocking. No disposable Supabase/PostgreSQL environment verified
artifact issuance, projection ACK, RLS, concurrent Boss events or deletion.

### Asset/content gate

Open and non-blocking. The tile deliberately uses a structural system icon;
Founder artwork, approved titles, Season/Boss content and localization still
require production review before enabling capabilities.

## Known limitations

- The app has no production remote-auth/sync composition or secure platform
  session store, so release capabilities remain unavailable.
- Only artifacts from the active validated Season package are shown; historical
  archive presentation is not implemented.
- Full Season day/Boss participation and expiry/error screens are still absent.
- Static repository tests cannot prove server issuance or RLS behavior.
- Physical-device and production asset acceptance remain open.

## Next phase readiness

The server reward now has a durable, honest client presentation boundary. The
next unblocked repository work is the gated Season/Boss participation surface
with explicit loading, unavailable, not-joined, active-day, Boss-window, expiry
and retry states. External Supabase, secure storage, device and content gates
continue to block enablement rather than repository development.
