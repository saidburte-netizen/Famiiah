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
| `ANDROID_KEYSTORE_BASE64` | mobile | Base64 of the Android upload keystore (PKCS#12 `.keystore`/`.jks`). |
| `ANDROID_KEYSTORE_PASSWORD` | mobile | Keystore (store) password. |
| `ANDROID_KEY_ALIAS` | mobile | Key alias inside the keystore. |
| `ANDROID_KEY_PASSWORD` | mobile | Key password (usually the same as the store password). |

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

Two supported paths; the mobile job picks automatically:

- **CI-managed (used when `ANDROID_KEYSTORE_BASE64` is set)** — the job decodes
  the keystore and writes `credentials.json` (both gitignored) via
  `apps/mobile/scripts/write-android-credentials.mjs`, then builds with the `ci`
  profile (`credentialsSource: local`, Android only). Add the four
  `ANDROID_*` secrets above to the target environment. This is the path to use
  when you hold the upload key yourself.
- **EAS-managed**: with no keystore secret present the job builds
  `--profile production --platform all`, using credentials EAS holds. Seed them
  once with `eas credentials` (Android → production) — have the keystore
  **file**, **store password**, **key alias** and **key password** ready. They
  are stored server-side and never committed.

Either way the signing key is created once and must be kept: Play rejects a
released app signed with a different key unless you use Play App Signing / key
reset.

- **Push**: delivery needs FCM (Android) and APNs (iOS) credentials uploaded in
  EAS. The app only stores its Expo token via `register_device_token`; there is
  no sender key in this repo. `extra.eas.projectId` (step 2) is required for
  `getExpoPushTokenAsync` — without it, token registration is skipped.
