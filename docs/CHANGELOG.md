# Changelog

All notable changes are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Phase 0 — Foundation**: pnpm + Turborepo monorepo, `.env.example`, CI workflow.
- **Phase 0 — Shared package** (`@fam/shared`): money helpers (integer minor units),
  permission matrix, semantic-version gate, error keys, zod schemas; unit tests.
- **Phase 1 — Database**: migrations `0001`–`0015`:
  - extensions, enums, helper functions
  - core tables (profiles, organizations, members, invitations, properties, units,
    tenants, leases, charges, payments, allocations)
  - stock, notifications, logs, versioning, feature flags
  - triggers (updated_at, new-user profile, unit status sync, receipt numbering, audit)
  - RLS with helper functions and per-table policies
  - storage buckets + policies, realtime publication, pg_cron jobs
  - RPC catalog (version gate, org/invites, tenants/leases, charges, payments,
    dashboard/lists/reports, stock, notifications/logs, admin)
  - execute-privilege lockdown for security-definer functions
- **Phase 1 — Edge Functions**: `send-reminders`, `invite-member`, `generate-receipt`,
  `payment-webhook`, `admin-api`.
- **Phase 1 — Tests**: pgTAP RLS matrix and RPC invariants; seed data.
- **Docs**: ARCHITECTURE, SCHEMA, API, VERSIONS, ASSUMPTIONS, RUNBOOK, CHANGELOG.
- **CI/CD**: `.github/workflows/ci.yml` (lint/typecheck/test, DB migrate + lint
  + pgTAP + drift check, admin production build, informational dependency audit)
  and `.github/workflows/deploy.yml` (manual/tag CD: DB → Edge Functions → admin
  → mobile). `apps/mobile/eas.json` build profiles and `docs/DEPLOYMENT.md`.
- **Phase 2 — Mobile app** (`@fam/mobile`): Expo Router auth flow, tab shell
  (Home, Properties, Tenants, Rent, Admin), secure-store Supabase client, i18n
  shell, version gate, shared UI primitives.
  - Screens: dashboard, properties list + detail + create, units, tenants list +
    detail (renew/terminate), create tenant & lease, rent overview, record
    payment, stock (list + adjust), notifications, settings.
  - `features/api.ts` — typed wrappers for every RPC/table query the app uses.
  - `lib/org.ts` — `useOrg()` active-organization hook.
- **Phase 2 — Mobile: remaining screens**: payment history + void, stock
  rentals (rent out / return), reports (collections, occupancy, overdue
  ageing), and admin member management (invite, role, status).
- **Phase 2 — Admin console**: org member drilldown (`/members/[id]`) and
  per-org reports (`/reports/[id]`). `admin_list_members` and the
  `report_*` RPCs now also authorise platform admins.
- **Assets**: real `icon.png`, `adaptive-icon.png` and `splash.png`
  (midnight + F-tower mark) replacing placeholders; admin nav label fixed
  to "Organizations".
- **Push delivery**: `send-reminders` now also dispatches queued push
  notifications to recipients' devices via the Expo push API and marks them
  `sent`/`failed` (no-device ones fail rather than retry forever).
- **CD**: the mobile job can sign Android builds with a keystore supplied as
  environment secrets (`ANDROID_KEYSTORE_BASE64` + password/alias/key
  password); it writes a gitignored `credentials.json` and builds with the
  `ci` EAS profile (`credentialsSource: local`). Without the secret it falls
  back to EAS-managed credentials.
- **Mobile push**: `lib/push.ts` registers the Expo push token on launch
  (permission prompt → `register_device_token`); tapping a notification
  routes to the Notifications screen.

### Changed

- `@fam/shared` `formatMoney` now accepts `string | number` (Postgres `numeric`
  arrives as a JSON number) and normalises without float drift.
- `Database` placeholder rows typed `any` so supabase-js's select-string parser
  resolves column names (index-signature rows previously produced `never[]`).
