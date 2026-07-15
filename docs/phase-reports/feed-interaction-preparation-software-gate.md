> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Cross-phase P0 - Feed interaction and preparation presentation. This closes the
remaining local Phase 3 Feed software gap without enabling the new Feed in
production. Branch at implementation time:
`codex/feed-interaction-preparation`.

## Scope actually completed

- Connected foreground visibility to an idempotent impression after a stable
  600 ms threshold. Backgrounding cancels the timer and resume starts a fresh
  visibility window.
- Made open, skip and accept first commit the same idempotent impression, so an
  explicit action cannot produce an impossible funnel without a view.
- Connected typed skip with exactly four reasons: not now, too intense, wrong
  context and not relevant. A committed skip advances the Feed.
- Added challenge preparation over the existing reviewed guide and dialogue
  catalogs: three practical steps, suggested phrases, alternate and advanced
  routes, a safe exit and an interactive branching rehearsal.
- Replaced the accidental first-eleven launch selection with a deterministic
  trait-balanced mix of six level-1, four level-2 and one level-3 challenge.
- Added bundled-catalog activation. Superseded bundled revisions are
  deactivated per locale while remote manifest activation remains a separate
  authority boundary.
- Made cached Feed batches fail forward: a stored batch that references content
  no longer active is replaced with a compatible current batch instead of
  crashing or showing stale copy.
- Tightened `ingest_events_v2`: Feed interaction events require assignment
  identity, reject attempt identity and validate skip reasons server-side.
- Added localized preparation, rehearsal, skip and failure copy.

## Files changed

- `mobile/lib/features/challenge/domain/challenge_preparation.dart`: validated
  guide and branching-rehearsal presentation model.
- `mobile/lib/content/data/bundled_vnext_content_adapter.dart`: launch mix and
  adaptation of reviewed guide/dialogue content.
- Content repository port and SQLite adapter: exact bundled activation.
- Feed session, view controller and runtime composition: batch compatibility,
  interaction coordinator and clock wiring.
- `mobile/lib/features/feed/presentation/vnext_feed_screen.dart`: visibility
  threshold, preparation/rehearsal and typed-skip sheets.
- `supabase/migrations/202607130006_vnext_rpc.sql`: canonical interaction-event
  validation.
- Unit, widget, SQLite, contract and golden tests plus two new reviewed golden
  surfaces.

## Architecture decisions

The widget observes lifecycle and visibility but does not write events. A
framework-neutral controller delegates canonical persistence to the existing
`FeedInteractionCoordinator`, preserving transaction and idempotency rules.

Preparation is a read-only presentation projection over the canonical bundled
guide/dialogue catalogs. This avoids a second editorial source and keeps
legacy Today compatible while vNext remains disabled.

Bundled activation and remote manifest activation stay separate. Importing a
new app bundle may replace older bundled revisions, but it cannot override an
active validated remote manifest by pretending to be remote content.

A cached batch is treated as an immutable historical assignment only while all
its referenced content identities remain active. An incompatible cache is not
deleted; a new batch is generated and stored, preserving event history and
diagnostics.

## Data/migration impact

- SQLite schema remains version 6; no migration or destructive reset is
  required.
- Existing assignments, interaction timestamps and canonical event tables are
  used.
- Existing bundled rows for the locale are deactivated only when absent from
  the current bundled catalog; exact current identities are activated.
- The not-yet-deployed vNext RPC migration gained stricter event validation.
  Once deployed anywhere, equivalent changes must be a new forward-only
  migration.
- Private reflection and rehearsal choices remain local and are not added to
  sync payloads.

## UI/motion result

- Feed cards expose compact preparation and skip icon actions with tooltips.
- Preparation uses Guide and Rehearsal tabs; rehearsal changes only the local
  dialogue branch and grants no hidden XP or parallel reward.
- Typed skip uses a bounded option sheet and advances only after persistence
  succeeds.
- Reduce Motion removes animated page advance; lifecycle cancellation prevents
  background impressions.
- Verified at 390x844 and text scale 1.6. Reviewed goldens include the updated
  Feed/action states and new preparation and skip sheets.

## Dependencies and environment mutations

- `pubspec.yaml`, `pubspec.lock` and all package manifests: unchanged.
- Dependency resolution, package updates and network downloads: none.
- Xcode, Android SDK, simulators, Docker, Supabase CLI, system packages and
  standalone `impellerc`: not installed or invoked.
- Locked Flutter/Dart, bundled Node and the existing local SQLite harness were
  used. Flutter state was redirected to `/private/tmp`.
- A `--no-pub` Flutter web preview was attempted but the existing Flutter cache
  has no usable DWDS directory. Nothing was installed or repaired; widget
  goldens remained the available visual verification boundary.

## Tests run

- `dart format` on changed Dart files: clean.
- `dart analyze`: no issues in the pre-report implementation pass.
- Focused Feed, SQLite, runtime and golden tests: passed.
- Full locked Flutter suite: 175 passed.
- Full Node suite in the pre-report implementation pass: 22 passed, including
  six vNext Supabase contract tests.
- Content export: 50 quests, 5 bosses, 55 guides, 29 dialogues and 5 modifiers.
- Migration export: v5 has 17 statements and v6 has 2 statements.
- Supabase seed export: 50 quests and 5 bosses.
- Real SQLite harness: fresh v6, v4 upgrade and rollback passed.
- PostgreSQL execution and physical-device runtime are not claimed.

## Feature flags and safe defaults

`new_feed_enabled` remains false in production/release and legacy Today remains
the default. Remote content, cloud sync/auth composition, account linking,
Season, Boss, social proof, artifacts and notifications also remain disabled.
No capability revision was enabled by this slice.

## Gates

### Software gate

Closed for the complete local Feed vertical slice: session bootstrap, current
catalog activation, visibility/open/skip funnel, preparation/rehearsal, accept,
result, private reflection, reward and recovery have green repository coverage.

### Manual/device gate

Open and non-blocking. Physical iOS and Android checks are still required for
Feed frame time, memory, thermal behavior, haptics, keyboard, lifecycle,
VoiceOver/TalkBack, Dynamic Type and installed migration. Simulator/emulator or
golden output cannot close performance acceptance.

### External-service gate

Open and non-blocking. PostgreSQL has not parsed or applied the stricter RPC,
and anonymous auth, exact ACK, RLS isolation, deletion and concurrency remain
unverified against a live disposable Supabase environment.

### Asset/content gate

Open and non-blocking. Existing bundled guide/dialogue material passes
structural and safety contracts, but production editorial, localization,
artwork, sound/haptics and legal review are not claimed.

## Known limitations

- No web, simulator or physical-device screenshot was produced in this slice;
  reviewed widget goldens are the visual evidence.
- The local Feed is intentionally unreachable in release defaults.
- Static SQL contracts cannot prove PostgreSQL syntax or authorization.
- Server-issued artifact ownership is typed but not yet presented in the gated
  Season/Boss experience.
- Final visual branding and production asset review remain separate product
  work; this slice completes behavior, not a rebrand.

## Next phase readiness

The local Feed P0 software path is complete and ready for integration/device
acceptance while remaining disabled. The next unblocked repository P0 is the
gated Season/Boss/artifact presentation and its failure/expiry recovery states.
Live Supabase, secure platform storage, physical-device and asset/content gates
continue to block capability enablement and beta acceptance, not repository
development.
