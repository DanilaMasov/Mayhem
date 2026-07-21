# R5 Live Sentry Acceptance

This runbook defines the protected live-ingestion gate for the privacy-locked
staging crash client. It sends one synthetic event through the checked-in
Flutter adapter, retrieves that exact event through the Sentry API, and uploads
only a bounded secret-free report.

It does not enable production telemetry, alter product feature flags, provision
a Sentry project, or put a DSN in source control. Ordinary builds and tests do
not send an event.

## Protected GitHub Configuration

Create or reuse the approval-protected GitHub environment
`staging-acceptance`. Configure these environment secrets:

- `MAYHEM_SENTRY_DSN`: public HTTPS DSN for the dedicated staging project;
- `SENTRY_AUTH_TOKEN`: organization token with the minimum `project:read`
  scope required to retrieve the submitted event and list its attachments.

Configure these environment variables:

- `MAYHEM_R5_SENTRY_ENVIRONMENT_ID`: a non-production identifier such as
  `mayhem-staging-sentry`;
- `SENTRY_ORG`: staging Sentry organization slug;
- `SENTRY_PROJECT`: dedicated staging project slug;
- `SENTRY_API_BASE_URL`: optional Sentry SaaS region URL. The default is
  `https://sentry.io`; accepted regional hosts end in `.sentry.io`.

The API token is supplied only in the authorization header. The DSN and token
must not be printed, passed as command-line arguments, committed, or uploaded
as evidence. Sentry documents bearer-token API authentication and requires
`project:read`, `project:write`, or `project:admin` for retrieving a project
event; Mayhem uses the least-privileged read scope.

## Running the Gate

The workflow `.github/workflows/staging-sentry-acceptance.yml` is manual and
main-only. Select the exact confirmation
`I_UNDERSTAND_THIS_SENDS_A_SYNTHETIC_STAGING_EVENT` after both the crash client
and this acceptance harness are merged.

The workflow:

1. validates the protected configuration without echoing values;
2. resolves the committed Flutter lockfile;
3. runs `mobile/test/live/r5_live_sentry_test.dart` in the Flutter test harness
   with the separately tested release-staging configuration explicitly active;
4. sends one event containing a synthetic privacy marker, request, user,
   breadcrumb, context, stack detail, and attachment before the checked-in
   scrubber runs;
5. polls the exact 32-character event ID through the project-event API;
6. retrieves the event attachment list;
7. verifies the nine bounded acceptance checks;
8. uploads only `/tmp/mayhem-r5-sentry-report.json` for seven days.

The unredacted synthetic submission descriptor remains runner-local and is not
uploaded. Failures are reported as bounded error codes without response bodies,
DSNs, tokens, or event payloads.

## Passed Evidence Contract

A passing report proves:

- the exact event ID was ingested into the configured staging project;
- environment, release, and `staging_crash_v1` policy tags match;
- the synthetic private marker is absent from the retrieved event;
- user, request, and breadcrumb payloads are absent;
- exception detail is replaced with `details redacted`;
- the event has no attachments.

The report contains only the event ID, safe runtime identifiers, timestamps,
the nine fixed check names, and `result: passed`. The verifier rejects any
report containing the configured DSN or API token.

## Gates This Does Not Close

This hosted Flutter-test probe validates Dart-event ingestion and server-visible
privacy. It does not execute a release application binary and does not prove
Android/iOS native crash capture, debug-symbol upload, symbolication, offline
delivery, signed installation, startup behavior on a physical device, or owner
review in the Sentry UI. Those require a signed staging candidate and explicit
physical-device acceptance.
