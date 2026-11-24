# MTV Rewind (Unofficial)

An unofficial iPhone and iPad app for [MTV Rewind](https://wantmymtv.org/) (wantmymtv.org), the 24/7 music video stream. It's the same site you'd open in Safari, as a real app on your home screen.

> **Unofficial fan project.** Not affiliated with, endorsed by or connected to wantmymtv.org, MTV or Paramount. The app shows the official site; all videos belong to their owners and play from YouTube. No ads, accounts or tracking.

## Download

**[Download MTV Rewind](https://github.com/hotwheelz3000/wantmymtv-app/releases/latest)**: open the link, then tap the `.ipa` file under **Assets** (named with the version, e.g. `WantMyMTV-1.0.ipa`; later builds of a version add a build number, e.g. `WantMyMTV-1.0-2.ipa`).

## How to install

The app isn't on the App Store, so you install it yourself (iOS 17 or later):

1. **Download the `.ipa`** from the link above.
2. **Install it** with [Sideloadly](https://sideloadly.io), [AltStore](https://altstore.io) or a signing service such as Signulous.
3. **Trust it:** Settings → General → VPN & Device Management → your Apple ID → **Trust**.

## What it does

The site's player, rebuilt as a native app: just the video on top, and the app's own controls underneath. The site's banners, popups, counters and chat are hidden.

- **Now Playing:** the song, artist and channel under the picture.
- **Remote:** previous, play/pause and next, plus Save, Share, Skip (for a video that won't play) and Full. Every press has a haptic click.
- **Channels:** every channel on the site, grouped like the site (curated collections, regional, directors, labels...), with a filter.
- **Time Machine:** pick a decade, then a year from 1975 to 2025, or "Surprise me".
- **Search:** 113,000+ videos by artist or song.
- **Saved:** the site's "Your Saved Videos" list: play one, play all, swipe to remove.
- **Gestures:** swipe the picture left or right for next or previous, tap to pause, double-tap for full screen.
- **Landscape:** turn the phone for a full-screen TV; tap for a floating remote.
- **Picture in Picture** when you leave the app mid-video, **lock screen** controls, and sound that keeps going with the screen locked and the silent switch on.
- **Screen stays on** while a video plays.
- **No connection?** A "No connection" screen with **Retry**, and it reconnects by itself once you're online.

The app drives the site's own player and lists, so new channels on the site show up in the app by themselves.

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
