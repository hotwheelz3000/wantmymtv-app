# I Want My MTV (Unofficial)

An unofficial iPhone and iPad app for [I Want My MTV](https://wantmymtv.org/), the 24/7 music video stream. It's the same site you'd open in Safari, as a real app on your home screen.

> **Unofficial fan project.** Not affiliated with, endorsed by or connected to wantmymtv.org, MTV or Paramount. The app shows the official site; all videos belong to their owners and play from YouTube. No ads, accounts or tracking.

## Download

**[Download I Want My MTV](https://github.com/hotwheelz3000/wantmymtv-app/releases/latest)**: open the link, then tap the `.ipa` file under **Assets** (named with the version, e.g. `WantMyMTV-1.0.ipa`; later builds of a version add a build number, e.g. `WantMyMTV-1.0-2.ipa`).

## How to install

The app isn't on the App Store, so you install it yourself (iOS 17 or later):

1. **Download the `.ipa`** from the link above.
2. **Install it** with [Sideloadly](https://sideloadly.io), [AltStore](https://altstore.io) or a signing service such as Signulous.
3. **Trust it:** Settings → General → VPN & Device Management → your Apple ID → **Trust**.

## What it does

- **Opens straight to the player**, full screen with no Safari bars. A loading screen with the icon shows until the player is ready.
- **Feels like an app:** no text selection, long-press menus, link previews or pinch zoom.
- **Videos play in the page**, with fullscreen, rotation to landscape, AirPlay and Picture in Picture.
- **Leave the app mid-video** and it keeps playing in Picture in Picture (when iOS allows it for that video).
- **Screen stays on** while a video plays, then sleeps normally once it stops.
- **Lock screen and Control Center** show what's playing, with play/pause. Sound keeps going with the screen locked and the silent switch on.
- **Links that leave the site** (YouTube, IMVDb) open in Safari or their app.
- **No connection?** A "No connection" screen with **Retry**, and it reconnects by itself once you're online.

## Building

Every push to `main` builds an unsigned IPA with [xtool](https://xtool.sh) on GitHub Actions and publishes it as the `latest` release. The icon is an original design drawn by `scripts/make-app-icon.py`.

## Updates

- **Update feed:** each release also has `source.json`, an AltStore-format source. Add this URL in a sideloading app that supports sources to see new builds as updates:

```
https://github.com/hotwheelz3000/wantmymtv-app/releases/download/latest/source.json
```

## Checks before each build

- **Lint:** SwiftLint and swift-format run before the build.
- **JavaScript check:** `scripts/check-js.py` runs `node --check` on every script held in a Swift multi-line string. A syntax error stops the build and points at the Swift file and line.
- **Dependabot:** `.github/dependabot.yml` opens a pull request each week when the build's GitHub Actions have updates. Merge it to update.
