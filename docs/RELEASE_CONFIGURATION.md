# Mayhem Release Configuration

This document defines the checked-in release configuration policy. Application
identifiers, supported OS floors, environment ownership, and alpha telemetry
policy were approved on 2026-07-18. It does not claim that the identifiers are
registered in either store, signing is configured, store marketing artwork is
approved, or a production backend exists.

## Application Identity

| Target | Identifier | Display name |
| --- | --- | --- |
| Android production | `com.danilamasov.mayhem` | `MAYHEM` |
| Android staging | `com.danilamasov.mayhem.staging` | `MAYHEM STAGING` |
| iOS production | `com.danilamasov.mayhem` | `MAYHEM` |
| iOS staging | `com.danilamasov.mayhem.staging` | `MAYHEM STAGING` |

The minimum supported versions are Android 10 / API 29 and iOS 16. Before a
signed upload, the owner must verify that both production identifiers can be
registered in the personal Apple Developer and Google Play accounts. A store
conflict is a blocking owner decision; the checked-in identifiers must not be
silently replaced.

## Environments

The application accepts exactly three `MAYHEM_ENVIRONMENT` values:

- `development`: the debug default; loopback HTTP is allowed only here;
- `staging`: a release-capable non-production target for internal acceptance;
- `production`: the release default; Supabase must use HTTPS.

Release builds reject `development`. Unknown or misspelled values fail at
startup instead of creating a new secure-storage namespace or sending an
unsupported backend environment.

Native `production` and `staging` flavors set the corresponding runtime
environment through Flutter's `appFlavor`. An explicit `MAYHEM_ENVIRONMENT`
may be supplied as a defense-in-depth assertion, but a mismatch with the native
flavor fails at startup. Staging and production must use fully separate
Supabase projects; production remains unconfigured until staging acceptance is
complete.

Supabase values are supplied with Dart defines and must not be committed:

```sh
flutter build appbundle --release --no-pub \
  --flavor staging \
  --dart-define=MAYHEM_ENVIRONMENT=staging \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=STAGING_ANON_KEY \
  --build-name=1.0.0 \
  --build-number=1
```

The equivalent iOS configuration is selected with `--flavor staging`. Use
`--flavor production` only for an explicitly approved production build.

The client may receive only the publishable anonymous key. A service-role key,
database password, access token, or refresh token must never be passed through
Dart defines, source files, build logs, or store metadata.

## Unsigned CI Smoke

`.github/workflows/staging-release-smoke.yml` compiles an unsigned Android
staging AAB and an unsigned iOS staging release application on hosted GitHub
runners. It is pull-request/manual only, enforces the committed lockfile, uses
no backend or signing secret, and never targets the production flavor.

A successful smoke run proves that Flutter and the native toolchains can
compile the checked-in staging configuration. It does not prove signing,
installation, launch, runtime backend behavior, physical-device performance,
accessibility, store registration, or distribution readiness.

## Staging Crash Reporting

The Flutter client includes `sentry_flutter 9.24.0` solely for crash reporting.
It initializes only when all three conditions are true:

- the native/runtime environment is exactly `staging`;
- the app is compiled in release mode;
- `MAYHEM_SENTRY_DSN` contains a valid public HTTPS Sentry DSN.

Development and production builds remain fail-closed even if a DSN is passed
accidentally. A missing, malformed, insecure, or secret-bearing DSN disables
the adapter without blocking local-first app launch. The DSN is supplied as a
Dart define by the approved CI/signing environment and must not be committed or
printed in logs.

The staging policy captures crashes only. Default PII, breadcrumbs, HTTP
failures, request/response bodies, logs, metrics, performance traces, profiling,
session replay, screenshots, view hierarchy, user-interaction data, package
inventory, ANR/app-hang reports, and automatic session tracking are disabled.
The final `beforeSend` scrubber also removes users, requests, attachments,
arbitrary contexts, exception values, source context, local absolute paths, and
mechanism data before an event can leave the process.

No Sentry project or DSN is checked in. Live staging ingestion, symbolication,
offline delivery, native crash capture, and privacy inspection remain open
acceptance gates until the owner provisions an approved staging project and a
signed staging build is exercised. Production crash reporting remains disabled
until that staging policy is reviewed and explicitly approved for production.

