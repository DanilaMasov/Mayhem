# Mayhem Android Preview APK

The manual, main-only `Android Preview APK` GitHub Actions workflow builds an
installable Android package from the current `main` branch without backend,
telemetry, support-contact, store, or release-signing credentials.

## Build contract

- target: Android staging application `com.danilamasov.mayhem.staging`;
- mode: Flutter debug, signed by the disposable GitHub runner debug key;
- product surface: local vNext Feed enabled through the debug-only
  `MAYHEM_NEW_FEED_ENABLED` override;
- remote capabilities: disabled unless separately configured in source policy;
- Sentry: disabled because this is not a release build;
- artifact: `Mayhem-staging-preview.apk` plus its SHA-256 file;
- retention: seven days in GitHub Actions.

The workflow verifies the APK signature with Android `apksigner` before upload.
It cannot close release signing, store upload, production configuration, or R4
physical-device acceptance.

## Run and download

1. Open GitHub Actions and select `Android Preview APK`.
2. Select `Run workflow` on `main`.
3. Open the completed run and download the `mayhem-staging-preview-*` artifact.
4. Extract the artifact and verify it from that directory with
   `shasum -a 256 -c Mayhem-staging-preview.apk.sha256` (macOS) or
   `sha256sum --check Mayhem-staging-preview.apk.sha256` (Linux).
5. Transfer `Mayhem-staging-preview.apk` to an Android device.
6. Allow installation from the browser or file manager when Android asks, then
   open `MAYHEM STAGING`.

The preview is local-first and can be explored without an account or backend.
Android may require the previous preview to be uninstalled when a later run was
signed by a different disposable runner key. The staging application ID keeps
it isolated from any future production installation.

An iPhone `.ipa` cannot be produced by this workflow: iOS installation needs an
Apple team, certificate, provisioning profile, registered device or approved
distribution channel.
