# ADR 0001: Feed-first migration without a rewrite

- Status: Accepted
- Date: 2026-07-13
- Specification: `MAYHEM_MASTER_PRODUCT_DESIGN_TECH_SPEC.md`
- Reviewed specification SHA-256: `ed92f43c0d8cb8a36a8e4e55e95224c412ef04a0e84f6dbbe7322a768b6ed24e`

## Context

The existing Flutter application is a stable local-first quest tracker. It has
useful domain rules, SQLite snapshots, an append-only event journal, reflection
storage, preparation content, deterministic catalogs, sync retry mechanics and
tests. Its central product model is nevertheless incompatible with the new
MAYHEM contract: the home screen is a Today dashboard, `TodayController` owns
most transitions, `GameState` is a monolithic snapshot, Energy blocks actions,
and content assignments are generated as a deterministic daily selection.

A visual reskin of that flow would preserve the wrong product architecture.
A full rewrite would unnecessarily risk local history and discard tested
offline behavior.

## Decision

1. Flutter remains the production client and `mobile/` remains the production
   target.
2. The current Today flow becomes a legacy compatibility path. New Feed code is
   built feature-first beside it and is selected with `new_feed_enabled`.
3. SQLite remains the local authority while offline. Existing tables are kept
   through the migration window; vNext tables and migrations are additive.
4. Canonical history remains event based. vNext adds immutable content
   revisions, per-installation client sequence, checkpoints and quarantine.
5. `GameState` and `TodayController` are not extended for Feed, Momentum, Rank,
   Season or auth. Those concerns receive separate entities, repositories and
   application controllers.
6. Network work never blocks the first local render. Remote auth, flags, sync
   and content refresh start after local readiness.
7. Private reflection text stays local by default. Auth tokens may only be
   persisted through a platform secure-storage adapter, never SQLite.
8. Design-system and motion work starts after the vNext domain and migration
   contracts are testable. Legacy visuals are not treated as a design base.

## Consequences

- During migration the repository contains both legacy and vNext paths.
- Adapters are required for legacy quests, guides, dialogs, events and stats.
- Database work must be validated against both a fresh database and the current
  version 4 schema before the Feed flag can be enabled.
- Additional packages require a recorded need, license review and compatible
  lockfile. No package is added during baseline work.
- The existing Supabase SQL remains a reference until a disposable vNext
  database proves migrations, RLS and RPC behavior.

## Deliberately deferred

- Final rank thresholds and sigil artwork.
- Final Momentum Core materials.
- Analytics, crash, CDN and sound vendors.
- Account linking provider details.
- Companion, Circle and unrestricted UGC.
