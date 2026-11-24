# iOS app template (xtool)

A starting point for SwiftUI iOS apps built with [xtool](https://xtool.sh): SwiftPM instead of an Xcode project, and a GitHub Actions workflow that builds an unsigned `.ipa` on every push to `main` and publishes it as the `latest` release.

What's here:

- `Package.swift`, `xtool.yml`, `Sources/MyApp/`: a placeholder "Hello, world!" SwiftUI app, so the template builds as-is.
- `MyApp-Info.plist`: the app's shown name and version.
- `rename-app.sh`: renames the placeholder to your app.
- `.github/workflows/build-ipa.yml`: lints, builds the `.ipa` on macOS, and publishes it.
- `Sources/MyApp/swiftgen.yml`, `Sources/MyApp/Resources/`: typed Swift for the app's text (below).
- `.swiftlint.yml`, `.swift-format`: lint and style rules used by the workflow.
- `RELEASE_NOTES.md`: shown on the release page and in `source.json`.
- `.claude/skills/using-xtool/`: a Claude Code skill with xtool reference notes.

## Start a new app

1. On GitHub, click **Use this template → Create a new repository** (or clone this repo and push it to a new one).
2. Clone your new repo and rename the app (below).
3. Commit and push to `main`. The workflow builds your IPA.

## Rename the app

```bash
./rename-app.sh CoffeeLog com.yourname.CoffeeLog
```

The first argument is the app name. It becomes a Swift module and type name, so use letters, digits and `_` only (no spaces or hyphens). The second is the bundle ID.

The script updates the names in `Package.swift`, sets `product:`, `bundleID:` and `infoPath:` in `xtool.yml`, renames `Sources/MyApp/` and `MyAppApp.swift`, renames the `MyAppApp` struct, and renames `MyApp-Info.plist` (and the shown name inside it). To show a name with spaces on the home screen, edit `CFBundleDisplayName` in the plist afterwards.

## Versions and build numbers

- **Version:** `CFBundleShortVersionString` in `<AppName>-Info.plist`. Change it by hand for a new version.
- **Build number:** set by the workflow. It counts the builds of the current version: the first build of a new version is 1, then 2, 3... It goes into `CFBundleVersion` and the app's `BuildInfo.label` ("Version 1.0 (build 3)").
- **File name:** `MyApp-1.0.ipa` for the first build of a version, then `MyApp-1.0-2.ipa`, `MyApp-1.0-3.ipa`.

## Download the IPA

Every push to `main` replaces the `latest` release. The direct link is:

```
https://github.com/<owner>/<repo>/releases/download/latest/<AppName>-<version>-<build>.ipa
```

The release notes and the end of the workflow log show the exact link. Builds run by hand (**Actions → Build IPA → Run workflow**) and builds of other branches don't publish a release; download those from the run page under **Artifacts**.

The IPA is **unsigned**. Sign it when installing, for example with Signulous, Sideloadly or AltStore, or `xtool install` after `xtool auth login`.

## Source feed (source.json)

Each release also has `source.json`, an AltStore-format source listing the latest build:

```
https://github.com/<owner>/<repo>/releases/download/latest/source.json
```

Add that URL in a sideloading app that supports sources, and it shows new builds as updates. It only works for public repos.

## Lint

The workflow runs SwiftLint (rules in `.swiftlint.yml`) and swift-format before building. SwiftLint errors (`force_try`, `force_cast`) stop the run; warnings and style notes show up on the run page.

## App text (SwiftGen)

Put the app's text in `Sources/<AppName>/Resources/en.lproj/Localizable.strings`:

```
"save_button" = "Save";
```

Build, and use it as `Text(L10n.saveButton)`. A typo in a key is a compile error instead of blank text. Settings are in `Sources/<AppName>/swiftgen.yml`.

## Build speed

The workflow caches Homebrew downloads and SwiftPM's `.build` folder, so later builds only recompile what changed. A new Xcode version on GitHub's runners starts a fresh cache.

## Build locally

With xtool installed ([macOS](https://xtool.sh/documentation/xtooldocs/installation-macos), [Linux/Windows](https://xtool.sh/documentation/xtooldocs/installation-linux)):

```bash
xtool dev build --ipa   # unsigned IPA at xtool/<AppName>.ipa
xtool dev               # build, sign and run on a connected device
```

## Checks before each build

- **JavaScript check:** `scripts/check-js.py` runs `node --check` on every script held in a Swift multi-line string. A syntax error stops the build and points at the Swift file and line.
- **Dependabot:** `.github/dependabot.yml` opens a pull request each week when the build's GitHub Actions have updates. Merge it to update.
