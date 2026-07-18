import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const androidBuild = read("mobile/android/app/build.gradle.kts");
const androidManifest = read("mobile/android/app/src/main/AndroidManifest.xml");
const iosInfo = read("mobile/ios/Runner/Info.plist");
const iosProject = read("mobile/ios/Runner.xcodeproj/project.pbxproj");
const mainDart = read("mobile/lib/main.dart");
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

test("mobile identifiers are explicit and not Flutter placeholders", () => {
  assert.match(androidBuild, /applicationId = "com\.mayhem\./);
  assert.doesNotMatch(androidBuild, /com\.example/);
  assert.match(iosProject, /PRODUCT_BUNDLE_IDENTIFIER = com\.mayhem\./);
  assert.doesNotMatch(iosProject, /com\.example/);
});

test("version default and signing-artifact exclusions are explicit", () => {
  const version = pubspec.match(/^version:\s+(\d+)\.(\d+)\.(\d+)\+(\d+)$/m);
  assert.ok(version, "pubspec version must be semantic with an integer build");
  assert.ok(Number(version[4]) > 0, "default build number must be positive");
  for (const pattern of ["*.jks", "*.keystore", "*.p12", "*.mobileprovision"]) {
    assert.match(gitignore, new RegExp(`^${escapeRegex(pattern)}$`, "m"));
  }
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
