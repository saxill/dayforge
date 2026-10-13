# Dayforge

Dayforge is a small personal operating system for daily rituals: habits, focus time, spending, brain training, a reading shelf, and private motivation pairing.

This repository contains:

- A native SwiftUI iOS app in `Dayforge/`, `Shared/`, and `DayforgeWidgets/`.
- A native Jetpack Compose Android app in `android/` with the same core flows.
- The Cloudflare Worker sync and pairing API in `worker/`.
- Installable build artifacts and verification screenshots in `dist/` when a release build has been produced.

## Feature map

| Area | iOS | Android |
| --- | --- | --- |
| Today dashboard | Pulse, habits, alarm, spending, brief, brain training | Pulse, habits, alarm, spending, brief, brain training |
| Focus | Configurable timer, stats, Live Activity | Configurable timer, stats, ongoing timer state |
| Discover | AI Brief, Manga Shelf, reader/source links | AI Brief, Manga Shelf, progress/source links |
| Profile | Theme, Today cards, auth, sync, team pairing | Theme, Today cards, auth, sync, team pairing |
| Widgets | WidgetKit | Android App Widget |

The Android client is a platform-native implementation rather than a source translation. Android substitutes an ongoing timer state for iOS Live Activities and uses Android Sharesheet/notifications instead of Apple-specific integrations.

## Build the iOS app

Requirements: Xcode 17 or later and XcodeGen.

```bash
xcodegen generate
xcodebuild -project Dayforge.xcodeproj \
  -scheme Dayforge \
  -destination 'generic/platform=iOS' \
  -configuration Debug \
  build
```

Sign with your own Apple Developer Team. The checked-in bundle identifiers and app-group identifiers are development identifiers from the original workspace and may need to be changed for your account.

The original raw MangaPin backup is intentionally not published because it contains personal reading history and embedded third-party cover data. Import your own backup in the app, or add a rights-cleared fixture locally.

## Build the Android app

Requirements: Android SDK API 35+, Build Tools 35+, JDK 17, and Gradle 8.11+.

```bash
cd android
JAVA_HOME=/path/to/jdk-17 gradle assembleDebug
```

The debug APK is written to `android/app/build/outputs/apk/debug/app-debug.apk`. The app can run offline using local sample data. Sign-in, sync, and team pairing use the same Worker API as iOS.

## Run the Worker tests

```bash
node worker/test.mjs
```

To deploy your own Worker, copy `worker/wrangler.toml.example` to `worker/wrangler.toml`, create a KV namespace, update the binding ID, and run `npx wrangler deploy`.

## Privacy and deployment

The pairing API intentionally shares only aggregate motivation metrics and daily history. Habit names/IDs, expenses, alarms, manga files, and notes are not part of the partner payload. Before production use, deploy the Worker and KV namespace under your own Cloudflare account and review authentication rate limits, CORS, retention, and account-deletion cleanup.

## License

This repository is released under the MIT License. See `LICENSE`.
