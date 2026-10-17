# Architecture

Fam is a property and rental management product built on Supabase only — no
separate API server. Three clients (Expo mobile, Flutter mobile, Next.js admin)
talk to Supabase over `supabase-js` / `supabase_flutter` using the publishable
(anon) key plus the user's JWT. All authorization is enforced in Postgres via RLS
and security-definer RPCs.

The two mobile clients are kept at feature parity: the same screens, the same
`*_rpc` surface, and the same error mapping. Expo is the reference
implementation; the Flutter client mirrors it (React Query → Riverpod,
`AuthProvider` → `authProvider`, `userMessage()` → `userMessage()`).

```
┌──────────────┐  ┌─────────────────┐  ┌────────────────┐
│ Expo mobile  │  │ Flutter mobile  │  │ Next.js admin  │
│ (owner/staff/│  │ (owner/staff/   │  │ (platform admin│
│  tenant)     │  │  tenant)        │  │  + org admin)  │
└──────┬───────┘  └────────┬────────┘  └───────┬────────┘
       │ supabase-js / supabase_flutter (anon key + user JWT)
       ▼                   ▼                    ▼
┌─────────────────────────────────────────────┐
│ Supabase                                    │
│  Auth ── JWT (sub, role, aal)               │
│  PostgREST ── tables (RLS) + RPC            │
│  Realtime ── rent_charges, payments,        │
│              notifications, stock_items     │
│  Storage ── private buckets (RLS)           │
│  Edge Functions ── reminders, webhooks,     │
│              invites, receipts, admin-api   │
│  pg_cron ── charges, overdue, reminders     │
│  Postgres ── schema, triggers, audit        │
└─────────────────────────────────────────────┘
       │ errors/crashes        │ platform logs
       ▼                       ▼
     Sentry               Supabase Logs / drain
```

## Layering rules

1. **RLS on every `public` table**, deny by default. The client never receives the service-role key.
2. Multi-tenant by `org_id`; every business table carries `org_id`.
3. Money is `numeric(14,2)`; never floats.
4. Soft delete (`deleted_at`) for properties, units, tenants. Hard deletes only for join/log data via admin RPCs.
5. Every schema change is a migration file. Never edit the DB by hand.
6. Client code uses generated types from `packages/shared`.

## Repository layout

```
fam/
├─ apps/mobile/        Expo (React Native) + TypeScript, Expo Router
├─ apps/mobile_flutter/ Flutter (Dart) client, Riverpod + go_router
├─ apps/admin/         Next.js App Router + Tailwind + shadcn/ui
├─ packages/shared/    types/, schemas, money/date helpers, permission matrix,
│                      error codes, version gate
├─ supabase/
│  ├─ migrations/      timestamp-free ordered .sql (0001..0016)
│  ├─ functions/       Edge Functions (Deno)
│  ├─ tests/           *.test.sql (pgTAP)
│  └─ seed.sql
├─ docs/
├─ .github/workflows/  ci.yml, flutter.yml, deploy.yml
└─ .env.example
```

## Data access policy

- Simple lists: table reads (`select`) with RLS filtering.
- Anything multi-step or transactional: an RPC (`security definer`, one transaction,
  explicit role check, clear error keys).
- "RPC only" tables (`rent_charges`, `payments`, `payment_allocations`,
  `stock_movements`, `stock_rentals`) have **no** client insert/update/delete
  policies; they are mutated only inside functions.

## Auth and roles

- Email + password (required); phone OTP optional (flag).
- Sign-up sends **one** identifier to GoTrue. The phone number typed on the form
  is profile data, so it travels in the sign-up metadata
  (`options.data.phone`) and `handle_new_user()` stores it on `profiles.phone`
  (migration `0017`); passing it as GoTrue's `phone` is rejected with
  `Only an email address or phone number should be provided on signup` unless
  phone sign-in is enabled for the project.
- When the project requires email confirmation (`mailer_autoconfirm = false`)
  `signUp` returns no session: both clients then show a "confirm your email"
  screen instead of routing into the app.
- Session storage on mobile: the platform secure store via a custom adapter —
  `expo-secure-store` (Expo) and `flutter_secure_storage` (Flutter). The refresh
  token never lands in plain preferences.
