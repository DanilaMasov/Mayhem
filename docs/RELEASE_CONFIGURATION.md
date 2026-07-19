# Mayhem Release Configuration

This document defines the checked-in release configuration policy. Application
identifiers, supported OS floors, environment ownership, and alpha telemetry
policy were approved on 2026-07-18. It does not claim that the identifiers are
registered in either store, signing is configured, launcher artwork is final,
or a production backend exists.

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

- final launcher icon and store artwork;
- support email or HTTPS support URL;
- privacy/store metadata and production Supabase target.

Signing ownership is assigned to the owner's personal Apple Developer and
Google Play accounts, but certificates, provisioning, Play App Signing, the
Android upload keystore, encrypted backups, and CI environments remain an
external manual gate.

Product analytics remain absent for the closed alpha. Sentry is the approved
crash-reporting direction, but no SDK or DSN is added until staging exists and
the privacy configuration is implemented and tested: no default PII, replay,
screenshots, attachments, user notes, tokens, request/response bodies, or raw
server payloads, plus a bounded `beforeSend` scrubber. Production telemetry
stays disabled until the staging policy is accepted.