The manual, main-only
`.github/workflows/staging-sentry-acceptance.yml` gate submits one synthetic
release-staging event, retrieves the exact event and its attachment list with a
least-privileged `project:read` token, and uploads only a bounded secret-free
report. Its protected configuration and evidence contract are documented in
[`R5_LIVE_SENTRY_ACCEPTANCE.md`](R5_LIVE_SENTRY_ACCEPTANCE.md). A passing hosted
probe validates Dart-event ingestion and the server-visible privacy scrubber;
it does not close native crash, symbolication, signed-build, or physical-device
acceptance.

## Support Contact

Both the legacy and vNext Settings screens consume one compile-time
`MAYHEM_SUPPORT_CONTACT` value. An approved release build may provide either:

- a plain email address or canonical `mailto:` address without query data;
- a public `https://` support page without embedded user credentials.

Missing, malformed, insecure, credential-bearing, or unsupported schemes are
ignored, so they cannot create a dead control or block local-first startup. A
valid value exposes one user-initiated external action and a bounded public
destination label. Failure to hand the URI to the platform is shown in-app and
does not log or persist the URI.

The implementation adds the Flutter-owned `url_launcher 6.3.2` plugin solely
for this platform handoff. It calls `launchUrl` directly and handles failure;
it does not probe installed applications or require Android package-visibility
or iOS query-scheme declarations.

Example release input:

```sh
--dart-define=MAYHEM_SUPPORT_CONTACT=support@example.com
```

This software boundary does not approve or provision the public destination.
Before a signed beta, the owner must select the email or HTTPS page, inject the
same approved value into both platform builds, and verify the action on signed
physical-device installs. Until then the Settings entry remains absent.

## Launcher Assets

Mayhem-owned production and staging launcher masters live under
`mobile/assets/brand/`. They are opaque RGB artwork with no embedded text or
external trademark:

- production uses the dark Mayhem monogram with a coral action signal;
- staging adds a persistent amber corner warning and is not a silent copy of
  production;
- Android provides density PNGs, an adaptive foreground/background, and a
  monochrome themed icon;
- iOS provides complete production `AppIcon` and staging `AppIconStaging`
  catalogs; all staging build configurations select the staging catalog.

The committed asset contract checks dimensions, color type, platform
completeness, adaptive resources, staging separation, and native assignments.
Launcher assets do not close store screenshot, feature-graphic, promotional
artwork, or signed-device appearance gates.

## Android Signing

Android release builds never fall back to the debug signing key. A signing
configuration is created only when all four external variables exist:

- `MAYHEM_ANDROID_KEYSTORE_PATH`;
- `MAYHEM_ANDROID_KEYSTORE_PASSWORD`;
- `MAYHEM_ANDROID_KEY_ALIAS`;
- `MAYHEM_ANDROID_KEY_PASSWORD`.

A partial set fails Gradle configuration. Keystores and signing credentials
belong in the approved local/CI secret store and are ignored by Git. Without
the variables, the project can produce only an unsigned release artifact; it
is not eligible for distribution.

## iOS Signing

The repository contains no development team, provisioning profile, certificate,
or signing password. Those values must be configured in the approved Apple/CI
signing environment. An archive is not accepted as release evidence until its
bundle identifier, team, profile, entitlements, and export method are recorded.

## Version Policy

- `build-name` uses semantic `major.minor.patch` product versions.
- `build-number` is a positive integer that increases for every uploaded build
  on both stores and is never reused for a different commit.
- The release record must include Git commit, environment, build name, build
  number, signing identity fingerprint, and CI run.
- The `pubspec.yaml` value is a local default; CI/store builds provide explicit
  values and must not modify the lockfile.

## Open Decisions

Before an external beta or store build, the owner must approve:

- launcher appearance on signed physical-device installs and store artwork;
- support email or HTTPS support URL;
- privacy/store metadata and production Supabase target.

Signing ownership is assigned to the owner's personal Apple Developer and
Google Play accounts, but certificates, provisioning, Play App Signing, the
Android upload keystore, encrypted backups, and CI environments remain an
external manual gate.

Product analytics remain absent for the closed alpha. The privacy-locked Sentry
client is implemented for staging, but project provisioning, DSN injection,
live event inspection, and signed-device acceptance remain external gates.
Production telemetry stays disabled until the staging policy is accepted.
