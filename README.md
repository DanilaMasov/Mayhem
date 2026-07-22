# Mayhem

Mayhem is a local-first Flutter mobile application for structured social
challenges. The production application lives in [`mobile/`](mobile/). Root web
files are frozen legacy/reference material and must not receive new product
functionality.

## Start here

- [Current specification](docs/MAYHEM_CURRENT_SPEC_v1.2.md) - authoritative
  product, recovery, gate, and execution contract.
- [Current status](docs/CURRENT_STATUS.md) - implemented capabilities, open
  gates, latest evidence, and next authorized slice.
- [Agent contract](AGENTS.md) - mandatory boundaries for future Codex sessions.
- [Mobile documentation](mobile/README.md) - Flutter project details.
- [Release configuration](docs/RELEASE_CONFIGURATION.md) - environments,
  identities, support contact, signing, telemetry, and external ownership
  gates.
- [R5 live Sentry acceptance](docs/R5_LIVE_SENTRY_ACCEPTANCE.md) - protected
  staging ingestion/privacy runbook and bounded evidence contract.
- [Android preview APK](docs/ANDROID_PREVIEW_APK.md) - manual installable
  staging preview build and its explicit non-release boundary.

Kira and `.hatch-pets/` are not part of Mayhem. They must remain untracked and
must never be imported into the product or used as product/design requirements.

## Local verification

Repository contracts and deterministic generation:

```sh
node --test tests/*.test.mjs
node scripts/export_mobile_content.mjs --check
node scripts/export_mobile_migrations.mjs --check
python3 scripts/test_mobile_migration.py
node scripts/export_supabase_seed.mjs --check
```

Flutter verification with locked dependencies:

```sh
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --no-test-assets -j 1
```

The app must continue to open from local SQLite and bundled content when every
remote service is unavailable. Production flags remain fail-closed until their
software, live-backend, and physical-device gates have evidence.

## Historical material

Older PRDs, audits, development logs, execution plans, ADRs, phase reports, and
the root web prototype are retained as historical evidence. They are
non-authoritative when they conflict with
[`docs/MAYHEM_CURRENT_SPEC_v1.2.md`](docs/MAYHEM_CURRENT_SPEC_v1.2.md).
