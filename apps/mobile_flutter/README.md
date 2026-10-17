# Fam — Flutter client

A Flutter port of the Fam rent-control app, mirroring the Expo/React Native
client (`apps/mobile`): same backend (Supabase), same design tokens
(`lib/theme/tokens.dart` mirrors `apps/mobile/theme/tokens.ts`), same screens
and the same SQL RPCs.

## Configuration

The build reads compile-time values (never commit them):

```
--dart-define=FAM_SUPABASE_URL=https://<project>.supabase.co
--dart-define=FAM_SUPABASE_ANON_KEY=<anon/publishable key>
--dart-define=FAM_APP_ENV=production   # optional, defaults to local
```

Without the first two the app shows a "configuration missing" screen instead
of crashing.

## First-time setup

This folder contains only `lib/` and `test/`. Generate the native platform
folders once, then run:

```
# Android (also sets the Play application id — see below)
bash tool/setup_android.sh

# iOS (macOS only)
flutter create --platforms=ios --org com.fami .

flutter pub get
flutter analyze
flutter test
```

> The repo intentionally ships **no** `android/` folder, because it would
> contain a binary `gradle-wrapper.jar`. `tool/setup_android.sh` runs
> `flutter create` into a temp dir, copies `android/` in, and rewrites the
> application id to the Play package `com.fami.myapp`.

## Android / Play Store

- Application id: **`com.fami.myapp`** (also the Play Console package name).
- Launcher label: `Fam`.
- `minSdk = 24` (required by `flutter_secure_storage`) and
  `android:allowBackup="false"` (an encrypted store must not be restored without
  its Keystore key), both applied by `tool/setup_android.sh`.
- `--dart-define`s for the Supabase URL/key are `FAM_SUPABASE_URL` and
  `FAM_SUPABASE_ANON_KEY`.

CI (`.github/workflows/flutter.yml`) runs `flutter analyze`, `flutter test`
and then a real Android release build (APK + AAB) with Java 17, using the
application id above. The APK/AAB are uploaded as the `fam-android-release`
artifact.

### Release signing

By default the release APK/AAB are signed with Flutter's debug key so the
build always compiles — **Play will reject those**. To produce a Play-ready
bundle, add an upload keystore to the repository secrets:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
| `ANDROID_KEY_PASSWORD` | key password |

When they are present, `tool/setup_android.sh` writes the keystore to
`android/app/upload-keystore.jks`, creates `android/key.properties` and runs
`tool/patch_android_signing.py` to point `buildTypes.release` at it. With no
secrets the build stays on debug signing, so CI keeps working.

To build a signed bundle locally, export the four variables above and run
`bash tool/setup_android.sh && flutter build appbundle --release`. Create the
keystore once with:

```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

## Deep links

The invite flow uses `fam://invite?token=<rawToken>` — the raw token is SHA-256
hashed in `lib/screens/auth/invite.dart` before it reaches `accept_invitation`.

- **Android** is wired automatically: `tool/setup_android.sh` runs
  `tool/patch_android_manifest.py`, which adds the `VIEW`/`BROWSABLE` intent
  filter for the `fam` scheme to the generated manifest.
- **iOS** is manual: add the `fam` URL scheme to `ios/Runner/Info.plist`
  (`CFBundleURLTypes`).
- Android hands the app the *full* URI, so the first segment (`invite`) is the
  URI **host**, not a path. `lib/routing/deep_links.dart` rewrites
  `fam://invite?token=…` to `/invite?token=…` before the router's auth guard
  runs; `test/deep_links_test.dart` locks that in.

Known gap: the password-reset link (`fam://reset-password`, from
`resetPasswordForEmail`) opens the app on both clients, but neither has a screen
to set the new password yet, so it falls through to sign-in.

## Structure

- `lib/theme` — design tokens + Material theme (light brand palette).
- `lib/core` — Supabase bootstrap, error mapping, version gate, money, invite store.
- `lib/state` — Riverpod providers (auth session, active org).
- `lib/features/api.dart` — typed wrappers over every RPC/table query.
- `lib/routing` — go_router with the same auth/route guard as the RN app.
- `lib/screens` — auth + app sections:
  - `auth/` — login, sign-up, forgot password, create organization, invite.
  - `home/` — dashboard.
  - `properties/` — list, new, detail (with add-unit sheet).
  - `tenants/` — list, new (with lease), detail (renew/terminate).
  - `rent/` — monthly charge list, record payment, send reminder.
  - `payments/` — list (void), new.
  - `stock/` — items (adjust/rent), rentals (return).
  - `reports/`, `notifications/`, `settings/`, `admin/`.

## Error handling

`lib/core/errors/user_message.dart` mirrors `apps/mobile/lib/errors.ts`: every
Supabase/Postgres error is mapped to a localized, non-leaky string. Raw
`err.message` is never shown to the user. See `test/errors_test.dart`.
