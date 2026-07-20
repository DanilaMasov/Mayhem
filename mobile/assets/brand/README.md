# Mayhem Launcher Assets

`launcher_icon.svg` and `launcher_icon_staging.svg` are inspectable master
artwork. Platform PNGs and the RGB masters are generated without third-party
packages by the checked-in Flutter tool:

```sh
cd mobile
flutter test --no-pub --no-test-assets tool/generate_launcher_icons_test.dart
```

The command rewrites only launcher artwork and the staging iOS
`Contents.json`. Run the root repository contracts after regeneration; they
validate every platform size, RGB color type, adaptive resource, and
production/staging separation.
