> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Cross-phase P0 - complete local vNext Feed action loop. This closes the
inherited Phase 3/4 presentation gap without enabling the new Feed by default.
Branch: `codex/phase-6c-season-participation`.

## Scope actually completed

- Added a Flutter-neutral `FeedChallengeController` around the existing
  transactional `ChallengeFlowCoordinator`.
- Connected route selection and 620 ms Hold Accept to the current challenge
  assignment.
- Restored an active challenge after cold start and exposed one persistent
  result capsule across Feed pages.
- Added Attempted/Completed result entry with four felt signals.
- Added optional 1-10 before/after signals, repeat intent and a local-only
  private note up to the existing 2000-character domain limit.
- Connected the standard Reward Stage to the committed XP, primary trait and
  actual Momentum day count.
- Refreshed Journey and Rank after a successful challenge transaction.
- Made `VNextRuntime` observable so an action-triggered rank unlock reaches the
  root rank-up overlay immediately.
- Kept post-commit Journey refresh failure separate from transaction success;
  a committed reward is never reported as rolled back.
- Added an IANA timezone platform channel using Android `TimeZone` and iOS
  `TimeZone.current.identifier`; abbreviations and missing values fail closed.
- Added Russian action, reflection and reward copy without changing legacy
  Today.

## Files changed

- `mobile/lib/features/feed/application/feed_challenge_controller.dart`:
  action state, cold restoration, commit orchestration and reward presentation.
- `mobile/lib/features/feed/application/feed_view_controller.dart`: active
  challenge snapshot updates.
- `mobile/lib/features/feed/presentation/vnext_feed_screen.dart`: route, Hold,
  result, reflection, Reward and resilient Dynamic Type layouts.
- `mobile/lib/app/vnext/vnext_runtime.dart` and `vnext_app_root.dart`: challenge
  composition, Journey refresh and rank-up notifications.
- `mobile/lib/core/clock/platform_timezone_id.dart`, Android `MainActivity.kt`
  and iOS `AppDelegate.swift`: platform IANA timezone boundary.
- Hold/Reward design-system components: localized completion labels and actual
  Momentum input.
- `mobile/lib/core/localization/mayhem_strings.dart`: Russian action-loop copy.
- Runtime, widget, platform-channel and golden tests plus four reviewed Feed
  state baselines.

## Architecture decisions

The UI controller owns only transient interaction state. Acceptance, reward,
Difficulty, Momentum, Rank, private reflection persistence and canonical event
creation remain inside the existing domain coordinator and one SQLite
transaction. Widgets do not calculate XP or write repositories directly.

The action controller reports success at the transaction boundary. Journey is
refreshed afterward through a callback; a refresh failure is logged without
rewriting an already committed result as failure.

IANA timezone is obtained from native platform APIs instead of using
`DateTime.timeZoneName`, which can be an ambiguous abbreviation. The channel is
loaded only when the debug-gated vNext runtime is composed.

No Riverpod/router rewrite was introduced. Existing typed controllers,
repository ports and nested navigation remain sufficient for this scope.

## Data/migration impact

- SQLite schema remains version 6; no migration is required.
- Existing `challenge_attempts`, progress, Momentum, private reflections and
  canonical event tables are used.
- Hold Accept and result submission use the already tested atomic commits.
- Private note text remains only in `private_reflections` and is absent from
  event payloads, logs and Reward presentation.
- No cloud schema or remote migration changed in this slice.

## UI/motion result

- Challenge cards expose a stable two-route selector and Hold Accept panel.
- Active challenge capsule has a fixed 104 px responsive boundary and no longer
  expands under loose overlay constraints.
- Long challenge content scrolls internally only when Dynamic Type needs it.
- Result sheet is keyboard-aware, scrollable and uses fixed-format controls.
- Reward uses the existing reduced-motion-aware ceremony and displays committed
  XP, trait and actual Momentum instead of fixture values.
- Complete Hold -> result -> Reward passes at 390x844 and text scale 1.6.
- Reviewed goldens:
  - `phase4_feed_390x844.png`;
  - `phase6_feed_active_390x844.png`;
  - `phase6_result_sheet_390x844.png`;
  - `phase6_reward_390x844.png`.

## Dependencies and environment mutations

- `pubspec.yaml`/`pubspec.lock` changes: none.
- `flutter pub get --offline` recreated `.dart_tool` after the requested cleanup
  using the existing lockfile and local package cache.
- Network package download/update: none.
- System packages, Xcode, Android SDK, Docker, Supabase CLI and standalone
  `impellerc`: not installed or invoked.
- Native timezone source was statically tested but not platform-compiled because
  no approved iOS/Android toolchain or device is available.

## Tests run

- `dart format lib test` - clean at the action-loop pass.
- `dart analyze` - no issues.
- `flutter test --no-pub --no-test-assets -j 1` - 169 passed across the full
  unit/widget/golden suite.
- `node --test tests/*.test.mjs` - 21 passed.
- `node scripts/export_mobile_content.mjs --check` - 50 quests, 5 bosses, 55
  guides, 29 dialogs and 5 modifiers verified.
- `node scripts/export_mobile_migrations.mjs --check` - v5 17 statements and v6
  2 statements verified.
- `node scripts/export_supabase_seed.mjs --check` - 50 quests and 5 bosses.
- `python3 scripts/test_mobile_migration.py` - fresh, v4 upgrade and rollback
  verified on real SQLite.
- Golden update followed by a clean non-update comparison - passed.
- `git diff --check` - clean before checkpoint.

## Feature flags and safe defaults

`new_feed_enabled` remains false for production/release and legacy Today remains
the default. The full action loop is reachable only when the existing debug
override explicitly composes vNext. Remote content, sync, account linking,
Season, Boss, social, artifacts and notifications remain disabled.

No new capability revision or remote flag was introduced.

## Gates

### Software gate

Closed for the local Feed action-loop scope. Atomic accept/result behavior,
cold restoration, private note isolation, post-commit refresh semantics,
rank-up notification, IANA timezone validation, Dynamic Type, accessibility Hold
action and deterministic visual states have green repository coverage.

### Manual/device gate

Open and non-blocking. Required checks include native timezone execution,
physical Hold/haptics, keyboard/IME behavior, VoiceOver/TalkBack, app kill during
result entry, sustained Feed performance, memory and thermal behavior. A
simulator/emulator cannot close the physical performance gate.

### External-service gate

Open and unchanged. This slice is local-first and does not claim Supabase,
anonymous auth, secure storage or remote sync execution.

### Asset/content gate

Open and non-blocking. The four structural visual states are reviewed, but final
brand art, production content, sound/haptics and device visual sign-off are not
claimed.

## Known limitations

- Feed impression/open/typed skip domain commits exist but are not yet connected
  to visibility thresholds and presentation controls.
- Preparation guide/rehearsal content is not yet exposed from the vNext card.
- Native timezone implementations have source tests only, not platform builds.
- Reward is intentionally transient; canonical progress/history is the durable
  recovery source after process death.
- Physical-device performance acceptance remains open.

## Next phase readiness

The largest inherited product-loop gap is closed. The next unblocked P0 is the
remaining Phase 6 server-authority slice: server-issued artifact ownership and
thresholded privacy-safe Boss social aggregation. It can proceed behind disabled
capabilities while live PostgreSQL, content and physical-device gates remain
open.
