# Assumptions

Decisions taken where the brief was unspecified. Chosen to be the most
conventional option, per the build prompt. Update this file when a decision
changes.

| # | Area | Assumption | Rationale |
|---|------|-----------|-----------|
| A1 | Money | All money handled as integer minor units (bigint) client-side; DB stores `numeric(14,2)`. | Avoids float error; DB remains source of truth. |
| A2 | Currency | ETB only in v1; currency column exists on `organizations` for future use. | Spec says ETB. |
| A3 | Timezone | All timestamps stored UTC (`timestamptz`); display in `Africa/Addis_Ababa`. | Standard; DST-free zone. |
| A4 | Tenant identity | A tenant is not an auth role; a `tenants.user_id` link grants self-service access. | Spec section 9. |
| A5 | Billing day | `1..28` to avoid month-end edge cases. | Check constraint; matches spec. |
| A6 | Charge generation | Generated for the **current** month on the 1st (cron 01:00 UTC = 04:00 Addis). | Spec cron; no back-fill in v1. |
| A7 | Grace period | Defaults to 5 days; a charge becomes overdue when `due_date + grace_days < today`. | Spec default. |
| A8 | Payment allocation | Oldest unpaid charge first; leftover stored in `unallocated_amount`. | Spec `record_payment`. |
| A9 | Receipt numbers | `RCP-YYYY-NNNNNN`, per-org atomic counter. | Spec. |
| A10 | Soft delete | Properties/units/tenants use `deleted_at`; archive only, no hard delete via client. | Spec section 4. |
| A11 | Stock adjustment | `adjustment` sets an **absolute** balance (from a stock count); `in`/`out` are relative. | Common inventory pattern. |
| A12 | Invitations | Raw token is only sent to the user; DB stores SHA-256 `token_hash`. | Security. |
| A13 | Sign-up identifier | Sign-up is **@handle + email + password** (plus a terms toggle that must be ticked; the email is the GoTrue identifier). Email is the only identifier that needs no paid gateway, so sign-up works on the free tier; the phone/OTP sign-up path is **dormant** until Providers → Phone is enabled (billed SMS, deferred). The sign-in field keeps accepting a phone **or** an email, so accounts created earlier keep working. | SMS auth costs per message (skipped for now); GoTrue accepts exactly one identifier per sign-up. |
| A14 | Session storage | The session lives in the platform secure store (Keystore/Keychain); if — and only if — that store **throws**, it falls back to plain app-private storage (what `supabase_flutter` / `supabase-js` do by default) instead of failing the auth flow. A broken Keystore must not block sign-up after the account was created server-side; the fallback copy is cleared on a healthy write or sign-out. | Availability over storage confidentiality for the fallback; refresh token stays inside the app sandbox either way. |
| A14 | MFA | Platform-admin RPCs require AAL2; `ADMIN_REQUIRE_MFA=false` can disable for local dev. | Spec admin gate. |
| A15 | First platform admin | Promoted manually (seed or migration) — no client path. | Spec section 9. |
| A16 | Online payments | `online_payments` flag off by default; webhook verifies HMAC signature. | Spec. |
| A17 | i18n | Keys exist for `en`; `am`/`om` added without code changes. | Spec. |
| A18 | Offline writes | Stock adjustments may be queued; payments never queued (idempotency key on retry). | Spec section 10. |
| A19 | PDF generation | `generate-receipt` emits a minimal PDF placeholder; swap in `pdf-lib` for real layout. | Kept dependency-light. |
| A20 | `unique nulls not distinct` | Requires Postgres 15+; Supabase projects meet this. | Spec note. |
| A21 | Sentry | DSNs are env-driven; disabled when unset. | Avoids build failures. |
| A22 | Email/SMS providers | Abstracted behind `EMAIL_PROVIDER_KEY` / `SMS_PROVIDER_KEY`; not bound to a vendor. | Spec lists them as secrets. |
| A23 | Password reset | Supabase email link flow; OTP screen shown when SMS enabled. | Spec screen list. |
| A24 | Simple CRUD writes | Property/unit creation uses direct table inserts guarded by RLS (`has_org_role(...,'owner','manager')`), not RPCs. Business writes (payments, leases, stock) stay RPC-only. | RLS suffices; avoids boilerplate RPCs for trivial inserts. |
| A25 | React version | React and React DOM are pinned to `19.1.0` workspace-wide via `pnpm-workspace.yaml` `overrides`, matching React Native 0.79. | Mismatched react/react-dom breaks the admin build. |
| A26 | Dependency audit | The CI `audit` job is informational (`continue-on-error`). | Remaining advisories are transitive build tooling (`braces`, `node-forge`) with no patched release. |
| A27 | Invite acceptance | The client hashes the raw deep-link token (SHA-256, via `expo-crypto`) before calling `accept_invitation(p_token_hash)`; the Edge Function stores the same hash. | Keeps the raw token out of the database. |
| A28 | EAS monorepo build | Mobile adds `eas-build-post-install` to build `@fam/shared`; admin's `build` script builds `@fam/shared` first. | Workspace packages resolve to `dist`, which must exist before bundling. |
| A29 | Direct RLS writes | Creating/editing a property or unit is a plain PostgREST insert/update guarded by RLS (`owner`/`manager` policies), not an RPC. Payments, leases, stock movements and voids go through SECURITY DEFINER RPCs. | CRUD with no cross-table business rule stays on RLS; anything needing invariants/audit stays server-side. |
| A30 | Stock rentals | Renting out / returning stock goes through `rent_stock_item` / `return_stock_item`; `stock_rentals` is read-only over PostgREST (RLS). The app picks a tenant and a due date. | Writes touch `stock_items` quantity, so they must be server-side. |
| A31 | Push notifications | The app stores its Expo push token via `register_device_token`; the daily `send-reminders` cron queues reminders and then dispatches queued push rows to the Expo push API (marking `sent`/`failed`). Delivery needs FCM (Android) / APNs (iOS) credentials configured in EAS and an optional `EXPO_ACCESS_TOKEN` secret — not in this repo. | Keeps provider credentials in EAS; the token table + RPC are the only server contract. |
| A32 | Handle uniqueness | The sign-up **@handle** is the account's public name: lowercase `[a-z][a-z0-9_]{2,23}` (3–24 chars), unique project-wide, stored on `profiles.handle`. The clients ask the anon-callable `handle_available()` RPC before submitting; the unique index is what actually guarantees it, and the display name falls back to `@handle`. The terms acceptance is recorded as `profiles.accept_terms_at` from the sign-up metadata. | GoTrue metadata cannot enforce uniqueness, so the database owns the rule (migration `0018`); a stored timestamp makes the required terms toggle auditable. |
