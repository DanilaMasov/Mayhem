# MAYHEM Supabase contract

This directory contains the production database contract. It has not been applied to a remote project from this workspace.

## Migration order

1. `202607120001_core_event_log.sql` creates the catalog, installation ownership, append-only events, cached stats, Boss tables and RLS.
2. `202607120002_ingest_quest_events.sql` adds the authenticated, idempotent batch ingestion RPC.
3. `202607120003_quest_catalog_seed.sql` is generated from `src/data.js` and seeds 50 quests plus 5 Boss challenges.
4. `202607120004_delete_user_data.sql` adds current-user cloud-data deletion. Deleting the `auth.users` record remains an Edge Function responsibility.

## Generated seed

```sh
npm run supabase:seed
npm run supabase:seed:check
```

Never edit the generated seed directly. Update the canonical JS catalog, run both content exporters and review the resulting migration diff.

## RPC request contract

`ingest_quest_events(installation_id, events)` accepts at most 100 records:

```json
{
  "id": "client-event-uuid",
  "eventType": "quest_completed",
  "questId": "q_c_001",
  "modifierId": "echo",
  "payload": {},
  "createdAt": "2026-07-12T12:00:00.000Z"
}
```

The response maps directly to the mobile sync acknowledgement:

```json
{
  "acceptedIds": [],
  "rejectedById": {},
  "stats": {}
}
```

Boss completions are accepted only after a trusted server task has populated `daily_boss_quests` for that UTC date. The ingestion RPC never lets a client choose the Boss of the day.

## Verification boundary

Static contract tests verify schema invariants, event-name parity, generated seed parity, RLS and RPC safeguards. PostgreSQL/Supabase CLI is not installed in this workspace, so these migrations still require compilation against a disposable Supabase project before deployment.

## Guarded live acceptance

`npm run supabase:live` runs the first R2 live vertical slice without additional
Node dependencies. It requires an explicitly confirmed disposable environment,
an HTTPS Supabase URL (localhost HTTP is the only exception), the public anon
key, a PostgreSQL connection URL, and an available `psql` executable.

The runner refuses targets that already contain Mayhem tables. Credentials are
read only from environment variables; URLs, keys, refresh tokens, and access
tokens are excluded from reports and error messages. See
`docs/R2_LIVE_SUPABASE_ACCEPTANCE.md` for the exact variables, prepared probes,
and still-open R2 gates.
