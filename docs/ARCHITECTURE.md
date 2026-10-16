# Architecture

Fam is a property and rental management product built on Supabase only — no
separate API server. Two clients (Expo mobile, Next.js admin) talk to Supabase
over `supabase-js` using the anon key plus the user's JWT. All authorization is
enforced in Postgres via RLS and security-definer RPCs.

```
┌──────────────┐   ┌────────────────┐
│ Expo mobile  │   │ Next.js admin  │
│ (owner/staff/│   │ (platform admin│
│  tenant)     │   │  + org admin)  │
└──────┬───────┘   └───────┬────────┘
       │ supabase-js (anon key + user JWT)
       ▼                   ▼
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
├─ apps/admin/         Next.js App Router + Tailwind + shadcn/ui
├─ packages/shared/    types/, schemas, money/date helpers, permission matrix,
│                      error codes, version gate
├─ supabase/
│  ├─ migrations/      timestamp-free ordered .sql (0001..0015)
│  ├─ functions/       Edge Functions (Deno)
│  ├─ tests/           *.test.sql (pgTAP)
│  └─ seed.sql
├─ docs/
├─ .github/workflows/
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
- Session storage on mobile: `expo-secure-store` via a custom adapter.
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

## Observability

- `audit_logs` written by triggers (key tables) plus custom action rows
  (`payment.void`, `role.change`, `lease.terminate`, `flag.change`, `version.publish`).
- `app_event_logs` via the `log_client_event` RPC (rate-limited, truncated).
- Sentry in mobile and admin; source maps uploaded in CI.
- Structured JSON logs in Edge Functions with `request_id`.
