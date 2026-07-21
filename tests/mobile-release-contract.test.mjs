import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const androidBuild = read("mobile/android/app/build.gradle.kts");
const androidManifest = read("mobile/android/app/src/main/AndroidManifest.xml");
const androidActivity = read(
  "mobile/android/app/src/main/kotlin/com/danilamasov/mayhem/MainActivity.kt"
);
const iosInfo = read("mobile/ios/Runner/Info.plist");
const iosProject = read("mobile/ios/Runner.xcodeproj/project.pbxproj");
const iosProductionScheme = read(
  "mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/production.xcscheme"
);
const iosStagingScheme = read(
  "mobile/ios/Runner.xcodeproj/xcshareddata/xcschemes/staging.xcscheme"
);
const mainDart = read("mobile/lib/main.dart");
const crashReporting = read(
  "mobile/lib/infrastructure/telemetry/staging_crash_reporting.dart"
);
const pubspec = read("mobile/pubspec.yaml");
const gitignore = read(".gitignore");

test("Android release never falls back to debug signing", () => {
  assert.doesNotMatch(androidBuild, /signingConfigs\.getByName\("debug"\)/);
  for (const variable of [
    "MAYHEM_ANDROID_KEYSTORE_PATH",
    "MAYHEM_ANDROID_KEYSTORE_PASSWORD",
    "MAYHEM_ANDROID_KEY_ALIAS",
    "MAYHEM_ANDROID_KEY_PASSWORD"
  ]) {
    assert.match(androidBuild, new RegExp(variable));
  }
  assert.match(androidBuild, /configuredReleaseSigningValues != 0/);
  assert.match(androidBuild, /signingConfigs\.getByName\("release"\)/);
});

test("platform orientation declarations match portrait-only runtime", () => {
  assert.match(androidManifest, /android:screenOrientation="portrait"/);
  assert.match(
    mainDart,
    /SystemChrome\.setPreferredOrientations\(\[DeviceOrientation\.portraitUp\]\)/
  );
  assert.deepEqual(plistArray(iosInfo, "UISupportedInterfaceOrientations"), [
    "UIInterfaceOrientationPortrait"
  ]);
  assert.deepEqual(plistArray(iosInfo, "UISupportedInterfaceOrientations~ipad"), [
    "UIInterfaceOrientationPortrait"
  ]);
});

test("production and staging identities are exact and isolated", () => {
  assert.match(androidBuild, /applicationId = "com\.danilamasov\.mayhem"/);
  assert.match(androidBuild, /create\("production"\)/);
  assert.match(androidBuild, /create\("staging"\)/);
  assert.match(androidBuild, /applicationIdSuffix = "\.staging"/);
  assert.match(androidActivity, /^package com\.danilamasov\.mayhem$/m);
  assert.match(androidActivity, /"mayhem\/timezone"/);
  assert.doesNotMatch(androidBuild, /com\.example/);
  assert.match(
    iosProject,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.danilamasov\.mayhem;/
  );
  assert.match(
    iosProject,
    /PRODUCT_BUNDLE_IDENTIFIER = com\.danilamasov\.mayhem\.staging;/
  );
  assert.doesNotMatch(iosProject, /com\.example/);
  for (const mode of ["Debug", "Profile", "Release"]) {
    assert.match(
      iosProductionScheme,
      new RegExp(`buildConfiguration="${mode}-production"`)
    );
    assert.match(
      iosStagingScheme,
      new RegExp(`buildConfiguration="${mode}-staging"`)
    );
    assert.match(iosProject, new RegExp(`name = "${mode}-production";`));
    assert.match(iosProject, new RegExp(`name = "${mode}-staging";`));
  }
  assert.match(mainDart, /flavor: appFlavor \?\? ''/);
});

test("supported OS floors are iOS 16 and Android API 29", () => {
  assert.match(androidBuild, /minSdk = 29/);
  assert.doesNotMatch(androidBuild, /minSdk = (?:2[0-8]|1\d|\d)\b/);
  const deploymentTargets = [
    ...iosProject.matchAll(/IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);/g)
  ].map((match) => match[1]);
  assert.ok(deploymentTargets.length > 0);
  assert.deepEqual(new Set(deploymentTargets), new Set(["16.0"]));
});

test("version default and signing-artifact exclusions are explicit", () => {
  const version = pubspec.match(/^version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)$/m);
  assert.ok(version, "pubspec version must be semantic with an integer build");
  assert.ok(Number(version[4]) > 0, "default build number must be positive");
  for (const pattern of ["*.jks", "*.keystore", "*.p12", "*.mobileprovision"]) {
    assert.match(gitignore, new RegExp(`^${escapeRegex(pattern)}$`, "m"));
  }
});

test("crash reporting is staging-only and privacy locked", () => {
  assert.match(pubspec, /^\s+sentry_flutter: \^9\.24\.0$/m);
  assert.match(mainDart, /String\.fromEnvironment\('MAYHEM_SENTRY_DSN'\)/);
  assert.match(mainDart, /StagingCrashReportingConfiguration\.resolve/);
  assert.match(
    crashReporting,
    /environment != MayhemRuntimeEnvironment\.staging/
  );
  assert.match(crashReporting, /if \(!releaseMode\)/);
  for (const privacyLock of [
    "sendDefaultPii = false",
    "maxBreadcrumbs = 0",
    "captureFailedRequests = false",
    "captureNativeFailedRequests = false",
    "enableLogs = false",
    "enableMetrics = false",
    "attachScreenshot = false",
    "attachViewHierarchy = false",
    "beforeBreadcrumb = ((_, _) => null)"
  ]) {
    assert.match(crashReporting, new RegExp(escapeRegex(privacyLock)));
  }
  assert.doesNotMatch(
    `${mainDart}\n${crashReporting}`,
    /https:\/\/[^\s@]+@[^\s/]+\/\d+/
  );
});

function read(path) {
  return readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
}

function plistArray(source, key) {
  const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = source.match(
    new RegExp(`<key>${escaped}</key>\\s*<array>([\\s\\S]*?)</array>`)
  );
  assert.ok(match, `Missing plist array ${key}`);
  return [...match[1].matchAll(/<string>([^<]+)<\/string>/g)].map(
    (entry) => entry[1]
  );
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
