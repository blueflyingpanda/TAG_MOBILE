# TAG Mobile

Cross-platform (iOS + Android) React Native port of the [TAG web app](../TAG), built with Expo.

## Stack

- **Expo SDK 56** / React Native 0.85 (TypeScript)
- **NativeWind 4** (Tailwind class styling) + theme palette mirroring the web CSS variables (light/dark)
- **react-native-reanimated 4** + **react-native-gesture-handler** — swipeable word-card stack, counters, transitions
- **AsyncStorage** — token, user, locale, theme, in-progress game state (replaces web localStorage)
- **expo-web-browser + deep link (`tag://auth`)** — Google OAuth via the existing TAG_API flow

## Architecture

`src/` mirrors the web app:

- `types.ts`, `i18n/translations.ts`, `utils/game.ts`, `utils/games.ts`, `utils/themes.ts` — identical to web
- `utils/config.ts` — API base (override with `EXPO_PUBLIC_API_BASE`)
- `utils/oauth.ts` — token handling + native login flow
- `utils/storage.ts` — AsyncStorage-backed persistence
- `contexts/` — locale (EN/RU) + light/dark theme palette
- `components/`, `ui/` — RN ports of every web screen

## Auth flow (mobile)

1. App opens an in-app browser at `GET /auth/login?redirect_uri=tag://auth`
2. TAG_API stores the redirect with the OAuth `state`, sends the user through Google
3. `GET /auth/token` redirects to `tag://auth?code=<one-time-code>` (instead of the web FE URL)
4. App exchanges the code at `POST /auth/exchange` for the JWT

Requires TAG_API with `redirect_uri` support on `/auth/login` (setting `MOBILE_REDIRECT_URI`, default `tag://auth`) — added alongside this app.

## Development

```bash
npm install
npx expo start          # Expo Go / dev client
```

Note: this project uses native modules (reanimated, gesture-handler, etc.) compatible with Expo Go for SDK 56. For full-fidelity dev builds use `npx expo run:android` / `npx expo run:ios`.

Against a local backend (Android emulator): `EXPO_PUBLIC_API_BASE=http://10.0.2.2:8000 npx expo start`

## Building

### Android (local)

```bash
export ANDROID_HOME=$HOME/Library/Android/sdk
npx expo prebuild --platform android
cd android && ./gradlew assembleRelease
# APK: android/app/build/outputs/apk/release/app-release.apk
```

The release build uses the debug signing config by default — fine for sideloading/testing. For Play Store, generate an upload keystore and configure `android/app/build.gradle` signing, or use EAS (`eas build -p android`).

### iOS (local — requires Xcode)

1. Install Xcode from the App Store, then:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   brew install cocoapods
   ```
2. Build:
   ```bash
   npx expo prebuild --platform ios
   npx pod-install
   npx expo run:ios                       # simulator
   npx expo run:ios --device              # device (needs Apple Developer signing in Xcode)
   ```
   For an archive/.ipa, open `ios/TAG.xcworkspace` in Xcode → Product → Archive (set a development team first), or use EAS (`eas build -p ios`).
