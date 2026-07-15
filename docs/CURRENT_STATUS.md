# Mayhem Current Status

**Status date:** 2026-07-15
**Authoritative specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`
**Production target:** Flutter application under `mobile/`
**Current branch:** `codex/runtime-composition`
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

## Active work item

Baseline pull request
[#1](https://github.com/DanilaMasov/Mayhem/pull/1) was merged into `main` as
`15c6397`. Phase R1 is in progress on `codex/runtime-composition`. The first
vertical slice publishes validated server flags into a mutable runtime and
proves live fail-closed UI behavior without enabling release defaults.

## Open software gates

- R1 production composition root, secure session adapter, cached-flag startup,
  non-blocking remote orchestration, lifecycle sync, remote Feed, and real
  account actions.
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

- No production auth/sync composition or Keychain/Keystore session adapter.
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
# 225 files, 0 changed

flutter analyze --no-pub
# no issues

flutter test --no-pub --no-test-assets -j 1
# 185 passed
```

R1 mutable-flag slice local evidence:

- release defaults remain false and debug overrides remain debug-only;
- cached/server snapshots require a valid lifetime and expire automatically;
- server records pass capability-revision validation before publication;
- remote bootstrap updates the effective runtime and gates remote content;
- widget coverage proves legacy Today to vNext and automatic TTL fallback
  without restarting the app;
- no package, lockfile, SDK, secret, or release-default change was introduced.

The first complete green GitHub baseline was commit `d7b33ce`:

- [push CI run 29409000516](https://github.com/DanilaMasov/Mayhem/actions/runs/29409000516):
  repository contracts and Flutter format/analyze/test passed;
- [pull-request CI run 29409002878](https://github.com/DanilaMasov/Mayhem/actions/runs/29409002878):
  repository contracts and Flutter format/analyze/test passed;
- Linux and macOS visual tests use strict platform-specific PNG baselines;
  no tolerance or automatic golden update is enabled in ordinary CI.

Baseline PR #1 is merged. CI for the current R1 slice is pending its commit,
push, and pull request. Live-backend, simulator/emulator, and physical-device
tests were not run and their gates remain open. GitHub Actions also emits a
non-blocking Node 20 action-runtime deprecation warning for the v4
checkout/setup actions; it does not affect the current baseline gate.

## Next authorized slice

Continue Phase R1 with the production composition owner, platform-protected
session adapter, cached-flag bootstrap, and non-blocking remote orchestration.
Keep every release flag false until its live-backend and device prerequisites
are satisfied. R2-R6 remain gated by the specification prerequisites.

Historical reports under `docs/phase-reports/` are evidence only and are not
current authority.
