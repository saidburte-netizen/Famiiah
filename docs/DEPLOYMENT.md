# Deployment (CI/CD)

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | every push / PR | lint, typecheck, unit tests; DB migrate + lint + pgTAP + drift check; admin production build; dependency audit |
| `deploy.yml` | manual (`workflow_dispatch`) or a `v*` tag | deploy DB migrations → Edge Functions → admin → mobile |

## Required repository/environment secrets

Set these under **Settings → Environments** (e.g. `staging`, `production`) so the
`environment:` mapping in `deploy.yml` picks the right values. Only the secrets
for the components you deploy are needed.

| Secret | Used by | Notes |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | db, functions | Supabase personal access token. |
| `SUPABASE_DB_PASSWORD` | db | Database password for the target project. |
| `SUPABASE_PROJECT_ID` | db, functions | Project ref (e.g. `abcdefghijklmnop`). |
| `VERCEL_TOKEN` | admin | Vercel token. |
| `VERCEL_ORG_ID` | admin | From `apps/admin/.vercel/project.json`. |
| `VERCEL_PROJECT_ID` | admin | From `apps/admin/.vercel/project.json`. |
| `EXPO_TOKEN` | mobile | Expo access token (needs `eas init` once per project). |

Edge Function *config* (URLs, provider keys) is set with
`supabase secrets set --project-ref <ref> KEY=value`, not in CI. Relevant keys:
`EXPO_ACCESS_TOKEN` (push delivery from `send-reminders`), `EMAIL_PROVIDER_KEY`
(`invite-member`), and the payment-provider secret used by `payment-webhook`.

## Deploy order

`db → functions → admin → mobile`. Migrations are forward-only; the schema is
never behind the clients. The `functions`/`admin`/`mobile` jobs run even if `db`
is skipped (e.g. deploying only the admin).

## Manual deploy

Actions → **CD** → *Run workflow* → choose `environment` and `components`
(`all`, or a comma list such as `admin,mobile`).

## Release

Push a tag (`git tag v1.0.0 && git push origin v1.0.0`) to build and deploy all
components and cut a GitHub release. Mobile builds run with `--no-wait`; submit
to the stores from the EAS dashboard or by adding `eas submit` to the job.

## First-time setup

1. `pnpm --filter @fam/admin exec vercel link` and commit nothing — copy the
   generated org/project IDs into the `VERCEL_*` secrets.
2. `pnpm --filter @fam/mobile exec eas init` to attach an EAS project ID
   (writes `extra.eas.projectId` into `app.json`).
3. Create the Supabase projects and add the `SUPABASE_*` secrets.

## Android signing & push

- **Keystore**: run `eas credentials` (Android → production) once and either let
  EAS generate a keystore or upload the existing one. If uploading, have these
  ready: the keystore **file**, the **keystore password**, the **key alias** and
  the **key password**. EAS stores them server-side; they are never committed.
- **Push**: delivery needs FCM (Android) and APNs (iOS) credentials uploaded in
  EAS. The app only stores its Expo token via `register_device_token`; there is
  no sender key in this repo. `extra.eas.projectId` (step 2) is required for
  `getExpoPushTokenAsync` — without it, token registration is skipped.
