> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

# Phase completed

Phase 0 - baseline and repository boundary.

## What changed

- Read the complete 5278-line master product/design/engineering specification.
- Audited the Flutter bootstrap, app root, controller, legacy state/engine,
  SQLite schema, event rebuild, sync transport, tests, content pipeline,
  Android release manifest, repository metadata and visual baseline.
- Created branch `codex/feed-vnext-foundation`.
- Captured the working app in commit `d3c6580` and tagged it
  `pre-feed-redesign-baseline` after all baseline checks passed.
- Added root ignore rules for local secrets, build output and generated artwork.
- Removed `.hatch-pets` authoring runs from the active Git index without deleting
  local files.
- Added local-equivalent CI checks for repository contracts and Flutter.
- Added production Android Internet permission.
- Explicitly separated the root web prototype from the `mobile/` production
  target and replaced the obsolete auth-first next-step note.
- Added the feed-first migration ADR and phased execution plan.

## Files changed

- `.gitignore`: root hygiene, secret and generated-art exclusions.
- `.github/workflows/ci.yml`: Node/content and Flutter quality gates.
- `mobile/android/app/src/main/AndroidManifest.xml`: production `INTERNET`.
- `README.md`, `mobile/README.md`, `package.json`: production/legacy boundary.
- `docs/adr/0001-feed-first-migration.md`: architecture decision.
- `docs/feed-vnext-execution-plan.md`: phased migration contract.
- `.hatch-pets/**`: removed from the active index, preserved on disk.

## Architecture decisions

ADR 0001 keeps Flutter and SQLite, preserves the legacy Today flow behind a
future flag, builds vNext feature-first beside it, forbids new Feed behavior in
`TodayController`, and requires local-first bootstrap and secure token storage.

## Data/migration impact

No database schema, event payload, snapshot or user data changed in Phase 0.
No local database was reset. The baseline tag provides a code rollback point.

## UI/motion result

No UI or motion changed by design. Existing screenshots were reviewed and
confirm that the card dashboard, Energy meter and four-destination navigation
must not be reused as the Feed design base. Design-system work remains Phase 2.

## Tests run

- `node --test tests/*.test.mjs`: 13 passed.
- `node scripts/export_mobile_content.mjs --check`: 50 quests, 5 bosses,
  55 guides, 29 dialogs and 5 modifiers verified.
- `node scripts/export_supabase_seed.mjs --check`: 50 quests and 5 bosses.
- `dart format --output=none --set-exit-if-changed lib test`: 44 files,
  0 changes.
- `dart analyze`: no issues.
- `flutter test --no-pub --no-test-assets -j 1`: 32 passed.
- `xmllint --noout` on Android manifest: valid.
- Ruby YAML parse on CI workflow: valid.

## Performance/accessibility

No runtime behavior changed, so existing performance/accessibility behavior is
unchanged. Real-device profiling and the new Reduce Motion/Transparency
contracts are gates for Phases 2, 3 and 7, not claimed complete here.

## Known limitations

- Git objects from the initial commit still contain old pet authoring files.
  Rewriting published history is intentionally not performed without an
  explicit maintenance decision. The files are no longer tracked by HEAD.
- GitHub-hosted CI is configured but cannot be observed until the branch is
  pushed.
- Android application ID and release signing remain development values and are
  finalized in Phase 7.
- Supabase SQL is still statically tested only; disposable-database compilation
  is a Phase 5 gate.

## Next phase readiness

Phase 1 can start from a green, tagged baseline. Its first slice is additive and
contains Clock, vNext domain entities/repository ports, event envelope v2 and
SQLite migration tests before any Feed UI is enabled.
