# Mayhem Current Status

**Status date:** 2026-07-15
**Authoritative specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`
**Production target:** Flutter application under `mobile/`
**Current branch:** `codex/current-baseline`
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

## Active work item

Repository Recovery and Documentation Consolidation from specification
sections 3, 4, and 14. Production Composition Root and all later phases are
intentionally not started on this branch.

## Open software gates

- R1 production composition root, secure session adapter, mutable effective
  flags, lifecycle sync, remote Feed, and real account actions.
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

Clean-clone local verification completed on 2026-07-15. GitHub CI remains
pending until this documentation commit is pushed. Commands and local results:

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
# 179 passed
```

`git diff --check`, clean-tree/Kira-history checks, branch upstream, merge-base,
pull-request URL, and GitHub CI result are recorded after the documentation
commit and push. Live-backend, simulator/emulator, and physical-device tests
were not run and their gates remain open.

## Next authorized slice

First make the clean baseline pull request and GitHub CI green. Only after that
may a new `codex/runtime-composition` branch begin Phase R1. R2-R6 remain
unauthorized until their prerequisites in the specification are satisfied.

Historical reports under `docs/phase-reports/` are evidence only and are not
current authority.