- Admin `@supabase/ssr` bumped `^0.6.1` → `^0.12.7` (0.6.x d.ts imported a
  removed `@supabase/supabase-js/dist/module/lib/types` path).
- Mobile: added `@supabase/supabase-js` and `@types/node`.
- Tooling: added `eslint-plugin-react-hooks`; enabled only `rules-of-hooks` and
  `exhaustive-deps` (v7's new rules flag standard RN patterns).

### Fixed

- **SQL**: `check_app_version` declared `v rec;` (not a type); changed to
  `v record;`. This broke `supabase db reset` / `db push` at migration `0009`.
- **SQL**: `accept_invitation` read `email` from `profiles` (no such column);
  now reads it from `auth.users`.
- **SQL**: `list_units` had an ambiguous `id` (`select org_id from properties
  where id = p_property`); qualified with a table alias.
- **SQL**: `record_payment` now also authorises the `service_role`, so the
  online-payment webhook (no user session) can record payments.
- **SQL**: added the missing `storage.objects` update policy for the `receipts`
  bucket (needed by `generate-receipt`'s `upsert`).
- **Edge**: `invite-member` calls `invite_member` as the user (not service role)
  so its `has_org_role` check sees the caller.
- **Edge**: `send-reminders` read `tenant_id`/`user_id`/`name` as flat fields
  instead of nested under `leases`; corrected, and widened the reminder window
  (due today, +3 days, overdue 1/7/14 days).
- **Tests**: pgTAP fixtures used non-hex UUID literals; corrected them and made
  `plan(N)` match the assertion counts.
- **CI**: admin job now builds `@fam/shared` before `next build` (the admin
  build script runs `pnpm --filter @fam/shared build` first), fixing
  "Cannot find module '@fam/shared'" on CI.
- **CI**: dependency-audit step is now informational (`continue-on-error`) since
  the remaining advisories are transitive build tooling with no patched release.
- **CI**: `supabase start` retries with backoff (Docker Hub rate-limits
  unauthenticated pulls on shared runners); `db lint` pinned to `--level error`.
- **CI**: `supabase/setup-cli` moved to `v3` with a pinned CLI version. The `v1`
  action resolved `latest` through the GitHub API and intermittently failed the
  database job with "rate limit exceeded"; v3 installs the CLI from npm.
- `terminate_lease` wrapper now passes the required `p_end_date`.
- `createUnit` writes the correct `units.area_sqm` column.
- Corrected RPC argument names for dashboard/list/report/stock/notification calls.
- **Sign-up failed for every new account**: both clients passed the phone number
  as GoTrue's `phone`, which is rejected (`Only an email address or phone number
  should be provided on signup`) unless phone sign-in is enabled for the project,
  and the unmapped `validation_failed` code surfaced as "Something went wrong".
  The number now travels in the sign-up metadata and `handle_new_user()`
  (`0017`) stores it on `profiles.phone`; the auth codes GoTrue actually returns
  (`email_address_invalid`, `signup_disabled`, `*_provider_disabled`,
  `validation_failed`, `otp_expired`) now map to named messages.
- Sign-up no longer dead-ends when the project requires email confirmation
  (`mailer_autoconfirm = false`): `signUp` returns no session, so both clients
  show a "confirm your email" screen instead of routing into the app.

### Added (mobile)

- `(auth)/invite` screen: accepts `fam://invite?token=…` deep links by hashing
  the token (SHA-256) and calling `accept_invitation`; stashes a pending token
  across sign-in/sign-up via `lib/invite.ts`.
- Launch version gate is now wired in `app/_layout.tsx` (force-update screen);
  the `x-client-version` header now carries the real app version.
- **Unique @handle** (migration `0018`): `profiles.handle` (lowercase
  `[a-z][a-z0-9_]{2,23}`, unique index + format check) and
  `profiles.accept_terms_at`. The anon-callable `handle_available()` RPC lets
  the unauthenticated sign-up form check a handle before creating the account;
  `handle_new_user()` stores the handle, falls back to `@handle` for the
  display name and records the terms timestamp (defensive against malformed
  metadata). Shared `Handle` schema (`packages/shared/src/schemas.ts`) and
  `normalizeHandle` (`apps/mobile_flutter/lib/core/handle.dart`) apply the same
  rule as the database; pgTAP coverage in `supabase/tests/handle.test.sql`
  (uniqueness, format, normalisation, legacy sign-ups unaffected).

### Added (mobile — state & errors)

- `lib/auth.tsx` — single `AuthProvider`/`useAuth()` owning the Supabase session,
  replacing the duplicated listener in the root layout.
- `lib/errors.ts` — `userMessage()` maps Supabase/PostgREST/network failures to
  localized copy via `@fam/shared` error keys (plus Supabase Auth codes), so raw
  SQL never reaches the UI; `errorTag()` for logs.
- `components/error-boundary.tsx`, exported from `app/_layout.tsx` as the router
  `ErrorBoundary`, so render failures show a retry screen instead of a blank app.
- `components/ui.tsx`: `ErrorState` (message + retry) and `EmptyState`.
- `lib/query.tsx`: centralized `queryKeys`, retry that skips client errors,
  `gcTime`, and mutations no longer retry.
- `lib/supabase.ts`: `hasSupabaseEnv()`; `app/_layout.tsx` shows a config screen
  instead of throwing when the build lacks its public Supabase env.
- `i18n` catalogue now covers every shared error key plus auth/network/transport.

### Added (Flutter mobile)

- `apps/mobile_flutter/` — a Flutter client mirroring the Expo app: `go_router`
  route table, Riverpod providers (`authProvider`, `orgProvider`), shared theme
  tokens, and `features/api.dart` wrappers for the same RPC/table surface.
  Version `1.1.0+2`.
- `.github/workflows/flutter.yml` — `flutter analyze` + `flutter test`, then a
  release APK and AAB for `com.fami.myapp`. `tool/setup_android.sh` generates the
  Gradle project on demand (no committed `android/`) and
  `tool/patch_android_signing.py` switches to the upload keystore when the
  `ANDROID_KEYSTORE_*` secrets are present.
- Secure session storage: `flutter_secure_storage` behind a custom
  `SecureLocalStorage` adapter, matching the Expo app's `expo-secure-store`; the
  pending invitation token uses the same store. `package_info_plus` moved to
  `^10.2.2` so it and `flutter_secure_storage` resolve the same `win32` major.
- First-run flow: a signed-in user with no membership can reach
  `/auth/create-organization` (both clients), and the dashboard offers a
  "Create organization" action instead of a dead end. Creating an org (or
  accepting an invite) refreshes the active-org state before routing.
- Invite deep links work on Android: `tool/setup_android.sh` adds the `fam://`
  VIEW/BROWSABLE intent filter and `lib/routing/deep_links.dart` rewrites the
  link (`fam://invite?token=…`, where `invite` is the URI host) to the `/invite`
  route before the auth guard, so the invite screen is reachable from a link.

### Changed (mobile)

- Home / Properties / Tenants / Rent tabs now read through React Query against
  the shared `useOrg()` org instead of each re-querying `organization_members`.
- Auth and mutation screens surface errors with `userMessage()`; the rent tab's
  "send reminder" is a tracked mutation that surfaces failures via Alert.
- Sign-up is a **single** form in both clients — @handle, phone number and
  password on one screen, behind a terms toggle that must be ticked to submit
  (email stays out of the payload entirely). The phone is now
  the GoTrue identifier, so sign-up/sign-in need **Providers → Phone** enabled;
  when the project asks for SMS confirmation the clients show a "confirm your
  phone" code step (`verifyOtp`, type `sms`) instead of a "confirm your email"
  screen. The sign-in field accepts a phone number **or** an email, so accounts
  created before this change still sign in. Handle availability is checked via
  `handle_available()` before the account is created, with the shared error
  copy (`error.handleTaken`, `error.handleInvalid`, `error.acceptTerms`).
- Phone numbers are normalised to E.164 by a shared `toE164()` helper
  (`packages/shared/src/phone.ts` + `apps/mobile_flutter/lib/core/phone.dart`),
  so `09…`, `251…` and `+251…` all reach GoTrue in one shape.
- Flutter release bumped `1.1.1+3` → `1.1.3+5` (phone + @handle sign-up).
- The Admin tab's visibility derives from `useOrg().role`.

### Fixed (Flutter mobile)

- `userMessage()` maps `AuthWeakPasswordException` (gotrue prints `reasons:`
  instead of `code:` for it) to the weak-password message, and tests now lock
  in the `AuthApiException(message: …, statusCode: …, code: …)` shape that
  gotrue 2.27 actually prints, so auth failures never fall back to the generic
  message.

- Forgot-password swallowed failures (`try/finally` with no `catch`), leaking an
  unhandled async error; network failures now surface via `userMessage()`.
- Stock adjust/rent now invalidates the low-stock provider as well as the
  catalogue, so the reorder badge updates immediately.
- Sign-out failures are reported instead of silently ignored.
- `initSupabase()` failure renders the config screen instead of crashing before
  `runApp`.
- Removed the duplicate **Stock** quick action (it is already in the shell).
- Removed the decorative owner/manager/staff role chips from login in both mobile
  clients — they looked selectable but changed nothing.
- `tool/setup_android.sh` no longer emits a duplicate `android:allowBackup`
  attribute (two sed expressions both matched), which had failed the release
  Android build in the manifest merger; the manifest is now XML-validated.
- The release APK/AAB were built without the Supabase URL/anon key, so an
  installed build showed a configuration screen and could not sign in.
  `flutter.yml` now passes both with `--dart-define` (and an app-env define) and
  fails with a clear error when they are missing, so a keyless artifact is never
  published.
- The missing-config screen is now a plain "can't reach the server" message for
  users; the `--dart-define` instructions are debug-only.
- The Flutter CI read only `ANDROID_KEYSTORE_*`, so an existing `KEYSTORE_*`
  keystore (including the `KEYSTORE_BASE` shorthand) was ignored and release
  builds stayed debug-signed; both workflows now accept either naming, and a
  keystore that fails to decode or open is reported with a clear error.
- The generated `android/` project and `pubspec.lock` are gitignored so a local
  build cannot sweep them into a commit.

### Security

- `invitations` row policy narrowed to owner/manager, and `token_hash` revoked
  from client roles via column-level grants.
- `accept_invitation` fails closed: the caller's email (or, for phone-only
  invitations, the verified phone) must match the invitation.
- `invite_member` only lets an owner mint an `owner` invitation.
- Cron-only `generate_monthly_charges` / `mark_overdue_charges` revoked from
  client roles.
- `assign_tenant_to_unit` requires the tenant to belong to the unit's org.
- Avatar writes scoped to the caller's own storage folder.
- `admin_set_member_status` cannot be used by a manager to suspend an owner.
- `register_device_token` cannot reassign an existing token to another user.
- `profiles` INSERT column grants stop a client from self-setting
  `is_platform_admin`.
- `send-reminders` requires a valid JWT (`verify_jwt = true`).
- New pgTAP regression suite `supabase/tests/security.test.sql`.

### Notes

- Mobile and admin app scaffolds follow in later phases.
- `online_payments` and `maintenance_requests` are behind feature flags (off).
- Password-reset links (`fam://reset-password`, sent by `resetPasswordForEmail`)
  open both clients, but neither has a screen to set the new password yet, so the
  link falls through to sign-in. Completing the recovery flow (and adding the
  matching route to both clients) is follow-up work.
