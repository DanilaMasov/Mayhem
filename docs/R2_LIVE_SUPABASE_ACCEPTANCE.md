# R2 Live Supabase Acceptance

**Status:** ACCEPTED ON DISPOSABLE LIVE BACKEND
**Main checkpoint:** `b50f36f` (merge commit for PR #6)
**Branch:** `codex/r2-live-acceptance-completion`
**Completion PR:** [PR #7](https://github.com/DanilaMasov/Mayhem/pull/7)
**Specification:** `docs/MAYHEM_CURRENT_SPEC_v1.2.md`, section 6
**Final evidence:** `docs/R2_LIVE_SUPABASE_ACCEPTANCE_REPORT_2026-07-17.json`

## Environment

- disposable organization: `Mayhem R2 Disposable 2026-07-17`, Free plan;
- disposable project: `mayhem-r2-disposable-20260717`;
- environment/project ref: `sgabxgyrvtwasjwenxyu`;
- region: West EU (Ireland), `eu-west-1`;
- final project health before acceptance: Healthy;
- PostgreSQL client: keg-only Homebrew `libpq 18.4`;
- anonymous sign-ins enabled only for this disposable project;
- automatic grants for newly created Data API tables were disabled;
- no Supabase CLI, Docker, Podman, PostgreSQL server, Xcode, Android SDK, or
  other system SDK was installed.

During acceptance, the DB URL and publishable key existed only in
`/private/tmp/mayhem-r2-sgabxgyrvtwasjwenxyu.env` with mode `0600`. They were
never committed, added to shell profiles, added to GitHub Secrets, or printed
by the runner. The file, disposable project, and disposable organization were
deleted after PR and CI evidence completed.

## Command

The package command is:

```sh
npm run supabase:live
```

`npm` is not installed in the local environment, so the equivalent locked
entrypoint was used without installing Node tooling:

```sh
PATH="/opt/homebrew/opt/libpq/bin:$PATH" \
  /Users/emperor/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  scripts/run_live_supabase_acceptance.mjs
```

Required variables were loaded from the mode-`0600` temporary file:

- `MAYHEM_R2_ENVIRONMENT_ID`;
- `MAYHEM_R2_CONFIRM_DISPOSABLE=I_UNDERSTAND_THIS_IS_DISPOSABLE`;
- `MAYHEM_R2_REPORT_PATH`;
- `SUPABASE_URL`;
- `SUPABASE_ANON_KEY`;
- `SUPABASE_DB_URL`.

The runner decomposes the PostgreSQL URI into libpq variables and never places
the URI or password in argv. Parameterized verification SQL is sent through
stdin with `psql --file=-`, where psql variable substitution is active.

## Findings And Fixes

1. Attempt 1 applied migrations and then failed with
   `anonymous_provider_disabled`. Anonymous sign-ins were enabled only on the
   disposable project. No auth users had been created.
2. Attempt 2 proved that `mayhem_jsonb_has_private_note_key(jsonb)` had an
   ambiguous `value` reference, causing every canonical event to become
   `permanent_schema`. Migration
   `202607170009_private_note_validator_fix.sql` qualifies iterator fields.
3. Attempt 3 proved that psql variables are not substituted in `--command`
   input. `PsqlRunner.query()` now uses stdin and `--file=-`.
4. Attempt 4 passed all nine probes and exposed only an inaccurate static
   fixture-command label in the report metadata.
5. Attempt 5 ran the exact final code from an empty schema and produced the
   committed report. It passed all nine probes in 64,526 ms.

Every failed attempt emitted a secret-free report with explicit passed,
failed, and not-run probes. Before each clean rerun, the disposable `public`
schema and test-only auth users were reset atomically. Failed reset commands
were transactionally rolled back and verified by unchanged object counts.

## Final Result

- nine migrations applied from zero in deterministic order;
- nine live probes passed;
- eight production Flutter client checks passed;
- zero failed probes;
- zero blocked probes;
- zero not-run probes;
- report scan found no anon key or database URL;
- Delete Everywhere removed the first user and all owned data, compensated
  social proof, preserved its receipt contract, and left the second user and
  owned state intact.

Covered behavior includes anonymous auth/refresh, installation ownership,
RLS and grant boundaries, exact/duplicate/partial ACK, revoked-token recovery,
Season windows and idempotency, concurrent Boss submissions, server-owned
artifacts, thresholded social proof, production Flutter adapters, and complete
cross-user-safe deletion.

## GitHub CI

Final live fixes and evidence at commit `6884ab6` passed both CI events:

- [push run 29602473292](https://github.com/DanilaMasov/Mayhem/actions/runs/29602473292);
- [pull-request run 29602476160](https://github.com/DanilaMasov/Mayhem/actions/runs/29602476160).

Each run passed repository contracts and Flutter format/analyze/test.

## Remaining Gates

The R2 live-backend gate is closed. Release flags remain false. Simulator and
physical-device acceptance remain open and cannot be closed by this headless
backend run. R3 may begin only after PR #7 is green and merged.

## Cleanup Record

Installed locally for this acceptance only:

- `libpq 18.4`;
- `krb5 1.22.2`, installed as a `libpq` dependency;
- `readline 8.3.3`, installed as a `libpq` dependency.

Cleanup completed on 2026-07-17:

- deleted project `sgabxgyrvtwasjwenxyu`;
- deleted organization `birrqamaehnouxzrapey`;
- removed the mode-`0600` env file, final temporary report, four attempt
  reports, PR body, and diff-audit file from `/private/tmp`;
- reset the browser automation process that held credentials in memory;
- verified that only `libpq` used the newly installed `krb5` and `readline`;
- uninstalled `libpq 18.4`, `krb5 1.22.2`, and `readline 8.3.3`;
- confirmed that no PATH or shell-profile line had been added.