- Invitation deep-link tokens are held in the same secure store until accepted.
- Biometrics gate **opening an existing session**, never replace credentials.
- Org roles: `owner`, `manager`, `staff`, `viewer`. A **tenant** is not a role —
  it is a `tenants` row linked to a user who then sees only their own data.
- Platform admin: `profiles.is_platform_admin` plus **AAL2 (MFA)**, checked inside
  every `admin_*` RPC via `require_platform_admin()`.

## Admin gate (all layers)

1. UI route guards (Admin tab only for owner/manager; console only for platform admin).
2. Next.js middleware refreshes the session and redirects non-admins before page load.
3. RLS policies.
4. `admin_*` RPCs re-check the caller server-side.
5. Platform-admin actions require MFA at AAL2.
6. Every admin action writes an audit row.

## Background work

- `pg_cron` (UTC): generate charges 01:00, mark overdue 01:10, send reminders 05:00,
  prune logs Sun 02:30.
- `pg_net` calls the `send-reminders` Edge Function; the service key is read from
  Supabase **Vault**, never hard-coded in SQL.
- Edge Function auth: everything requires a valid JWT (`verify_jwt = true`)
  except `payment-webhook`, which is called by the payment provider and is
  verified with a timing-safe HMAC instead.

## Clients

- **Expo** (`apps/mobile`): Expo Router file-based routes, React Query for server
  state, `AuthProvider` context, `lib/errors.ts#userMessage` for user-facing errors.
- **Flutter** (`apps/mobile_flutter`): `go_router` with the same route table,
  Riverpod providers, an `authProvider` notifier, `core/errors/user_message.dart`
  for the same error mapping. Env is injected at build time with
  `--dart-define=FAM_SUPABASE_URL/FAM_SUPABASE_ANON_KEY/FAM_APP_ENV`.
- Invite deep links (`fam://invite?token=…`) reach the invite screen on both
  clients: Expo Router routes the scheme directly, and Flutter declares the
  `fam` VIEW intent filter (`tool/patch_android_manifest.py`) and rewrites the
  full URI — whose host is the first segment — to `/invite` in
  `lib/routing/deep_links.dart` before the auth guard runs.
- Both enforce the same first-run flow: sign up → (signed in, no membership) →
  create organization, and both keep that screen reachable while signed in.
- Android application id for both mobile builds is `com.fami.myapp`.

## CI/CD

- `ci.yml` (push/PR): Node — lint, typecheck, unit tests, admin build; Supabase —
  `supabase db reset` (applies `0001..0017`), `supabase test db` (pgTAP,
  `rls`/`rpc`/`security`/`signup`), `supabase db lint`.
- `flutter.yml` (push to `apps/mobile_flutter/**` or manual): `flutter analyze`,
  `flutter test`, then a release **APK** and **AAB**.
  - The Supabase URL and anon key are baked in with `--dart-define` from the
    `SUPABASE_URL` / `SUPABASE_ANON_KEY` repository secrets or variables
    (`FAM_SUPABASE_*` also accepted). A verification step fails the build when
    they are missing, so a keyless APK that cannot reach the backend is never
    published.
  - `android/` is not committed (it carries a binary `gradle-wrapper.jar`);
    `tool/setup_android.sh` generates it with `flutter create`, rewrites the
    application id to `com.fami.myapp`, labels the app `Fam`, sets
    `minSdk = 24` and `allowBackup="false"`, and adds the `fam://` invite
    intent filter (`tool/patch_android_manifest.py`).
  - Release signing: when `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
    `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` are set, the script decodes the
    keystore into `android/key.properties` and `tool/patch_android_signing.py`
    switches `buildTypes.release` to the upload key. Without the secrets the build
    stays debug-signed, so CI stays green on forks.
- `deploy.yml` (manual or version tag): database, Edge Functions and Expo
  (EAS) mobile. The admin web app is hosted separately.

## Observability

- `audit_logs` written by triggers (key tables) plus custom action rows
  (`payment.void`, `role.change`, `lease.terminate`, `flag.change`, `version.publish`).
- `app_event_logs` via the `log_client_event` RPC (rate-limited, truncated).
- Sentry in mobile and admin; source maps uploaded in CI.
- Structured JSON logs in Edge Functions with `request_id`.
