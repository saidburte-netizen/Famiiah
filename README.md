# Fam

Property and rental management app: mobile app (owners/managers/staff/tenants),
admin web console (platform + org admins), and a Supabase-only backend.

- **Mobile**: `apps/mobile` — Expo (React Native) + TypeScript, Expo Router
- **Mobile (Flutter)**: `apps/mobile_flutter` — Flutter + Riverpod + go_router
- **Admin**: `apps/admin` — Next.js App Router + Tailwind
- **Shared**: `packages/shared` — types, schemas, money/version/permission helpers
- **Backend**: `supabase/` — Postgres migrations, RLS, RPCs, Edge Functions, tests

The two mobile clients are feature-equivalent; the Expo app is the reference and
the Flutter app mirrors its screens, RPC surface and error handling.

Currency is ETB; timezone `Africa/Addis_Ababa`; English first (i18n-ready).

## Prerequisites

- Node.js 22+, pnpm 9+
- Supabase CLI
- (Mobile) Expo CLI / EAS CLI

## 1. Create Supabase projects

Create three projects in the Supabase dashboard: `fam-local` (or use the CLI),
`fam-staging`, `fam-production`. Copy the project URL and **publishable (anon)**
key for each. Keep the **service role key** server-side only.

## 2. Install

```bash
pnpm install
```

## 3. Run the backend locally

```bash
supabase start          # starts Postgres, Auth, Storage, Realtime, Studio
supabase db reset       # applies migrations 0001..0017 and runs seed.sql
```

Set Vault secrets used by `pg_cron` (once per project):

```sql
select vault.create_secret('<service-role-key>', 'service_role_key');
select vault.create_secret('https://<ref>.supabase.co', 'project_url');
```

Regenerate DB types after schema changes:

```bash
pnpm gen:types
```

## 4. Environment

```bash
cp .env.example .env
# fill EXPO_PUBLIC_* and NEXT_PUBLIC_* for the apps
# server-only secrets go to Supabase Edge Function secrets / CI
```

## 5. Run the apps

```bash
pnpm dev                         # runs everything Turbo knows about
pnpm --filter @fam/mobile dev    # Expo
pnpm --filter @fam/admin dev     # Next.js admin
```

Flutter (needs the Flutter SDK; the Android project is generated on demand):

```bash
cd apps/mobile_flutter
flutter pub get
flutter run --dart-define=FAM_SUPABASE_URL=<url> \
            --dart-define=FAM_SUPABASE_ANON_KEY=<anon> \
            --dart-define=FAM_APP_ENV=dev
```

## 6. Tests

```bash
pnpm test          # unit tests (shared, apps)
pnpm test:db       # pgTAP (supabase test db)
pnpm db:lint       # supabase db lint
cd apps/mobile_flutter && flutter analyze && flutter test   # Flutter
```

## 7. Migrations

Add a new timestamped file under `supabase/migrations/`. Never edit an applied
migration. CI runs migrations on a fresh DB and lints the schema.

## 8. Build and release

- Mobile (Expo): `eas build` then `eas submit`; publish an `app_versions` row via
  `admin_publish_app_version` to control the update gate.
- Mobile (Flutter): `.github/workflows/flutter.yml` builds a signed release APK and
  AAB. Create an upload keystore and add the `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`
  repository secrets; without them the build falls back to debug signing.
- Admin: deploy the Next.js app and set the public env vars.
- Bump the version in `apps/mobile_flutter/pubspec.yaml` (`x.y.z+n`) and record it
  in `docs/VERSIONS.md` / `docs/CHANGELOG.md`.

## 9. First platform admin

There is no client path to become a platform admin. Promote the first one manually:

```sql
-- run as the service role / in the SQL editor
update profiles set is_platform_admin = true where id = '<user-uuid>';
```

Then enable MFA on that account; platform-admin RPCs require AAL2.

## Documentation

- `docs/ARCHITECTURE.md` — system design and layering rules
- `docs/SCHEMA.md` — tables, relationships, RLS summary
- `docs/API.md` — every RPC with args, returns, roles, errors
- `docs/ASSUMPTIONS.md` — decisions taken where the brief was unspecified
- `docs/RUNBOOK.md` — deploy, rollback, backup/restore, key rotation, incidents
- `docs/VERSIONS.md` — runtime and library versions
- `docs/CHANGELOG.md` — change history

## Security

RLS is enabled on every `public` table and denies by default. The service-role key
is never shipped to a client. Security-definer functions set `search_path` and
have execute revoked from `public`/`anon`. Storage buckets are private; downloads
use short-lived signed URLs. Online payments are off behind a feature flag.
Invitation tokens are stored hashed, are never selectable by client roles, and
`accept_invitation` only succeeds for the exact email or phone they were sent to.
Mobile session and invitation tokens live in the platform secure store
(`expo-secure-store` / `flutter_secure_storage`), not in plain preferences.
