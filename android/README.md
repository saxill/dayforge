# Dayforge Android

This is a native Jetpack Compose implementation of Dayforge's core iOS flows. It uses the same email/password Worker API and pairing payloads, while using Android-native substitutes for iOS-only integrations:

- Ongoing in-app focus state instead of ActivityKit Live Activities.
- Material icons and Android Sharesheet instead of SF Symbols and `UIActivityViewController`.
- SharedPreferences for the local prototype store; production releases should move the token to an Android Keystore-backed encrypted store.
- Android's notification/widget APIs can be added without changing the core screen model.

Build with JDK 17 and an installed Android SDK:

```bash
JAVA_HOME=/path/to/jdk-17 \
ANDROID_HOME=/path/to/android-sdk \
gradle --offline assembleDebug
```

The debug APK is emitted at `app/build/outputs/apk/debug/app-debug.apk`.
