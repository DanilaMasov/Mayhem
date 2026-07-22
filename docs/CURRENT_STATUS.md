# Mayhem Current Status

**Status date:** 2026-07-22
**Authoritative specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`
**Production target:** Flutter application under `mobile/`
**Status handoff branch:** `main`
**Current implementation checkpoint:** `e33bda0` (merged by PR #31 as
`d813e31`)
**Clean-tree import commit:** `3c338d4 chore: import clean Mayhem baseline`
**Imported source checkpoint:** `9a61caa feat(season): present server-owned artifacts`

## Completed capabilities

- Local-first Flutter startup and SQLite v4-to-v6 migration path.
- Onboarding, Feed, guide, rehearsal, challenge result, reflection, reward,
  Journey, You, Momentum, ranks, history, and local reset.
- Idempotent local events and deterministic bundled-content fallback.
- Source-level Supabase auth, exact-ACK sync, feature-flag, remote-content,
  Season, Boss, artifact, reconciliation, and privacy-threshold contracts.
- Server-owned artifact persistence and gated active-Season presentation.
- Clean Git baseline imported without old Kira or `.hatch-pets/` history.
- Mutable effective feature-flag runtime with strict TTL expiry, capability
  validation through remote bootstrap, and live legacy/vNext UI switching.
- App-level composition owner for local runtimes, feature flags, lifecycle,
  cancellable remote orchestration, bounded diagnostics, and store shutdown.
- Environment-namespaced Keychain/Android Keystore session storage with a
  single atomic payload, strict decoding, and corrupted-entry recovery.
- Production Supabase composition for anonymous auth, installation bootstrap,
  exact-ACK sync, cached/server flags, remote content, remote Feed, Season
  activation, reconciliation, manual retry, and confirmed global deletion.
- Production/staging application identities, supported OS floors, unsigned
  release-smoke CI, distinct launcher assets, and honest release Settings.
- Release-staging-only Sentry crash client with a fail-closed DSN boundary and
  privacy scrubber; production telemetry remains disabled.
- Manual main-only Sentry ingestion/privacy acceptance harness with bounded,
  secret-free evidence; no live run has been claimed.
- Owner-configurable support contact parsing and platform handoff shared by
  legacy and vNext Settings; no public destination has been approved.
- Manual Android staging preview workflow with debug-only local Feed override,
  signature verification, bounded artifact retention, and no protected inputs.
- Device-feedback blocker hardening for the challenge-result sheet: keyboard
  safe scrolling, debug-paint reset in preview builds, retry-safe terminal
  result acknowledgement, stale local event-sequence recovery, and honest
  retry copy.

## Active work item

Baseline pull request #1 and R1 pull requests
[#2](https://github.com/DanilaMasov/Mayhem/pull/2),
[#3](https://github.com/DanilaMasov/Mayhem/pull/3), and
[#4](https://github.com/DanilaMasov/Mayhem/pull/4) are merged into `main`.
PR #4 landed as merge commit `96e1f7d`; R1 software implementation is merged.
The bounded post-R1 correction pass in pull request
[#5](https://github.com/DanilaMasov/Mayhem/pull/5) is merged into `main` as
`73b61c3`. The guarded R2 acceptance preparation in pull request
[#6](https://github.com/DanilaMasov/Mayhem/pull/6) is merged into `main` as
`b50f36f`. Phase R2 live acceptance in pull request
[#7](https://github.com/DanilaMasov/Mayhem/pull/7) is merged into `main` as
`ccdd12d`. The original disposable Supabase run applied nine migrations from zero
and passed all nine backend probes plus eight production Flutter client checks.
Its secret-free report is
`docs/R2_LIVE_SUPABASE_ACCEPTANCE_REPORT_2026-07-17.json`. R3 state foundation
in pull request [#8](https://github.com/DanilaMasov/Mayhem/pull/8) is merged as
`8f271d4`. Server-authoritative Join in pull request
[#9](https://github.com/DanilaMasov/Mayhem/pull/9) is merged into `main` as
`8761978`. Server-authoritative Day completion and Boss participation in pull
request [#10](https://github.com/DanilaMasov/Mayhem/pull/10) are merged into
`main` as `4453a17`. Pull request
[#11](https://github.com/DanilaMasov/Mayhem/pull/11) adds authenticated
participation to the active-Season snapshot and reconciles it with unresolved
same-revision local actions; it is merged into `main` as `3b564c2`. Commit
`423d2b9` on `codex/r3-state-matrix-audit` closes the remaining production
state-path and retry gaps found by the final R3 software audit. Remote
operations still activate only with a valid environment-specific Supabase
configuration. The final R3 software correction in pull request
[#12](https://github.com/DanilaMasov/Mayhem/pull/12) is merged into `main` as
`9958be3`; R3 software implementation is closed. Pull request
[#13](https://github.com/DanilaMasov/Mayhem/pull/13) removes Android debug
release signing, aligns portrait declarations, validates runtime environments,
and adds the missing social-aggregate privacy disclosure. It is merged into
`main` as `26d82e1`; its final push and pull-request CI are green. The current
R5 slice applies the owner-approved production/staging identities and minimum
OS policy without changing signing material, assets, telemetry, backend
configuration, dependencies, or release flags. Pull request
[#14](https://github.com/DanilaMasov/Mayhem/pull/14) is merged into `main` as
`814be9b`. Pull request
[#15](https://github.com/DanilaMasov/Mayhem/pull/15) adds unsigned Android and
iOS staging release compilation in CI without backend or signing secrets; it
is merged into `main` as `1bc90cb`. Pull requests
[#16](https://github.com/DanilaMasov/Mayhem/pull/16),
[#17](https://github.com/DanilaMasov/Mayhem/pull/17), and
[#18](https://github.com/DanilaMasov/Mayhem/pull/18) add the protected
migration-`010` staging acceptance workflow, accepted secret aliases, and
redacted failure diagnostics. Live run
[29770143398](https://github.com/DanilaMasov/Mayhem/actions/runs/29770143398)
then exposed implicit `anon` execute grants on ten `SECURITY DEFINER`
functions. Pull request
[#19](https://github.com/DanilaMasov/Mayhem/pull/19) closes that deployment
portability defect with forward migration `011` and is merged as `685934c`.
The final protected run
[29771165967](https://github.com/DanilaMasov/Mayhem/actions/runs/29771165967)
applied all eleven migrations from zero and passed all nine live probes plus
eight production Flutter client checks. The R5 launcher slice replaces
the remaining default Flutter artwork with separate production and visibly
marked staging icon sets for Android and iOS; it does not alter dependencies,
signing, backend configuration, telemetry, or release flags. Pull request
[#21](https://github.com/DanilaMasov/Mayhem/pull/21) is merged into `main` as
`0f1281e`. Pull request
[#22](https://github.com/DanilaMasov/Mayhem/pull/22) removes controls and status
copy for capabilities that have no production implementation while preserving
the persisted preference schema for backward-compatible reads; it is merged
into `main` as `7aee0da`. Pull request
[#23](https://github.com/DanilaMasov/Mayhem/pull/23) adds crash-only staging
Sentry reporting and is merged as `d526219`. Pull request
[#25](https://github.com/DanilaMasov/Mayhem/pull/25) adds its protected live
ingestion/privacy harness directly to `main` and is merged as `d1327f5`; it
corrects pull request #24 having targeted the already-merged crash-client
branch. No staging project, DSN, API token, or successful live run is claimed.
Pull request [#26](https://github.com/DanilaMasov/Mayhem/pull/26) adds a strict
compile-time email/HTTPS support configuration boundary, one shared external
action in both Settings implementations, recoverable launch failure, semantic
widget coverage, and a repository release contract. It is merged into `main`
as `1849525`. No public support destination is invented or approved by this
slice.

Pull request [#31](https://github.com/DanilaMasov/Mayhem/pull/31) merges the
user-directed device-feedback blocker slice as `d813e31`. It addresses the two
supplied Android captures by removing leaked Flutter paint diagnostics from
distributed debug previews, keeping the result form scrollable above the
keyboard at enlarged text, replacing the reflection tile that triggered a
transparent-material assertion, and recovering both a lost UI acknowledgement
and a stale local event counter without double-paying rewards. The change does
not claim physical-device acceptance; preview 3 still requires installation and
reproduction on the reporting device.

## Open software gates

- R5 store registration, signing, store artwork, owner approval/injection and
  signed-device verification of the support destination, live staging Sentry
  provisioning/ingestion inspection, signed install/launch,
  launcher-appearance acceptance, and release records.
- R6 visual refinement, gated behind a signed staging candidate and a
  preliminary two-device R4 defect-finding pass.
- The Android preview APK is an installable demonstration only; it does not
  replace a signed release candidate or any physical-device acceptance report.

## Live-backend gates

- R2 disposable Supabase/PostgreSQL migration, RLS, explicit function grants,
  RPC, concurrency, deletion, auth, sync, Season/Boss, artifact, social-proof,
  and production Flutter client acceptance is closed through migrations
  `001-011` by the 2026-07-20 protected live run.
- Migration `202607180010_season_participation_snapshot.sql` and forward
  grant-hardening migration
  `202607200011_explicit_function_execute_grants.sql` both passed from-zero
  live acceptance against the authorized staging project.
- No production Supabase environment has been configured or authorized.

## Open device gates

- R4 physical iOS and Android performance, lifecycle, accessibility, haptics,
  thermal, migration, secure-session, and interrupted-deletion acceptance.
- Simulator/emulator evidence cannot close physical-device acceptance.
- Any R6 visual or interaction change invalidates earlier UI/device evidence;
  the final candidate requires a fresh full four-device R4 regression.

## Known release blockers

- Production remote auth/sync remains unavailable in builds without
  `SUPABASE_URL` and `SUPABASE_ANON_KEY`; no production target is configured.
- `new_feed_enabled` and all dependent release capabilities remain false.
- Physical-device acceptance, store registration of the approved application
  IDs, release signing, store artwork, signed launcher appearance, approval and
  device verification of the support destination, live staging crash-reporting
  acceptance, and store configuration remain incomplete.

## Verification

The broad clean-clone verification was completed on 2026-07-18. Repository
contracts, Flutter static/runtime checks, and generated-data checks were
repeated on 2026-07-21; the latest live-backend evidence remains dated
2026-07-20. Commands and latest applicable results:

The 2026-07-22 device-feedback blocker slice passed its complete local software
gate:

```sh
node --test tests/*.test.mjs
# 66 passed

cd mobile
dart format --output=none --set-exit-if-changed lib test tool
# 264 files, 0 changed

flutter analyze --no-pub
# no issues

flutter test --no-pub --no-test-assets -j 1
# 268 passed; 2 protected live-only tests skipped
```

The suite includes a 390x844 result-sheet regression with a 330-pixel keyboard
inset and 1.6x text, stale local sequence recovery, lost result-acknowledgement
recovery, and debug-overlay reset. These tests do not substitute for a rerun on
the physical Android device that produced the captures.

- [push CI run 29932406124](https://github.com/DanilaMasov/Mayhem/actions/runs/29932406124):
  repository contracts and Flutter passed;
- [pull-request CI run 29932468034](https://github.com/DanilaMasov/Mayhem/actions/runs/29932468034):
  repository contracts and Flutter passed;
- [pull-request release-smoke run 29932468063](https://github.com/DanilaMasov/Mayhem/actions/runs/29932468063):
  unsigned Android and iOS staging compilation passed.

```sh
node --test tests/*.test.mjs
# 66 passed

node scripts/export_mobile_content.mjs --check
# 50 quests, 5 bosses, 55 guides, 29 dialogs, 5 modifiers

node scripts/export_mobile_migrations.mjs --check
# v5: 17 statements; v6: 2 statements

python3 scripts/test_mobile_migration.py
# fresh v6, v4-to-v6 upgrade, and rollback passed on real SQLite

node scripts/export_supabase_seed.mjs --check
# 50 quests and 5 bosses verified

cd mobile
dart format --output=none --set-exit-if-changed lib test tool
# 262 files, 0 changed

flutter analyze --no-pub
# no issues

flutter test --no-pub --no-test-assets tool/generate_launcher_icons_test.dart
# 1 generator test passed; RGB platform assets reproduced

flutter test --no-pub --no-test-assets -j 1
# 264 passed; 2 live-only tests skipped without protected targets
```

R3 state-foundation local evidence:

- the UI model distinguishes disabled, cached loading, remote loading,
  unavailable, offline cached, server confirmed, conflict, incompatible
  package, and recoverable-error availability;
- membership, day, and Boss substates are explicit, including joining,
  retryable join failure, in-progress day, Boss submission, already
  participated, expired, and completed outcomes;
- expired packages remain readable from the validated local cache instead of
  disappearing when the active time window closes;
- Journey exposes a gated Season entry and detail screen that labels cached
  data separately from server-confirmed data and remains valid at 1.6x text;
- social proof is rendered only when the validated package exposes a value at
  or above its privacy threshold;
- the state-foundation commit exposed no mutation from the local coordinator
  alone; the subsequent Join slice adds the required exact-ACK boundary.
- [push CI run 29606646694](https://github.com/DanilaMasov/Mayhem/actions/runs/29606646694):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29606663881](https://github.com/DanilaMasov/Mayhem/actions/runs/29606663881):
  repository contracts and Flutter format/analyze/test passed.

R3 server-authoritative Join local evidence:

- Join is staged atomically with its canonical event and becomes active only
  after the exact event receives a server-accepted ACK;
- the durable action journal distinguishes pending, synced, and rejected
  delivery without storing secrets or creating a second mutation channel;
- a staged Join survives runtime disposal and a new app composition restores
  retryable state from SQLite;
- retry clears only the event backoff and resubmits the same event ID, allowing
  the server's duplicate-event handling to recover from a lost ACK;
- network failure leaves one retryable pending action; server rejection clears
  optimistic local participation before a new attempt is allowed;
- Join UI is disabled without a configured remote runtime, explains the
  server-confirmation boundary, and remains valid at 1.6x text;
- no dependency, lockfile, migration, production flag, or SDK changed.
- [push CI run 29609782160](https://github.com/DanilaMasov/Mayhem/actions/runs/29609782160):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29609798994](https://github.com/DanilaMasov/Mayhem/actions/runs/29609798994):
  repository contracts and Flutter format/analyze/test passed.

R3 server-authoritative Day/Boss local evidence:

- Day completion and Boss participation are staged atomically with canonical
  events and become terminal only after the exact event receives an accepted
  server ACK;
- pending delivery survives runtime disposal, and retry resubmits the same
  event ID instead of duplicating participation or changing the Boss route;
- network failure and missing ACK remain explicitly retryable, while permanent
  rejection rolls back only the affected optimistic day or Boss state;
- an unconfirmed Join cannot expose Day/Boss actions, and one operation lock
  prevents parallel Season mutations;
- Journey exposes Day submission and package-approved Boss route selection;
  the 1.6x text widget flow covers Join, Day, and Boss end to end;
- Season scrolling reserves the navigation inset so terminal controls remain
  hit-testable at large text sizes;
- no dependency, lockfile, migration, production flag, or SDK changed.
- [push CI run 29615519565](https://github.com/DanilaMasov/Mayhem/actions/runs/29615519565):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29615538337](https://github.com/DanilaMasov/Mayhem/actions/runs/29615538337):
  repository contracts and Flutter format/analyze/test passed.

R3 cross-device participation local evidence:

- the authenticated active-Season RPC returns only the current account's
  joined timestamp, completed days, and Boss participation timestamp;
- the client validates participation identity, revision, day range,
  uniqueness, and timestamps before replacing the authoritative local base;
- unresolved Join, Day, and Boss actions are preserved only when they belong
  to the same Season revision, so bootstrap cannot erase retryable writes or
  carry them into a changed package;
- a second device can render server-confirmed membership without synthesizing
  a local Join event, while server absence clears stale confirmed state;
- manual and foreground Season activation refresh the Season runtime even
  when the progress projection revision did not change;
- package and participation persistence remain backward-compatible with
  snapshots written before the participation field existed;
- no dependency, lockfile, production flag, or SDK changed;
- at this historical R3 checkpoint migration `010` was still unapplied; it
  later passed the protected 2026-07-20 live gate, while all associated
  production flags remain false.
- [push CI run 29643920613](https://github.com/DanilaMasov/Mayhem/actions/runs/29643920613):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29643930964](https://github.com/DanilaMasov/Mayhem/actions/runs/29643930964):
  repository contracts and Flutter format/analyze/test passed.

R3 final state-matrix local evidence:

- every required availability, membership, Day, and Boss enum state is
  exercised by one exhaustive deterministic domain contract;
- malformed optional Season activation remains isolated from core sync but is
  propagated to the production runtime as `incompatiblePackage`; non-format
  activation failures are propagated separately as recoverable;
- incompatible, recoverable, conflict, and unavailable empty states no longer
  collapse into one generic screen;
- the Season Retry command uses the existing coalesced remote synchronizer,
  suppresses parallel attempts, and always exits loading through `finally`;
- a stale cached package remains readable after activation failure, while
  Join, Day, and Boss mutations are blocked until compatible state returns;
- a successful retry clears stale failure state and renders the newly
  validated server-confirmed package;
- the new cached-package failure path remains valid at 1.6x text;
- no dependency, lockfile, migration, production flag, or SDK changed.
- [push CI run 29646030801](https://github.com/DanilaMasov/Mayhem/actions/runs/29646030801):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29646043550](https://github.com/DanilaMasov/Mayhem/actions/runs/29646043550):
  repository contracts and Flutter format/analyze/test passed.

R5 release-safety local evidence:

- Android release no longer falls back to the debug signing configuration;
- Android release signing is composed only from a complete four-variable
  external environment contract, and a partial secret set fails closed;
- Android manifest, iPhone/iPad plist declarations, and Flutter runtime now
  agree on portrait-only orientation;
- application runtime accepts only `development`, `staging`, or `production`,
  defaults release to production, and rejects development release targets;
- repository contracts protect signing, orientation, non-placeholder IDs,
  semantic version shape, positive build number, and signing-file exclusions;
- Settings explains that participant counts are aggregate-only and hidden
  below the privacy threshold;
- `docs/RELEASE_CONFIGURATION.md` records environment, signing, versioning,
  secret-handling, and still-open external approvals;
- no package, lockfile, SDK, signing material, analytics, crash-reporting, or
  production flag changed;
- Android/iOS release compilation, signing, install, and launch remain untested
  until an approved SDK/signing environment is provided.
- [final push CI run 29646666244](https://github.com/DanilaMasov/Mayhem/actions/runs/29646666244):
  repository contracts and Flutter format/analyze/test passed;
- [final pull-request CI run 29646667487](https://github.com/DanilaMasov/Mayhem/actions/runs/29646667487):
  repository contracts and Flutter format/analyze/test passed.

R5 release-identity local evidence:

- Android and iOS production identity is exactly `com.danilamasov.mayhem`;
  staging is isolated as `com.danilamasov.mayhem.staging`;
- Android exposes `production` and `staging` product flavors, while iOS exposes
  matching shared schemes and build configurations;
- Flutter derives runtime environment from the native flavor and rejects an
  explicit `MAYHEM_ENVIRONMENT` that disagrees with it;
- Android 10 / API 29 and iOS 16 are enforced as the supported OS floors;
- staging installs are visibly labelled `MAYHEM STAGING`; at this historical
  checkpoint a separately marked staging icon remained open and is now supplied
  by the R5 launcher-asset slice;
- the Android namespace and `MainActivity` package moved with the application
  ID while preserving the native IANA timezone method channel;
- Xcode project/plist and both schemes pass `plutil`/`xmllint`; repository
  contracts, content/migration/SQLite/seed checks, Dart format, Flutter analyze,
  and all 254 non-live Flutter tests pass locally;
- no dependency, lockfile, SDK, signing material, telemetry, backend secret,
  production flag, or launcher asset changed;
- unsigned Android/iOS staging release compilation passes in hosted CI;
  signing, install, launch, and store registration remain external gates;
- [initial push CI run 29656281403](https://github.com/DanilaMasov/Mayhem/actions/runs/29656281403):
  repository contracts and Flutter format/analyze/test passed;
- [initial pull-request CI run 29656293884](https://github.com/DanilaMasov/Mayhem/actions/runs/29656293884):
  repository contracts and Flutter format/analyze/test passed.

R5 staging release-smoke evidence:

- the workflow runs only for matching pull requests or explicit manual
  dispatch, so expensive macOS builds are not duplicated on every branch push;
- Android compiles an unsigned staging release AAB with API 29 floor and no
  keystore variables;
- iOS compiles a staging release application with iOS 16 floor and
  `--no-codesign`;
- both builds use `--flavor staging`, assert `MAYHEM_ENVIRONMENT=staging`, and
  resolve dependencies with the committed lockfile enforced;
- no Supabase value, production flavor, signing secret, SDK change, uploaded
  artifact, dependency, lockfile, or production flag is introduced;
- [staging release-smoke CI run 29657632595](https://github.com/DanilaMasov/Mayhem/actions/runs/29657632595):
  Android release compilation passed in 4m46s and iOS in 4m34s;
- [ordinary pull-request CI run 29657632614](https://github.com/DanilaMasov/Mayhem/actions/runs/29657632614):
  repository contracts and Flutter format/analyze/test passed.

R5 launcher-asset local evidence:

- production uses an opaque RGB Mayhem monogram master instead of Flutter
  template artwork; staging adds a persistent amber warning marker;
- Android provides distinct production/staging PNGs at all five launcher
  densities plus adaptive foreground/background and monochrome resources;
- iOS provides complete production `AppIcon` and staging `AppIconStaging`
  catalogs, and every staging build configuration selects the staging set;
- repository contracts parse PNG headers, verify every declared native size,
  reject alpha in iOS artwork, require adaptive resources, and prove production
  and staging masters differ;
- all 54 repository contracts and 254 non-live Flutter tests pass locally;
  the explicit disposable live test remains skipped in the ordinary suite;
- no dependency, lockfile, SDK, signing material, backend value, telemetry, or
  production flag changed;
- signed installation and real launcher-mask appearance remain physical-device
  gates; store marketing artwork remains a separate owner deliverable.

R5 settings-honesty local evidence:

- release Settings exposes only the two accessibility switches whose values are
  consumed by the live application: reduced motion and reduced transparency;
- haptics, sound, and reward-ceremony switches are hidden because their stored
  values were not connected to those capabilities; push notification status is
  hidden because notifications are an explicit current-cycle non-goal;
- pre-R5 `user_preferences_v1` snapshots retain their legacy fields and still
  deserialize without migration or data loss;
- widget coverage proves legacy snapshots remain readable, placeholder controls
  remain absent, and an effective accessibility change is persisted;
- the shell integration test locates Reset, Delete Everywhere, and Diagnostics
  semantically instead of relying on a fixed scroll distance;
- all 54 repository contracts and 255 non-live Flutter tests passed for that
  slice; the explicit disposable live test remained skipped in the ordinary
  suite;
- content, migration, SQLite, and seed checks, Dart format, and Flutter analyze
  pass without dependency, lockfile, SDK, backend, telemetry, or flag changes.

R5 staging crash-reporting local evidence:

- `sentry_flutter 9.24.0` is the only new direct dependency and is used solely
  for crash capture; product analytics remain absent;
- initialization requires release mode, the staging runtime/flavor, and a
  valid public HTTPS `MAYHEM_SENTRY_DSN`; development, production, missing,
  insecure, malformed, and secret-bearing configurations all fail closed;
- default PII, breadcrumbs, HTTP capture, logs, metrics, tracing, profiling,
  replay, screenshots, view hierarchy, user interactions, package inventory,
  ANR/app-hang reporting, and automatic session tracking are disabled;
- the final `beforeSend` scrubber removes users, requests, attachments,
  arbitrary contexts, exception text, response/mechanism data, source context,
  frame variables/registers, and local absolute paths;
- Sentry initialization failure cannot block the local-first launch path, and
  bootstrap diagnostics report only a bounded runtime type;
- focused Flutter behavior tests and repository release contracts cover the
  activation boundary, option policy, payload scrubbing, and absence of a
  committed DSN;
- all 55 repository contracts and 259 non-live Flutter tests pass locally; the
  explicit disposable live test remains skipped in the ordinary suite;
- an Android staging AAB attempt stopped before compilation because this host's
  Android SDK directory contains no platforms or build tools; `flutter doctor`
  also confirms that Xcode is incomplete and CocoaPods is absent, so native
  Android/iOS compilation must be repeated in the hosted release-smoke gate;
- no Sentry project/DSN, signing material, backend value, production telemetry,
  product analytics, or release feature flag is added. Live ingestion,
  symbolication, native crash capture, and privacy inspection remain open.

R5 Sentry live-acceptance scaffold local evidence:

- `.github/workflows/staging-sentry-acceptance.yml` is manual, main-only,
  approval-environment protected, read-only at the GitHub permission layer, and
  requires an explicit synthetic-event confirmation;
- the staging DSN and least-privileged Sentry API token enter only through
  protected environment secrets and are never passed in command arguments;
- the Flutter-test probe explicitly activates the separately tested
  release-staging configuration, sends one synthetic event through the exact
  checked-in scrubber, then writes only a runner-local event descriptor; it is
  skipped without the protected confirmation;
- the Node runner polls the exact event ID, retrieves the attachment list, and
  proves nine bounded conditions covering ingestion, environment/release/policy
  identity, marker removal, user/request/breadcrumb removal, exception
  redaction, and attachment absence;
- the uploaded seven-day report excludes the synthetic marker, DSN, API token,
  organization/project slugs, and raw Sentry response; verifier and runner tests
  reject protected-value leakage and unsafe production/insecure configuration;
- all checks in this paragraph are local/static only. No Sentry project or
  protected credentials are configured, and native crash capture,
  symbolication, offline delivery, Sentry-UI review, signed builds, and devices
  remain open live gates.

Post-R1 correction local evidence:

- Delete Everywhere models server deletion, cloud confirmation, secure-session
  clear, local-data clear, and completion as distinct stages;
- an environment-scoped secure recovery marker survives session and SQLite
  clearing, resumes before cold-start sync, and prevents repeated cloud delete;
- server failure and receipt mismatch preserve session/local state, while
  secure-session, local-clear, and marker-cleanup failures remain explicitly
  recoverable;
- successful device-only reset deterministically leaves its loading state;
- Diagnostics renders live configured/disabled, runtime, account, session, and
  bounded error-code state without secrets;
- successful foreground refresh restores `ready` and clears stale errors;
- authenticated RPC performs at most one forced refresh and one retry after
  `401`; refresh failure and a second `401` are explicit bounded auth errors;
- HTTPS is mandatory outside development localhost/loopback configurations.

R2 harness evidence:

- requires an explicit non-production identifier and destructive-test
  confirmation before reading the database target;
- keeps DB URL, anon key, access tokens, refresh tokens, and server bodies out
  of argv, logs, diagnostics, and reports;
- refuses a target containing existing Mayhem tables unless a separately
  confirmed reset is requested, binds API and DB URLs to the same project ref,
  and applies eleven migrations from zero in deterministic order through
  `psql`;
- prepares two-user auth/refresh, ownership/RLS, grants, direct-write denial,
  exact/duplicate/partial ACK, private-note rejection, and auth recovery;
- covers Season join/day/closed-window rules, concurrent Boss submission,
  duplicate participation, advisory-lock effects, server-owned artifacts,
  thresholded social proof, identity/privacy isolation, and deletion cleanup;
- invokes production Flutter auth/backend/content/Feed/Season/reconciliation
  and Delete Everywhere adapters in a headless opt-in live test;
- adds migration `007` to close legacy security-definer search paths and
  decrement social proof during deletion, migration `008` to advance the
  projection revision only for newly issued artifacts, migration `009` to
  repair recursive private-note validation, migration `010` for
  account-scoped Season participation, and migration `011` to revoke implicit
  Data API function grants before restoring the authenticated RPC allowlist;
- decomposes PostgreSQL credentials into libpq environment fields and sends
  parameterized verification SQL through stdin instead of argv;
- the latest protected staging run passed all nine probes and eight Flutter
  client checks in 62,726 ms with no failed, blocked, or not-run checks;
- the original 2026-07-17 disposable project and local acceptance tooling were
  removed after evidence; the current protected staging project remains
  configured and contains only deterministic acceptance fixtures;
- `docs/R2_LIVE_SUPABASE_ACCEPTANCE.md` records the reproducible command,
  attempt history, cleanup contract, and final secret-free evidence.

R1 final composition local evidence:

- valid cached flags are restored and capability-checked before `runApp`;
- anonymous auth, secure-session restore/refresh, installation registration,
  bootstrap, exact-ACK event sync, reconciliation, remote content, Season
  activation, and remote Feed are composed without global singletons;
- bootstrap uses three bounded attempts, foreground uses two, event retries are
  durable with exponential backoff and jitter, and HTTP stages have timeouts
  plus a 1 MiB response limit;
- remote Feed preserves server order, excludes accepted/completed/skipped
  assignments, persists stable identities, and cannot replace local fallback
  when invalid, expired, unavailable, or disabled;
- Feed results and Season/Boss terminal commits trigger sync only after local
  writes, while foreground and explicit retry use coalesced orchestration;
- Delete Everywhere is enabled only for a usable secure session, attempts sync,
  requires destructive confirmation, and clears session/local state only after
  a matching server receipt;
- account linking and notifications remain unavailable because no tested
  provider or notification implementation is configured;
- access/refresh tokens remain confined to secure storage and authenticated
  request headers; error diagnostics redact token echoes and remain bounded.

R1 secure-session slice local evidence:

- `flutter_secure_storage 10.3.1` is the only new direct dependency and exists
  solely to back sessions with iOS Keychain and Android encrypted storage;
- session access, refresh tokens, and identity metadata are written as one
  namespaced JSON payload and never enter SQLite or logs;
- invalid JSON, schema, field types, UTC expiry, and oversized payloads are
  treated as corruption and remove only the affected environment entry;
- real platform read/write/delete failures remain observable and are not
  misreported as sign-out;
- Android API 23, backup exclusion, and iOS Keychain entitlements are declared;
- adapter and platform configuration contracts pass without requiring an SDK,
  simulator, emulator, or physical device.

R1 mutable-flag slice local evidence:

- release defaults remain false and debug overrides remain debug-only;
- cached/server snapshots require a valid lifetime and expire automatically;
- server records pass capability-revision validation before publication;
- remote bootstrap updates the effective runtime and gates remote content;
- widget coverage proves legacy Today to vNext and automatic TTL fallback
  without restarting the app;
- no package, lockfile, SDK, secret, or release-default change was introduced.

R1 composition-owner slice local evidence:

- local Today renders while remote bootstrap is still pending;
- remote bootstrap failure degrades only remote state and cannot replace the
  local UI;
- app foreground calls orchestration only on lifecycle resume;
- shutdown cooperatively cancels pending bootstrap and closes local storage;
- disabled production remote bootstrap is explicit and idempotent;
- telemetry and logs expose bounded error type codes, not exception messages or
  tokens;
- vNext is prepared independently of the release flag when a valid platform
  timezone exists, and fails closed to legacy Today otherwise.

The first complete green GitHub baseline was commit `d7b33ce`:

- [push CI run 29409000516](https://github.com/DanilaMasov/Mayhem/actions/runs/29409000516):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29409002878](https://github.com/DanilaMasov/Mayhem/actions/runs/29409002878):
  repository contracts and Flutter format/analyze/test passed;
- Linux and macOS visual tests use strict platform-specific PNG baselines;
  no tolerance or automatic golden update is enabled in ordinary CI.

Baseline PR #1 is merged. The first R1 slice is commit `85a91e4` in pull request
[#2](https://github.com/DanilaMasov/Mayhem/pull/2):

- [push CI run 29410905633](https://github.com/DanilaMasov/Mayhem/actions/runs/29410905633):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29410929122](https://github.com/DanilaMasov/Mayhem/actions/runs/29410929122):
  repository contracts and Flutter format/analyze/test passed.

The R1 composition-owner slice is commit `6708701` in pull request
[#3](https://github.com/DanilaMasov/Mayhem/pull/3):

- [push CI run 29413237254](https://github.com/DanilaMasov/Mayhem/actions/runs/29413237254):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29413260609](https://github.com/DanilaMasov/Mayhem/actions/runs/29413260609):
  repository contracts and Flutter format/analyze/test passed.

The final R1 software slice is commit `8da8174` in merged pull request
[#4](https://github.com/DanilaMasov/Mayhem/pull/4), checkpoint `96e1f7d`:

- [push CI run 29421312228](https://github.com/DanilaMasov/Mayhem/actions/runs/29421312228):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29421314120](https://github.com/DanilaMasov/Mayhem/actions/runs/29421314120):
  repository contracts and Flutter format/analyze/test passed.

The post-R1 correction implementation is commit `49a5ab6` in merged pull request
[#5](https://github.com/DanilaMasov/Mayhem/pull/5), checkpoint `73b61c3`:

- [push CI run 29435408678](https://github.com/DanilaMasov/Mayhem/actions/runs/29435408678):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29435443641](https://github.com/DanilaMasov/Mayhem/actions/runs/29435443641):
  repository contracts and Flutter format/analyze/test passed.

The guarded R2 live-acceptance preparation is final branch commit `95cb456` in
merged pull request [#6](https://github.com/DanilaMasov/Mayhem/pull/6),
checkpoint `b50f36f`:

- [push CI run 29437932969](https://github.com/DanilaMasov/Mayhem/actions/runs/29437932969):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29437940068](https://github.com/DanilaMasov/Mayhem/actions/runs/29437940068):
  repository contracts and Flutter format/analyze/test passed;
- these source and dry-contract checks do not close the R2 live-backend gate.

The complete R2 live acceptance is merged from pull request
[#7](https://github.com/DanilaMasov/Mayhem/pull/7) at checkpoint `ccdd12d`:

- [push CI run 29596288252](https://github.com/DanilaMasov/Mayhem/actions/runs/29596288252):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29596307195](https://github.com/DanilaMasov/Mayhem/actions/runs/29596307195):
  repository contracts and Flutter format/analyze/test passed;
- final live fixes and evidence are commit `6884ab6`;
- [push CI run 29602473292](https://github.com/DanilaMasov/Mayhem/actions/runs/29602473292):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29602476160](https://github.com/DanilaMasov/Mayhem/actions/runs/29602476160):
  repository contracts and Flutter format/analyze/test passed.
- final branch evidence and cleanup are commit `3295a3d`;
- [final push CI run 29603351325](https://github.com/DanilaMasov/Mayhem/actions/runs/29603351325):
  repository contracts and Flutter format/analyze/test passed;
- [final pull-request CI run 29603353592](https://github.com/DanilaMasov/Mayhem/actions/runs/29603353592):
  repository contracts and Flutter format/analyze/test passed.

Migration-`011` hardening commit `d6d02ce` and merged pull request
[#19](https://github.com/DanilaMasov/Mayhem/pull/19) passed:

- [push CI run 29770972191](https://github.com/DanilaMasov/Mayhem/actions/runs/29770972191):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29770991600](https://github.com/DanilaMasov/Mayhem/actions/runs/29770991600):
  repository contracts and Flutter format/analyze/test passed;
- [protected live run 29771165967](https://github.com/DanilaMasov/Mayhem/actions/runs/29771165967):
  eleven migrations, nine live probes, eight Flutter client checks, and
  secret-free report verification passed.

The latest R2 live-backend gate is closed by
`docs/R2_LIVE_SUPABASE_ACCEPTANCE_REPORT_2026-07-20_MIGRATION_011.json`.
Simulator/emulator and physical-device gates remain open. GitHub Actions also
emits a non-blocking Node 20 action-runtime deprecation warning for the v4
checkout/setup actions; it does not affect the current green software gate.

## Next authorized slice

The R5 release-identity, launcher, Settings honesty, privacy-locked crash client,
protected ingestion/privacy harness, and support-path software boundary are
merged through PR #26 (`1849525`). The remaining R5 progress requires an
approved support value, an owner-provisioned staging Sentry project, DSN,
`project:read` token, protected live run, signed candidate, and physical-device
support/native-crash/symbolication acceptance. These are external owner,
credential, signing, or device gates rather than safe local implementation
work.
Production backend values, production telemetry, and release flags remain
unset.

With the blocker APK published, the next user-authorized software slice is a
readable local rating path: visible rank catalogue and thresholds, skill-map
legend, per-rank unlocked visual styles that remain selectable, and a vertical
arena-style progress history. A real public leaderboard per rank is not a
local-only UI feature; it remains gated on an explicit server, privacy, abuse,
and account-identity design instead of being simulated with fake users.

The manual, secret-free Android staging preview workflow was merged through
[PR #28](https://github.com/DanilaMasov/Mayhem/pull/28) as `8c01ced`. All six PR
checks passed, including Android and iOS staging release smoke builds. Manual
[run 29919995723](https://github.com/DanilaMasov/Mayhem/actions/runs/29919995723)
then built, signature-verified, and uploaded artifact
`mayhem-staging-preview-1`; the downloaded 171,027,777-byte APK passed ZIP
integrity verification and had SHA-256
`ffbd4ab09905d310a9df779b7e37516eb2b172f93fed6283da42dfec52754a7a`.
Download verification exposed that the checksum file retained its runner path,
so the portability fix was merged through
[PR #29](https://github.com/DanilaMasov/Mayhem/pull/29) as `e7dc244`; all four
push and pull-request CI checks passed. Final manual
[run 29926718883](https://github.com/DanilaMasov/Mayhem/actions/runs/29926718883)
then passed build, `apksigner` verification, packaging, and upload. Its
`mayhem-staging-preview-2` artifact produced a 171,027,777-byte APK with SHA-256
`c3ef4426e7a455d1f5b174ef0d0c0e4c0ef234125f32eb15c9b424696b2bf2f6`.
The downloaded checksum passed the documented standard verification command,
and the APK passed local ZIP integrity verification. The artifact expires on
2026-07-29, while an ignored local copy remains under `mobile/build/previews/`.
After PR #31 merged, manual
[run 29933014496](https://github.com/DanilaMasov/Mayhem/actions/runs/29933014496)
built and signature-verified `mayhem-staging-preview-3` from merge commit
`d813e31`. The downloaded 171,030,897-byte APK passed checksum and ZIP integrity
verification with SHA-256
`3da7d3c96aea6ecdb2a6b6b701dfe900119d01175ee8e9e8d699496d216da9d0`.
[Prerelease v0.1.0-preview.3](https://github.com/DanilaMasov/Mayhem/releases/tag/v0.1.0-preview.3)
publishes exactly one `Mayhem-staging-preview.apk` asset with the same digest.
The result remains debug-signed and cannot close R4 or any release/store gate.

The delivery sequence distinguishes closed-alpha requirements from later store
submission work. A preliminary R4 pass may start on two physical devices to
find defects, but it does not close the four-device gate. After R6 changes any
user-facing behavior or rendering, repeat the full R4 device regression on the
final candidate before expanding the closed alpha. Keep every production flag
false until its own specification gate is closed.

Historical reports under `docs/phase-reports/` are evidence only and are not
current authority.
