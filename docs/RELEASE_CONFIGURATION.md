# Mayhem Release Configuration

This document defines the checked-in release configuration policy. It does not
claim that signing accounts, final store identifiers, launcher artwork, or a
production backend have been approved.

## Environments

The application accepts exactly three `MAYHEM_ENVIRONMENT` values:

- `development`: the debug default; loopback HTTP is allowed only here;
- `staging`: a release-capable non-production target for internal acceptance;
- `production`: the release default; Supabase must use HTTPS.

Release builds reject `development`. Unknown or misspelled values fail at
startup instead of creating a new secure-storage namespace or sending an
unsupported backend environment.

Supabase values are supplied with Dart defines and must not be committed:

```sh
flutter build appbundle --release --no-pub \
  --dart-define=MAYHEM_ENVIRONMENT=staging \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=STAGING_ANON_KEY \
  --build-name=1.0.0 \
  --build-number=1
```

The client may receive only the publishable anonymous key. A service-role key,
database password, access token, or refresh token must never be passed through
Dart defines, source files, build logs, or store metadata.

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

- final Android application ID and iOS bundle ID;
- Android and Apple signing ownership;
- final launcher icon and store artwork;
- support email or HTTPS support URL;
- privacy/store metadata and production Supabase target.

Crash reporting and analytics remain absent. They require a separate approved
event, retention, consent, and privacy specification before any SDK is added.
