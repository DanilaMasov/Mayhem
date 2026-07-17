# R2 Live Supabase Acceptance

**Status:** IMPLEMENTED, LIVE RUN BLOCKED
**Main checkpoint:** `b50f36f` (merge commit for PR #6)
**Branch:** `codex/r2-live-acceptance-completion`
**Preparation:** merged through [PR #6](https://github.com/DanilaMasov/Mayhem/pull/6)
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
target containing existing Mayhem tables, applies all eight migrations in
order, requests a PostgREST schema reload, executes the opt-in production
Flutter client test, and emits a secret-free JSON report on success or probe
failure.

## Forward-Only R2 Fixes

- `202607170007_r2_deletion_security_hardening.sql` closes the legacy
  security-definer search paths and decrements social-proof aggregates before
  deleting a participating user;
- `202607170008_artifact_projection_revision.sql` advances the server
  projection revision only when a genuinely new artifact is issued, allowing
  production reconciliation to observe ownership changes.

Neither migration has been applied to a live environment yet.

## Prepared Acceptance Probes

- two independent anonymous signups and one session refresh;
- installation registration and cross-user ownership rejection;
- RLS ownership isolation, grants/revokes, closed security-definer search paths,
  and direct table-write denial where RPC is required;
- canonical event acceptance and exact ACK;
- duplicate event idempotency;
- valid plus malformed batch partial ACK;
- private-note payload rejection;
- invalid access token, refresh, and successful retry;
- active/closed Season join, duplicate join, day availability, and duplicate day;
- Boss-window rejection, concurrent submissions, duplicate participation, and
  aggregate advisory-lock outcome;
- server-only artifact issuance, duplicate prevention, owned-only
  reconciliation, and projection-revision advancement;
- social-proof visibility below and at threshold with no identity/private-text
  fields;
- production Flutter anonymous bootstrap, secure-session serialization/restore,
  refresh, exact/partial ACK parsing, remote content and Feed persistence,
  Season persistence, artifact reconciliation, and interrupted deletion
  recovery;
- Delete Everywhere receipt/retry behavior, cross-user deletion denial, social
  counter compensation, full user cascade, and second-user survival.

## Report Contract

The JSON report contains only the environment identifier/host, migration
versions, static commands, per-probe timings, client check names, and explicit
`passed`, `failed`, `blocked`, and `notRun` lists. It never contains connection
URLs, keys, tokens, or server response bodies.

## Still Required Before R2 Acceptance

- provide one disposable real Supabase/PostgreSQL environment and `psql`;
- execute the complete runner from an empty Mayhem schema;
- record actual project identifier, commands, migration versions, timings, and
  results from the same environment;
- commit the generated secret-free acceptance report;
- rerun from a new clean target after any forward-only SQL fix.

Source and dry-run tests do not close the live-backend gate.
