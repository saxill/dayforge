# Dayforge verification artifacts

## Installable builds

- `Dayforge-ios-debug.ipa` — packaged from the signed physical-device Debug build produced by Xcode.
- `Dayforge-android-debug.apk` — installable debug APK produced with Android Gradle Plugin 8.7.3.
- `Dayforge-android-release-unsigned.apk` — minified-disabled release variant; it is unsigned and must be signed with the installer's keystore before distribution.

## Screenshots

The screenshots were captured from the working iOS build on an iPhone 17 Pro simulator running iOS 26.3:

- `ios-today.png` — Today dashboard, Pulse, rituals, alarm, spending, brain-training and brief cards.
- `ios-focus.png` — Focus timer, controls and statistics.
- `ios-discover-ai.png` — Discover AI Brief list.
- `ios-article.png` — Open AI Brief reading view.
- `ios-profile.png` — Profile, account, name and theme settings.

Android compilation passed in this environment, but there was no Android emulator or connected Android device available for a runtime screenshot. The Android source is in `android/` and can be exercised with an Android API 35+ emulator or device.
