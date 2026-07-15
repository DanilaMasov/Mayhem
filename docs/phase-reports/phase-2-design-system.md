> **Historical, non-authoritative phase evidence.** See `../CURRENT_STATUS.md`.

# Phase 2 report: design system and Motion Lab

Date: 2026-07-13

Branch: `codex/motion-design-system`

Production target: `mobile/`

## Scope delivered

- Central token system for the master-spec palette, spacing, radii, typography,
  glass/material, shadows, durations and springs.
- Named curves, haptics and app/system Reduce Motion and Reduce Transparency
  resolution.
- Base components: scaffold, text, vector icon, pressable, primary/secondary
  button, Hold button, glass control, three-destination navigation, sheet,
  dialog, toast, loading, error and offline states.
- Product prototypes: five-state Momentum Core, Spark/Mover Rank Sigils,
  layered vertical Feed fixture and standard completion/attempt Reward Stage.
- Internal Motion Lab with foundation, Feed, object and action galleries.
- Debug-only route map and a separate development entrypoint. Legacy Today
  remains the production home and no Feed business state was connected.

## Deliberate decisions

- No Riverpod/router dependency was pulled into this phase. Typed application
  state and declarative production routing belong to Phase 3 after dependency
  and license review.
- Components receive semantic visual states only. They do not import legacy
  `GameState`, `TodayController`, repositories or SQLite.
- Hold uses the specified 620 ms threshold, exposes an immediate screen-reader
  confirmation action, cancels without error and guards the completion callback
  exactly once.
- Glass is limited to controls, navigation and sheets. High contrast or Reduce
  Transparency removes `BackdropFilter` and keeps the same border hierarchy.
- The PRD font weights 450/650 map to the nearest system-supported 500/600.
  Negative display tracking was intentionally normalized to zero for stable
  Dynamic Type rendering.
- Icons are small custom-painted vectors behind `MayhemGlyph`; the component
  API does not leak Material or Cupertino glyphs.

## Verification

- Dart analyzer: no issues.
- Dart formatter: 118 files checked, no pending formatting change.
- Flutter: 67 tests passed with `--no-pub --no-test-assets -j 1`.
- Node: 15 tests passed.
- Content: 50 quests, 5 bosses, 55 guides, 29 dialogs, 5 modifiers verified.
- Supabase seed: 50 quests and 5 bosses verified.
- SQLite v5 generator: 17 statements verified.
- Real SQLite: fresh schema, v4 upgrade and rollback passed.
- Layout smoke: 360x800, 390x844, 430x932 and 412x915.
- Dynamic Type smoke: text scale 1.3 and 1.6 across every Motion Lab section.
- Golden baselines:
  - `mobile/test/dev/goldens/motion_lab_foundation_390x844.png`;
  - `mobile/test/dev/goldens/motion_lab_objects_390x844.png`.
- Source audit found no literal colors, arbitrary durations, radii or shadows
  outside centralized token files in the new design-system/dev modules.

## Gate status

### Software/design-system gate: passed

The analyzer, unit/widget/golden checks, required phone viewports, text scaling,
reduced-motion/transparency variants and source-token audit are green. This gate
is sufficient to continue Phase 3 behind `new_feed_enabled = false`.

### Functional and visual device checks: pending

When simulator/emulator tooling is available, record iOS and Android smoke runs
for Feed swipes, Hold cancel/success, Reward, Dynamic Type and opaque fallback.
These checks validate behavior and visual composition only; they are not
performance acceptance.

### Physical-device performance gate: deferred and open

Before enabling the new Feed by default or distributing an internal beta,
record representative physical iOS and Android runs covering frame timings,
haptics, thermal behavior, Reduce Motion, Dynamic Type and sustained Feed use.
Only physical-device evidence can close this gate.

The host currently has no `simctl`, no usable `adb`/connected device and an
incomplete Flutter engine cache. The project does not call or require a
standalone `impellerc`; shaders and assets use Flutter's standard pipeline. The
local `--no-test-assets` command is a temporary host workaround for framework
test-asset compilation, not an application dependency. No SDK repair, Xcode,
Android SDK, simulator or external component was installed as part of this
phase or gate review.

One earlier launch omitted `--no-pub`. It resolved the unchanged lockfile,
changed neither `pubspec.yaml` nor `pubspec.lock`, and is accepted as harmless.
Subsequent reproducible checks use locked dependencies and do not update
packages without a separate task.
