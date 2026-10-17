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
flutter create --platforms=android,ios --org com.fam .
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=FAM_SUPABASE_URL=… \
  --dart-define=FAM_SUPABASE_ANON_KEY=…
```

> `flutter create` only adds the missing `android/` and `ios/` folders; it does
> not overwrite `lib/` or `test/`.

## Deep links

The invite flow expects the `fam://invite?token=<rawToken>` scheme. After
`flutter create`, add the intent filter in `android/app/src/main/AndroidManifest.xml`
and the URL scheme in `ios/Runner/Info.plist` (the RAW token is SHA-256 hashed
in `lib/screens/auth/invite.dart` before being sent to `accept_invitation`).

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
