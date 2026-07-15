# Mayhem Current Status

**Status date:** 2026-07-15
**Authoritative specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`
**Production target:** Flutter application under `mobile/`
**Current branch:** `codex/runtime-orchestration`
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

## Active work item

Baseline pull request #1 and mutable-flag pull request
[#2](https://github.com/DanilaMasov/Mayhem/pull/2) are merged into `main`; PR #2
landed as `7825c8d`. Phase R1 continues in
[#3](https://github.com/DanilaMasov/Mayhem/pull/3) on
`codex/runtime-orchestration`. Commit `6708701` moves startup and lifecycle
ownership into `AppCompositionRoot` while deliberately keeping production
remote operations disabled until secure session storage exists.

## Open software gates

- R1 secure session adapter, concrete Supabase composition, cached-flag startup,
  bounded network timeouts/retries, terminal-action sync triggers, remote Feed,
  and real account actions.
- R3 complete user-visible Season/Boss state machine and recovery UX.
- R5 release configuration and hardening.
- R6 visual refinement, authorized only after R1-R4 evidence.

## Open live-backend gates

- R2 disposable Supabase/PostgreSQL migration, RLS, grants, RPC, concurrency,
  deletion, auth, sync, Season/Boss, artifact, and social-proof acceptance.
- Current SQL evidence is source-contract coverage only.

## Open device gates

- R4 physical iOS and Android performance, lifecycle, accessibility, haptics,
  thermal, migration, secure-session, and interrupted-deletion acceptance.
- Simulator/emulator evidence cannot close physical-device acceptance.

## Known release blockers

- Production remote auth/sync remains disabled because no Keychain/Keystore
  session adapter is composed yet.
- `new_feed_enabled` and all dependent release capabilities remain false.
- No live-backend acceptance, physical-device acceptance, release signing,
  final application IDs, production assets, or store configuration.

## Verification

Clean-clone local verification completed on 2026-07-15. Commands and local
results:

```sh
node --test tests/*.test.mjs
# 22 passed

node scripts/export_mobile_content.mjs --check
# 50 quests, 5 bosses, 55 guides, 29 dialogs, 5 modifiers

node scripts/export_mobile_migrations.mjs --check
# v5: 17 statements; v6: 2 statements

python3 scripts/test_mobile_migration.py
# fresh v6, v4-to-v6 upgrade, and rollback passed on real SQLite

node scripts/export_supabase_seed.mjs --check
# 50 quests and 5 bosses verified

cd mobile
flutter pub get --offline
# locked dependencies restored from the existing local package cache

dart format --output=none --set-exit-if-changed lib test
# 229 files, 0 changed

flutter analyze --no-pub
# no issues

flutter test --no-pub --no-test-assets -j 1
# 190 passed
```

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

Live-backend, simulator/emulator, and physical-device tests were not run and
their gates remain open. GitHub Actions also emits a non-blocking Node 20
action-runtime deprecation warning for the v4 checkout/setup actions; it does
not affect the current green software gate.

## Next authorized slice

Continue Phase R1 with the platform-protected session adapter and concrete
Supabase composition, then load valid cached flags before non-blocking remote
refresh. Keep every release flag false until its live-backend and device
prerequisites are satisfied. R2-R6 remain gated by the specification
prerequisites.

Historical reports under `docs/phase-reports/` are evidence only and are not
current authority.
