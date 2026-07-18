# MAYHEM Mobile

Production-oriented Flutter implementation for iOS and Android. The web app in the repository root is a UX/reference prototype; new product development targets this mobile project.

## Current vertical slice

- native Flutter Today screen with Daily Drop first and two Backup Runs;
- zero-registration three-quest onboarding with a post-first-success safety boundary;
- local profile with stat progress and completed-quest history;
- Settings/About boundaries and transactional deletion of all device-local progress;
- Quest Detail with main/alternate route selection;
- working Accept, Complete and Leave actions;
- Reflection screen with two scores, repeat intent, optional note and penalty-free skip;
- Quest Guide screen with category-specific execution steps, working phrases, alternate route, escalation and clean exit;
- quest-specific branching rehearsals for all 24 eligible level 2/3 quests and all 5 Boss challenges;
- legacy energy regeneration retained as a readiness signal without an action gate;
- canonical `quest_started`, `quest_completed`, `quest_deferred` events;
- route variant and attempt duration persisted in events;
- rehearsal preparation survives Leave, grants +10% XP and clears after completion;
- one safe modifier roll per calendar day, persisted through Leave and attached to lifecycle events;
- deterministic local-noon and UTC daily selection;
- complete 50-quest + 5-Boss versioned JSON catalog validated before use;
- separate versioned guide catalog with complete quest-ID coverage validation;
- SQLite snapshot + append-only event log committed in one transaction;
- event-derived state rebuild with automatic snapshot repair on startup;
- durable event sync queue with bounded batches, partial ack, permanent rejection and exponential retry metadata;
- versioned Supabase schema, generated quest seed and authenticated ingestion/deletion RPC contracts;
- injected Supabase HTTP transport and resettable durable installation identity, disabled until an authenticated session exists;
- SQLite reflection records committed atomically with completion and event log updates;
- production identity `com.danilamasov.mayhem` and isolated staging identity
  `com.danilamasov.mayhem.staging` on Android and iOS;
- Android 10 / API 29 and iOS 16 minimum supported versions;
- portrait phone orientation.

## Architecture

```text
presentation/
  Today + Quest Detail widgets
        |
application/
  TodayController
        |
domain/
  models + GameEngine + GameStore port
        |
data/                 infrastructure/
  bundled catalog       SQLite GameStore
```

Domain code has no dependency on SQLite, Supabase or widgets. `GameStore` can be replaced by another adapter without changing game rules or presentation.

## Commands

```sh
cd ..
npm run content:export
npm run content:check
cd mobile
flutter analyze --no-pub
flutter test --no-pub --no-test-assets -j 1
flutter run --no-pub --flavor staging
```

The root JS catalog is a temporary legacy migration source. `content:export`
still updates all four mobile JSON assets during the compatibility window;
`content:check` fails when committed assets differ from a deterministic export.
Production content will move to immutable versioned JSON records with schema
validation before remote content is enabled.

`--no-test-assets` is a temporary workaround for this host's incomplete Flutter
3.44.6 engine cache while the framework compiles its standard
`ink_sparkle.frag` test asset. The project does not invoke or require a separate
`impellerc` binary; application shaders and assets remain on Flutter's standard
pipeline. Domain and widget tests themselves pass.

## Toolchain status

- Locked software checks target Flutter 3.44.6 / Dart 3.12.2.
- No SDK, simulator, signing tool, or system package is installed automatically.
- Android release verification requires an approved SDK/license environment.
- iOS archive verification requires an approved Xcode/CocoaPods/signing environment.
- Physical-device acceptance remains mandatory and cannot be replaced by CI,
  simulators, or emulators.

Release environment, signing, versioning, and open-approval rules are recorded
in [`../docs/RELEASE_CONFIGURATION.md`](../docs/RELEASE_CONFIGURATION.md).

## Feed-first migration

The July 2026 master specification supersedes the previous incremental Today
roadmap. The local-first Feed, production composition, live Supabase acceptance,
and R3 Season/Boss software flow are implemented behind fail-closed production
flags. Physical-device R4 evidence, migration `010` live acceptance, and R5
release approvals remain open. See `../docs/CURRENT_STATUS.md` for the current
checkpoint and `../docs/feed-vnext-execution-plan.md` for historical execution
context.

### Domain vNext foundation

Phase 1 is implemented behind the disabled Feed flag:

- additive SQLite v5 schema with immutable content revisions, assignments,
  attempts, private reflections, event v2, checkpoints and quarantine;
- deterministic v4 progress/reflection import with exact XP preservation;
- transactional per-installation client sequence;
- separate Challenge, Feed, Progress, Momentum, Reflection and Season ports;
- tested attempted/completed rewards, Momentum Shield, balanced Rank and
  rule-based difficulty policies;
- legacy Energy no longer blocks accepting a challenge.

The production default remains legacy Today until physical-device and rollout
gates explicitly authorize the new Feed.

### Design system and Motion Lab

Phase 2 now provides a feature-independent visual foundation:

- centralized color, spacing, radius, typography, material, shadow, duration,
  curve, spring and haptic primitives;
- accessible pressable, primary/secondary/hold buttons, glass controls,
  bottom navigation, sheet, dialog and feedback states;
- custom vector glyphs with no Material/Cupertino icon dependency;
- semantic Momentum Core and Spark/Mover Rank Sigil prototypes;
- vertical fixture Feed with layered drag response and centralized physics;
- standard/reduced-motion Reward Stage and transparency fallbacks;
- internal `/_internal/motion-lab` route included only in debug builds.

Run the isolated gallery with:

```sh
flutter run --no-pub --flavor staging -t lib/dev/motion_lab/main.dart
```

The current local Flutter SDK cannot launch it because its engine cache is
incomplete; no SDK repair or download was attempted. Widget tests and goldens
cover the four required phone sizes and text scale through 1.6.

The Phase 2 software/design-system gate is passed. Simulator/emulator smoke
remains a functional and visual check only. Physical iOS and Android performance
acceptance remains open and is mandatory before enabling the Feed by default or
distributing an internal beta.
