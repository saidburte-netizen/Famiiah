# Runbook

Operational procedures for Fam. Environments: `local` (Supabase CLI), `staging`,
`production` (separate Supabase projects).

## Deploy

1. **Database**: merge migration PR → CI runs `supabase db reset` + `supabase test db`
   → apply to staging (`supabase db push`), verify, then production.
2. **Edge Functions**: `supabase functions deploy <name> --project-ref <ref>`.
   Set secrets with `supabase secrets set`.
3. **Admin**: deploy the Next.js app to the hosting provider; set
   `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `NEXT_PUBLIC_SENTRY_DSN`.
4. **Mobile**: `eas build` + `eas submit`; publish an `app_versions` row via
   `admin_publish_app_version`.

## Rollback

- **Admin/mobile**: redeploy the previous build/tag.
- **Edge Functions**: redeploy the previous commit.
- **Database**: migrations are forward-only. To undo, write a new migration that
  reverts the change. For a bad data migration, restore from PITR (see below).

## Backup and restore

- Production has **PITR** enabled. Verify in the Supabase dashboard.
- Restore drill (run quarterly on staging): note the target timestamp, trigger a
  restore to a scratch project, run `supabase test db` against it, confirm row counts.
- Logical backup: `supabase db dump -f backup.sql` (schema + data) before risky changes.

## Key rotation

1. **Service role key**: rotate in Supabase → update Edge Function secrets
   (`supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...`) → update CI secrets →
   redeploy functions. Clients never hold this key.
2. **Vault secrets** (`service_role_key`, `project_url` used by pg_cron):
   `select vault.update_secret(id, 'new') from vault.secrets where name = '...';`
3. **Provider keys** (Chapa, SMS, email): rotate in provider dashboard, update
   Supabase secrets, redeploy the affected function.
4. **Anon/publishable key**: rotate in dashboard, update client env, ship a release.

## Incident steps

1. Confirm scope: `opencode`-independent — check Supabase Logs Explorer and Sentry.
2. Check `app_event_logs` (level=error) and the Edge Function JSON logs by `request_id`.
3. Check `cron.job_run_details` for failed cron jobs.
4. If a bad migration shipped: stop writes if needed, write a corrective migration,
   deploy, backfill.
5. If credentials leaked: rotate (above), then review `audit_logs`.
6. Post-incident: add a regression test, update this runbook.

## Alerts to configure

- Error-rate spike (Sentry).
- Failed reminder batch (cron job failure / non-200 from `send-reminders`).
- Cron job failure (`cron.job_run_details` where `status <> 'succeeded'`).
- Webhook signature failures (`payment-webhook` log `bad_signature`).

## Log retention

- `app_event_logs`: 90 days (pruned by `fam-prune-logs`).
- `audit_logs`: kept ≥ 2 years. Document a log-drain option for platform logs.
