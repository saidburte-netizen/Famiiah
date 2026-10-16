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

### Notes

- Mobile and admin app scaffolds follow in later phases.
- `online_payments` and `maintenance_requests` are behind feature flags (off).
