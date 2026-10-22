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
- **Session storage (both mobile clients)**: a device whose Keystore throws no
  longer fails sign-up *after* the account was created server-side — the
  supabase-js storage adapter and the pending-invite helpers now degrade to
  plain app-private storage (or "no pending invite") exactly like the Flutter
  client, so an `expo-secure-store` error can't surface as "Something went
  wrong" (ASSUMPTIONS A14).

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
- **Sign-up switched to email** so new accounts work on the free tier: the
  phone identifier needed **Providers → Phone**, which requires a paid SMS
  gateway. The form is now @handle + email + password (+ the terms toggle);
  login still accepts a phone **or** an email, so existing accounts are
  unaffected, and the phone/OTP sign-up path stays dormant in both clients to
  switch back on when SMS is funded. With **Confirm email** off (free, no SMTP
  needed) `signUp` returns a session and users get in straight away; if
  confirmations are ever on, the form shows a "check your email" notice
  (`auth.confirmEmail`) instead of routing into the app.
- Flutter release bumped `1.1.3+5` → `1.1.4+6` (email sign-up).

### Fixed (Flutter mobile)

- Release builds had **no `android.permission.INTERNET`**: `flutter create`
  puts it only in the debug/profile manifests, never in the main one, so every
  API call on an installed release APK failed with a socket error ("No
  connection. Check your network and try again.") while the phone's browser
  reached the same Supabase host fine. `tool/patch_android_manifest.py` (run by
  `tool/setup_android.sh`) now adds the permission to the main manifest —
  idempotent, XML-validated, flows into the CI-built APK/AAB.
- Flutter release bumped `1.1.4+6` → `1.1.5+7` (release INTERNET permission).
- A device whose Android Keystore throws turned **successful** sign-ups into the
  generic "Something went wrong": the session is written inside
  `auth.signUp()`/`signInWithPassword()`, so a broken Keystore failed the flow
  *after* the account was created server-side (the backend accepts the app's
  exact payload end to end — session returned, profile stored with the handle
  and terms stamp). The session store now falls back to plain app-private
  preferences — where `supabase_flutter` keeps the session by default — only
  when the secure store throws, and clears that copy again on a healthy write
  or sign-out; pending-invite reads/writes are best-effort for the same reason,
  so an undecryptable invite token can never block a sign-in.
- TLS handshake/certificate failures now read as a connection problem
  (`error.network`) instead of the generic message.
- Flutter release bumped `1.1.5+7` → `1.1.6+8` (resilient session storage).
- **Sign-up: @handle is now optional**. The shared `SignUpSchema`, both clients'
  sign-up forms, and `normalizeHandle()` in Flutter all accept a blank handle;
  when provided it must match the format and is checked for uniqueness via
  `handle_available()` before creating the account; when omitted, no `handle` is
  sent in the `auth.signUp()` metadata and the profile's `handle` remains NULL
  (the unique index on `profiles.handle` treats NULLs as distinct). This removes
  the create-account failure for users who never set a handle. (Flutter bumped
  `1.1.6+8` → `1.1.7+9`.)
- **Password reset is now reachable end to end.** The `fam://reset-password`
  link GoTrue emails was previously a dead end (no screen, no route). Both
  clients now rewrite the link to a reset screen (keeping the recovery tokens in
  the URI fragment), turn them into a session and call `updateUser`; an expired
  or reused link shows a friendly message plus a fresh-link action. The Flutter
  deep-link rewriter handles both `invite` and `reset-password`. (Flutter bumped
  `1.1.7+9` → `1.1.8+10`.)
- **Two runtime bugs fixed**: the RN login button stayed spinning forever on a
  rejected identifier (validation ran after `setBusy(true)`, so the early
  `return` skipped the `finally` that clears it); the RN invite screen compared
  already-translated text against raw error keys, so its invalid/expired-copy
  branches never fired (now matches on the normalized error key).
- **Flutter push registration seam** (`lib/core/push.dart`): the same
  `register_device_token` contract the Expo client uses, wired into launch and
  sign-in, as a no-op until an FCM-backed `PushTokenSource` is supplied (no
  provider is committed, since Android push needs a `google-services.json`).
- **React Query cache invalidation after every mutation.** The Expo client set
  `staleTime: 30s` and only invalidated the cache in one place, so creating a
  property/unit/tenant, recording or voiding a payment, adjusting/renting/
  returning stock, renewing/terminating a lease or assigning a tenant returned
  the user to a tab that still showed the old data for up to 30 s. Every
  mutation now invalidates the queries it affects (`properties`, `units`,
  `tenants`, `payments`, `rent-overview`, `dashboard`, `stock-low`,
  `stock-rentals`), so lists and totals update immediately.
- **Deleting a user no longer fails** (migration `0019`). The audit columns
  `organizations.created_by`, `invitations.invited_by`, `payments.received_by` /
  `voided_by` and `stock_movements.performed_by` referenced `auth.users(id)`
  with the default `NO ACTION`, so once a user had created an organization, sent
  an invitation, received/voided a payment or recorded a stock movement, the
  dashboard's **Delete user** (and any `service_role` delete) failed with
  "Database error deleting user" — a foreign-key refusal, not a missing row.
  Those five constraints are now `ON DELETE SET NULL`: the account is removed
  and the authored records survive with their actor cleared, matching how
  `tenants.user_id` already behaves. Accounts a user owns (`profiles`,
  `organization_members`, `notifications`) still cascade. A new pgTAP test
  (`user_delete`) deletes a user who authored all four record types and asserts
  the delete succeeds and the records remain.
- Flutter i18n catalogue gained the shared action labels (New, Save, Cancel,
  Manage, Refresh, History, …) and the reset-screen strings; both catalogues
  now define every key the screens reference.
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

### Verified (sign-up / sign-in without confirmation)

End-to-end audit of the free (no-SMS, no-email-confirmation) account flow against
the live project (`dlbgnurfuydcziczlzltl`), using the exact payloads the Flutter
client sends:

- Live auth settings confirm the intended shape: `mailer_autoconfirm: true`
  (no confirmation email), `external.email: true`, `external.phone: false`
  (no OTP), `disable_signup: false`.
- **Sign-up** (`POST /auth/v1/signup`, email + password + `accept_terms_at`)
  returns a full session immediately (`access_token` + `refresh_token`) with
  `email_confirmed_at` already set, so the app lands straight in the dashboard —
  no code to enter and no link to click.
- The `handle_new_user()` trigger wrote the `profiles` row with
  `handle = NULL` (the handle field was left blank) and `accept_terms_at` set.
- `create_organization` made the new user an `owner`/`active` member, so the
  post-sign-up redirect to the dashboard resolves a real org.
- **Sign-in** (`grant_type=password`) with the same credentials succeeds
  (`HTTP 200`, 1 h token) — password-only, no OTP.
- Every mutation the UI exposes was exercised and returned 200:
  property, unit, `create_tenant_with_lease`, `record_payment` (receipt no.
  assigned), `void_payment`, `stock_adjust`, `rent_stock_item`,
  `return_stock_item`, `renew_lease`, `terminate_lease`,
  `admin_set_member_role` (the `cannot_demote_last_owner` guard rejects a
  self-demotion of the only owner), `mark_*_notification_read`,
  `send_reminders_bulk`.
- Every read RPC the screens use returns rows: `dashboard_summary`,
  `list_properties_with_stats`, `list_units`, `list_tenants_with_status`,
  `rent_overview`, `report_occupancy`, `report_collections`,
  `report_overdue_ageing`, `admin_list_members`, `list_low_stock`.
- Every in-app navigation target resolves to a declared `go_router` route, and
  both `fam://invite` and `fam://reset-password` deep links are registered by
  `tool/patch_android_manifest.py` (which also adds the release
  `INTERNET` permission).

**Gap found — Edge Functions are not deployed.** All five functions
(`invite-member`, `generate-receipt`, `payment-webhook`, `send-reminders`,
`admin-api`) return `404 NOT_FOUND` on the live project, because `deploy.yml`
has never run and its `functions` job needs the `SUPABASE_PROJECT_ID` secret
(currently unset). The only user-visible effect is the Admin screen's **Invite**
action: `inviteMember()` calls `invite-member`, so it cannot succeed until the
functions are deployed. The client maps the 404 to the friendly
"Something went wrong" copy (no raw error), so nothing crashes. Deploy with
`deploy.yml` (components: `functions`) once `SUPABASE_PROJECT_ID` is set, or
`supabase functions deploy --project-ref <ref>`.

### Branding (Flutter mobile)

- The Flutter client now matches the approved design
  (`Fam-App-Design.html`, repo root): white surfaces on a `#F4F7FE` canvas, navy
  `#0A2260`/midnight `#061538` gradients, royal `#1D4ED8` actions and the
  `#DDE5F5` hairline border. `lib/theme/tokens.dart` gained the extended palette
  (tints, ink, semantic danger/success/warning, radii, gradients, shadows,
  weights) and `lib/theme/app_theme.dart` was rebuilt from it.
- **Typography is bundled, not fetched.** `google_fonts` is gone; Manrope
  (400/500/600/700/800) and Playfair Display (600/700) ship as TTFs in
  `assets/fonts/` declared in `pubspec.yaml`, so the app looks identical offline
  and in release builds. `FamFonts.body = 'Manrope'`,
  `FamFonts.display = 'PlayfairDisplay'`.
- **A shared brand component library** (`lib/widgets/brand.dart`) — `FamLogo`
  (the mark is *drawn* by a `CustomPainter`, so it stays crisp from 22 px tab
  icon to 138 px splash), `FamWordmark`, `FamGradientSurface`, `FamRing`,
  `FamIconButton`, `FamPrimaryButton`, `FamSecondaryButton`, `FamScreenHeader`,
  `FamSegmented`, `FamFilterPills`, `FamStatTile`, `FamHeroCard`,
  `FamSectionHeader`, `FamAvatar`, `FamBadge`, `FamProgress`, `FamFab`,
  `FamAuthHeader`, `FamDots`. `lib/widgets/ui.dart` gained `FamNotice` and
  `FamInfoRow` and restyled `FamScreen`/`FamCard`/`FamField`/`ErrorState`/
  `EmptyState`; `lib/widgets/page.dart`'s `FamPage` gained a `subtitle`, a white
  circular back button and a 22 px w800 title.
- Every screen was rebuilt against the design: splash, login, sign-up, forgot/
  reset password, create-organization, invite, dashboard, the bottom-tab shell
  (custom pill-indicator nav), properties (list/new/detail), units (form/assign/
  new), tenants (list/new/detail), rent, payments (list/new), stock (list/
  rentals), notifications, reports, settings and admin (team + invite/manage
  sheets).
- **Launcher and adaptive icons**: committed PNGs in
  `assets/branding/android/mipmap-*` (generated by
  `tool/generate_brand_icons.py`) are installed into the generated `android/`
  project by `tool/setup_android.sh`, along with the `mipmap-anydpi-v26` adaptive
  XML and a `#0A2260` background. `android/` itself stays uncommitted.
- Design elements with no implementation behind them were **omitted or reworded**
  rather than added as dead controls — no Face ID/fingerprint, no role tabs on
  login, no phone field, and the sign-up progress bar shows one filled segment
  labelled "Your details" instead of a fake "Step 1 of 3".
- Flutter release bumped `1.1.8+10` → `1.1.9+11` (brand rework).

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
