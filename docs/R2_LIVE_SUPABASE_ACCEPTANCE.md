# R2 Live Supabase Acceptance

**Status:** PREPARED, NOT RUN
**Main checkpoint:** `73b61c3` (merge commit for PR #5)
**Branch:** `codex/live-supabase-gate`
**Draft pull request:** [#6](https://github.com/DanilaMasov/Mayhem/pull/6)
**Specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`, section 6

## Current Environment Evidence

- `SUPABASE_URL`: absent;
- `SUPABASE_ANON_KEY`: absent;
- `SUPABASE_DB_URL` / `DATABASE_URL`: absent;
- `psql`: unavailable;
- Supabase CLI, Docker, and Podman: unavailable;
- GitHub Actions R2 secrets and variables: absent.

No package, CLI, container runtime, SDK, or system component was installed.
No migration or destructive request was sent to a live service.

## Prepared Command

```sh
npm run supabase:live
```

Required environment variables:

- `MAYHEM_R2_ENVIRONMENT_ID`: non-production identifier;
- `MAYHEM_R2_CONFIRM_DISPOSABLE=I_UNDERSTAND_THIS_IS_DISPOSABLE`;
- `SUPABASE_URL`: HTTPS, except explicit localhost HTTP;
- `SUPABASE_ANON_KEY`: public anonymous key;
- `SUPABASE_DB_URL` or `DATABASE_URL`: disposable PostgreSQL connection;
- optional `MAYHEM_R2_REPORT_PATH`: new output file, never overwritten.

The runner sends the database connection only through `PGDATABASE`, refuses a
target containing existing Mayhem tables, applies all six migrations in order,
requests a PostgREST schema reload, and emits a secret-free JSON report.

## Prepared Core Probes

- two independent anonymous signups and one session refresh;
- installation registration and cross-user ownership rejection;
- RLS ownership isolation through authenticated REST reads;
- direct table-write denial where RPC is required;
- canonical event acceptance and exact ACK;
- duplicate event idempotency;
- valid plus malformed batch partial ACK;
- private-note payload rejection;
- invalid access token, refresh, and successful retry;
- Delete Everywhere receipt and deleted-session rejection;
- database verification that the deleted user is removed while the second user
  and installation survive.

## Still Required Before R2 Acceptance

- execute the prepared core probes against a disposable real environment;
- add and execute Season join/day/Boss-window fixtures;
- test concurrent and duplicate Boss submissions;
- prove server-owned artifact issuance and reconciliation;
- prove social-proof threshold visibility and private-data isolation;
- record actual project identifier, commands, migration versions, timings, and
  results from the same environment;
- execute mobile bootstrap/auth/sync against that environment.

Source and dry-run tests do not close the live-backend gate.
