> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

## Phase completed

Phase 4 - Onboarding, Journey and You. Branch: `codex/phase-4-v1-1`.

## Scope actually completed

- Added fresh, migrated and stale-safety onboarding paths with versioned local
  calibration, safety revision acceptance and initial canonical projection.
- Added a three-tab local-first shell with independent persistent Navigator
  stacks, Feed assignment restoration and compact rank-up handling.
- Added Journey rank/Momentum top scene, trait constellation with textual
  detail, calendar, canonical history and local private-reflection retrieval.
- Added You/Profile Presence, local anonymous handle, settings, privacy,
  accessibility and diagnostics surfaces.
- Added honest local reset and a disabled Delete Everywhere action until an
  authenticated backend deletion contract exists.
- Added Russian localization resources for all new Phase 4 user-facing copy.
- Added a fail-closed runtime feature-flag resolver. The vNext root is created
  only for an explicit debug `new_feed_enabled` override.
- Added direct acceptance coverage from fresh local identity through onboarding
  to the first locally generated bundled challenge without a network session.

## Files changed

- `mobile/lib/app/vnext/`: Phase 4 composition root, launch flow and tab shell.
- `mobile/lib/features/onboarding/`: versioned calibration and onboarding UI.
- `mobile/lib/features/feed/`: Feed view state, restoration and mobile scene.
- `mobile/lib/features/progress/`: canonical Journey projection and detail UI.
- `mobile/lib/features/profile/` and `features/settings/`: You and settings.
- `mobile/lib/core/localization/`: Russian Phase 4 string contract.
- `mobile/lib/core/feature_flags/feature_flag_runtime.dart`: safe runtime flags.
- `mobile/lib/core/metadata/` and
  `infrastructure/sqlite/sqlite_local_metadata_repository.dart`: typed local
  metadata boundary.
- `mobile/lib/core/design_system/components/`: constellation, compact rank-up,
  adaptive navigation and theme-aware text family handling.
- `mobile/test/app/`, `mobile/test/features/onboarding/` and test support:
  gate-level widget, accessibility and deterministic golden coverage.

## Architecture decisions

The accepted typed controllers/repositories and `ChangeNotifier` composition
were retained; no Riverpod/router rewrite was justified by a v1.1
incompatibility. Three nested Navigators in an `IndexedStack` preserve each tab
stack and scroll state. Onboarding/settings/feed-view state use the existing
SQLite `app_metadata` table through a narrow repository rather than a new
schema. Local identity remains distinct from Supabase anonymous auth.

No new ADR was required for Phase 4. ADR 0002 was amended only to record the two
additional delta corrections found during implementation: neutral legacy
difficulty fallback and balanced next-rank progress.

## Data/migration impact

- SQLite schema remains version `6`; no migration or data-clearing upgrade.
- New onboarding, preferences, current Feed assignment and last-seen rank state
  are versioned values in `app_metadata`.
- Attempt result JSON now stores earned XP and effective local date additively;
  older rows restore with null values.
- Existing migrated progress is preserved and bypasses onboarding when the
  current safety revision was already accepted.
- Explicit local reset deletes local data atomically, rotates both local IDs,
  resets client sequence and writes every cached feature flag as false.
- Fresh, v4 upgrade and rollback paths remain green on real SQLite.

## UI/motion result

- Implemented opening, four-step calibration, boundaries and profile reveal.
- Implemented mobile Feed, Journey and You at 390x844 with reviewed goldens:
  `phase4_feed_390x844.png`, `phase4_journey_390x844.png` and
  `phase4_you_390x844.png`.
- Implemented deterministic Reduce Motion transitions and persisted Reduce
  Motion/Transparency preferences; advanced motion remains off by default.
- Phase 4 primary surfaces and full onboarding pass at 1.6x text scale without
  RenderFlex overflow.

## Dependencies and environment mutations

- `pubspec.yaml`/lockfile changes: none.
- `pub get` executed: no.
- System tools installed: none.
- Xcode, Android SDK, Docker, Supabase CLI and standalone `impellerc`: not
  installed or invoked.
- External credentials/services used: none.

## Tests run

- `dart format lib test` - 178 files, no changes required.
- `dart analyze` - no issues.
- `flutter test --no-pub --no-test-assets -j 1` - 105 passed, including unit,
  widget, accessibility and golden tests.
- `node --test tests/*.test.mjs` - 16 passed.
- `node scripts/export_mobile_content.mjs --check` - 50 quests, 5 bosses, 55
  guides, 29 dialogs and 5 modifiers verified.
- `node scripts/export_mobile_migrations.mjs --check` - v5 17 statements and v6
  2 statements verified.
- `python3 scripts/test_mobile_migration.py` - fresh, v4 upgrade and rollback
  verified on real SQLite.
- Phase 4 localization scan outside the localization resource - no Cyrillic
  user-facing literals found.
- `git diff --check` - clean.

## Feature flags and safe defaults

All production/release defaults remain false. Release builds ignore requested
debug overrides. Debug builds may explicitly enable `new_feed_enabled` or
`advanced_motion_enabled`; neither is enabled by default. Remote content,
account linking, notifications, social and every other production capability
remain disabled. Diagnostics reports flag source, local-only identity,
capability revisions and the open physical-device gate.

Active revisions are `reward_policy_dev_v1`, `difficulty_model_dev_v1`,
`rank_config_dev_v1`, `momentum_policy_dev_v1` and
`calibration_config_dev_v1`.

## Gates

### Software gate

Closed for Phase 4 scope. Fresh/migrated/stale-safety paths, offline first
challenge, canonical Journey state, local reset, localization, tab persistence,
cold Feed restoration, accessibility and goldens have direct green coverage.

### Manual/device gate

Open and non-blocking for Phase 5: onboarding/Journey/You visual sign-off,
VoiceOver/TalkBack smoke, haptics and representative physical iOS/Android
motion, frame-time and memory acceptance. Simulator/emulator results will not
close physical performance acceptance.

### External-service gate

Open and non-blocking. No Supabase credentials, disposable project or
authenticated anonymous session were used. Cloud-wide deletion, server
Momentum authority and remote content remain unavailable.

### Asset/content gate

Open and non-blocking. Final Sigil/Core/artifact artwork, sound/haptics tuning,
legal copy and production content approval are not claimed. Related production
flags remain disabled.

## Known limitations

- The new Feed is a browsing/restoration surface in this phase and does not add
  Accept/Attempt/Reward controls. Phase 3 domain coordinators remain tested, but
  wiring that action loop into the vNext Feed presentation was not redone.
- Delete Everywhere is deliberately disabled until Phase 5 can confirm remote
  deletion before removing auth/session state.
- Private note bodies remain local-only; OS backup exclusion and platform
  verification are still required before production launch.
- Golden/widget checks do not replace screen-reader or physical-device review.

## Next phase readiness

Phase 5 repository-only work may proceed under section 1.2.2. Remote content,
account linking, cloud deletion UI, notifications and advanced motion must stay
disabled until their external/manual gates close. `new_feed_enabled` remains a
debug-only explicit override until at least one physical iOS smoke/performance
sign-off is recorded.
