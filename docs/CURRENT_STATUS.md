# Mayhem Current Status

**Status date:** 2026-07-17
**Authoritative specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`
**Production target:** Flutter application under `mobile/`
**Current branch:** `codex/r3-season-boss-flow`
**Current main checkpoint:** `ccdd12d` (merge commit for PR #7)
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
`ccdd12d`. The final disposable Supabase run applied nine migrations from zero
and passed all nine backend probes plus eight production Flutter client checks.
Its secret-free report is
`docs/R2_LIVE_SUPABASE_ACCEPTANCE_REPORT_2026-07-17.json`. R3 is active on
`codex/r3-season-boss-flow`; its first slice adds explicit read-only
Season/Boss state projection and cached-versus-confirmed UX without exposing
unconfirmed Join or Boss mutations. Remote operations still activate only
with a valid environment-specific Supabase configuration.

## Open software gates

- R3 server-authoritative Join/day/Boss mutations, interruption recovery, and
  remaining state-specific UX.
- R5 release configuration and hardening.
- R6 visual refinement, authorized only after R1-R4 evidence.

## Live-backend gates

- R2 disposable Supabase/PostgreSQL migration, RLS, grants, RPC, concurrency,
  deletion, auth, sync, Season/Boss, artifact, social-proof, and production
  Flutter client acceptance is closed by the 2026-07-17 live report.
- No production Supabase environment has been configured or authorized.

## Open device gates

- R4 physical iOS and Android performance, lifecycle, accessibility, haptics,
  thermal, migration, secure-session, and interrupted-deletion acceptance.
- Simulator/emulator evidence cannot close physical-device acceptance.

## Known release blockers

- Production remote auth/sync remains unavailable in builds without
  `SUPABASE_URL` and `SUPABASE_ANON_KEY`; no production target is configured.
- `new_feed_enabled` and all dependent release capabilities remain false.
- R3 user-visible Season/Boss recovery UX, physical-device acceptance,
  release signing, final application IDs, production assets, and store
  configuration remain incomplete.

## Verification

Clean-clone local verification completed on 2026-07-17. Commands and local
results:

```sh
node --test tests/*.test.mjs
# 34 passed

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
# 246 files, 0 changed

flutter analyze --no-pub
# no issues

flutter test --no-pub --no-test-assets -j 1
# 226 passed; 1 live-only test skipped without an explicit disposable target
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
- no Join, day-completion, or Boss mutation is exposed by this slice, because
  the existing local event coordinator alone does not prove server acceptance.

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
- refuses a target containing existing Mayhem tables and applies nine
  migrations from zero in deterministic order through `psql`;
- prepares two-user auth/refresh, ownership/RLS, grants, direct-write denial,
  exact/duplicate/partial ACK, private-note rejection, and auth recovery;
- covers Season join/day/closed-window rules, concurrent Boss submission,
  duplicate participation, advisory-lock effects, server-owned artifacts,
  thresholded social proof, identity/privacy isolation, and deletion cleanup;
- invokes production Flutter auth/backend/content/Feed/Season/reconciliation
  and Delete Everywhere adapters in a headless opt-in live test;
- adds migration `007` to close legacy security-definer search paths and
  decrement social proof during deletion, plus migration `008` to advance the
  projection revision only for newly issued artifacts, and migration `009` to
  repair recursive private-note validation found by the live run;
- decomposes PostgreSQL credentials into libpq environment fields and sends
  parameterized verification SQL through stdin instead of argv;
- the final disposable run passed all nine probes in 64,526 ms with no failed,
  blocked, or not-run checks;
- the disposable Supabase project/organization, temporary credentials and
  reports, and acceptance-only Homebrew formulas were removed after evidence;
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

The R2 live-backend gate is closed by
`docs/R2_LIVE_SUPABASE_ACCEPTANCE_REPORT_2026-07-17.json`. Simulator/emulator
and physical-device gates remain open. GitHub Actions also emits a non-blocking
Node 20 action-runtime deprecation warning for the v4 checkout/setup actions;
it does not affect the current green software gate.

## Next authorized slice

Complete the next R3 slice with server-authoritative Join/day/Boss mutation,
authoritative participation refresh, bounded retry, and process-death recovery.
Keep every release flag false until its own specification gate is closed. R4
physical-device acceptance and R5-R6 release work remain separately gated.

Historical reports under `docs/phase-reports/` are evidence only and are not
current authority.
