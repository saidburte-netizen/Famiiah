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
- `terminate_lease` wrapper now passes the required `p_end_date`.
- `createUnit` writes the correct `units.area_sqm` column.
- Corrected RPC argument names for dashboard/list/report/stock/notification calls.

### Added (mobile)

- `(auth)/invite` screen: accepts `fam://invite?token=…` deep links by hashing
  the token (SHA-256) and calling `accept_invitation`; stashes a pending token
  across sign-in/sign-up via `lib/invite.ts`.
- Launch version gate is now wired in `app/_layout.tsx` (force-update screen);
  the `x-client-version` header now carries the real app version.

### Notes

- Mobile and admin app scaffolds follow in later phases.
- `online_payments` and `maintenance_requests` are behind feature flags (off).
