import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import test from "node:test";

const root = new URL("../", import.meta.url);
const androidRes = "mobile/android/app/src";
const iosAssets = "mobile/ios/Runner/Assets.xcassets";
const iosProject = text("mobile/ios/Runner.xcodeproj/project.pbxproj");

test("launcher masters are Mayhem-owned and staging is visibly distinct", () => {
  const productionSvg = text("mobile/assets/brand/launcher_icon.svg");
  const stagingSvg = text("mobile/assets/brand/launcher_icon_staging.svg");

  for (const source of [productionSvg, stagingSvg]) {
    assert.match(source, /#07090c/);
    assert.match(source, /#f4f6f8/);
    assert.match(source, /#ff6a45/);
    assert.doesNotMatch(source, /flutter|<text/i);
  }
  assert.doesNotMatch(productionSvg, /#ffc978/);
  assert.match(stagingSvg, /#ffc978/);

  const production = png("mobile/assets/brand/launcher_icon_1024.png");
  const staging = png("mobile/assets/brand/launcher_icon_staging_1024.png");
  assert.deepEqual(production, { width: 1024, height: 1024, colorType: 2 });
  assert.deepEqual(staging, { width: 1024, height: 1024, colorType: 2 });
  assert.notEqual(
    hash(new URL("mobile/assets/brand/launcher_icon_1024.png", root)),
    hash(new URL("mobile/assets/brand/launcher_icon_staging_1024.png", root))
  );
});

test("Android supplies production, staging, adaptive, and monochrome icons", () => {
  const densities = new Map([
    ["mipmap-mdpi", 48],
    ["mipmap-hdpi", 72],
    ["mipmap-xhdpi", 96],
    ["mipmap-xxhdpi", 144],
    ["mipmap-xxxhdpi", 192]
  ]);

  for (const [density, size] of densities) {
    const productionPath = `${androidRes}/main/res/${density}/ic_launcher.png`;
    const stagingPath = `${androidRes}/staging/res/${density}/ic_launcher.png`;
    assert.deepEqual(png(productionPath), {
      width: size,
      height: size,
      colorType: 2
    });
    assert.deepEqual(png(stagingPath), {
      width: size,
      height: size,
      colorType: 2
    });
    assert.notEqual(hash(new URL(productionPath, root)), hash(new URL(stagingPath, root)));
  }

  const adaptive = text(
    `${androidRes}/main/res/mipmap-anydpi-v26/ic_launcher.xml`
  );
  assert.match(adaptive, /<adaptive-icon/);
  assert.match(adaptive, /@color\/ic_launcher_background/);
  assert.match(adaptive, /@drawable\/ic_launcher_foreground/);
  assert.match(adaptive, /@drawable\/ic_launcher_monochrome/);
  assert.match(
    text(`${androidRes}/staging/res/drawable/ic_launcher_foreground.xml`),
    /#FFC978/
  );
  const manifest = text(`${androidRes}/main/AndroidManifest.xml`);
  assert.match(manifest, /android:icon="@mipmap\/ic_launcher"/);
  assert.match(manifest, /android:roundIcon="@mipmap\/ic_launcher"/);
});

test("iOS uses complete RGB icon sets and isolates staging artwork", () => {
  verifyIosSet("AppIcon.appiconset");
  verifyIosSet("AppIconStaging.appiconset");

  const productionAssignments = [
    ...iosProject.matchAll(
      /ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;/g
    )
  ];
  const stagingAssignments = [
    ...iosProject.matchAll(
      /ASSETCATALOG_COMPILER_APPICON_NAME = AppIconStaging;/g
    )
  ];
  assert.equal(productionAssignments.length, 3);
  assert.equal(stagingAssignments.length, 3);

  const production = new URL(
    `${iosAssets}/AppIcon.appiconset/Icon-App-1024x1024@1x.png`,
    root
  );
  const staging = new URL(
    `${iosAssets}/AppIconStaging.appiconset/Icon-App-1024x1024@1x.png`,
    root
  );
  assert.notEqual(hash(production), hash(staging));
});

function verifyIosSet(directory) {
  const base = `${iosAssets}/${directory}`;
  const contents = JSON.parse(text(`${base}/Contents.json`));
  const images = contents.images.filter((image) => image.filename);
  assert.equal(images.length, contents.images.length);
  assert.ok(images.length >= 10);
  for (const image of images) {
    const points = Number(image.size.split("x", 1)[0]);
    const scale = Number(image.scale.replace("x", ""));
    const size = Math.round(points * scale);
    const file = png(`${base}/${image.filename}`);
    assert.equal(file.width, size);
    assert.equal(file.height, size);
    assert.equal(file.colorType, 2, `${directory}/${image.filename} has alpha`);
  }
}

function png(path) {
  const file = new URL(path, root);
  const bytes = readFileSync(file);
  assert.deepEqual(
    [...bytes.subarray(0, 8)],
    [137, 80, 78, 71, 13, 10, 26, 10],
    `${path} is not a PNG`
  );
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    colorType: bytes[25]
  };
}

function hash(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

function text(path) {
  return readFileSync(new URL(path, root), "utf8");
}
