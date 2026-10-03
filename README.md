# T.A.G. Mobile

Native Android/iOS client for **T.A.G. — Themed Alias Game**, built with Flutter.
Talks to the same backend as the web app ([TAG_API](../TAG_API)).

## Stack

- Flutter (Dart 3), Material 3 with the T.A.G. brand theme
- Riverpod (state), go_router (navigation), dio (HTTP)
- Native Google Sign-In (`google_sign_in`) → `POST /auth/google`
- Token in `flutter_secure_storage`; game state and preferences in `shared_preferences`

## Run

```bash
flutter pub get
flutter run                      # debug on a connected device/emulator
flutter run --release            # use this to judge performance/feel
```

Point at a local API with `--dart-define=API_BASE=http://10.0.2.2:8000` (Android emulator → host).

## Build

```bash
flutter build apk --release --split-per-abi   # sideload: build/app/outputs/flutter-apk/
flutter build appbundle --release             # Google Play: build/app/outputs/bundle/release/app-release.aab
```

## Release

Release builds are signed with the upload key, configured in `android/key.properties`
(gitignored):

```properties
storePassword=…
keyPassword=…
keyAlias=upload
storeFile=/Users/<you>/keys/tag-upload-keystore.jks
```

Without that file a release build stops with an error instead of signing with the debug key.
Keep the keystore and its password backed up. Play Console steps, store listing text and
Data safety answers are in [store/PLAY_RELEASE.md](store/PLAY_RELEASE.md).

## Translations

`lib/i18n/translations.dart` is **generated** from the web app's
`../TAG/src/i18n/translations.ts`. Edit the web file, then run:

```bash
node tool/gen_translations.mjs
```

## Tests

```bash
flutter analyze
flutter test
```

## Layout

```
lib/
  core/      config, theme (brand tokens), storage
  data/      API client, models, auth
  game/      pure game rules (scoring, win condition, cheat detection)
  state/     Riverpod providers
  features/  screens (themes, game, history, rules, login)
  ui/        shared widgets
  router.dart
```
