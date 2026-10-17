# Deployment (CI/CD)

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | every push / PR | lint, typecheck, unit tests; DB migrate + lint + pgTAP + drift check; admin production build; dependency audit |
| `deploy.yml` | manual (`workflow_dispatch`) or a `v*` tag | deploy DB migrations → Edge Functions → mobile (Android/Play) |

CD deploys the backend and the **Android/Play Store** app. The admin web app is
not deployed by CD — host it however you like (CI still typechecks and builds
`apps/admin` on every push).

## Required repository/environment secrets

Set these under **Settings → Environments** (e.g. `staging`, `production`) so the
`environment:` mapping in `deploy.yml` picks the right values. Only the secrets
for the components you deploy are needed.

| Secret | Used by | Notes |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | db, functions | Supabase personal access token. |
| `SUPABASE_DB_PASSWORD` | db | Database password for the target project. |
| `SUPABASE_PROJECT_ID` | db, functions | Project ref (e.g. `abcdefghijklmnop`). |
| `EXPO_TOKEN` | mobile | Expo access token (needs `eas init` once per project). |
| `SUPABASE_URL` | mobile, Flutter CI | Project URL — becomes `EXPO_PUBLIC_SUPABASE_URL` (EAS) and the Flutter `FAM_SUPABASE_URL` `--dart-define`. |
| `SUPABASE_ANON_KEY` | mobile, Flutter CI | Anon/public key — becomes `EXPO_PUBLIC_SUPABASE_ANON_KEY` and the Flutter `FAM_SUPABASE_ANON_KEY` `--dart-define`. |
| `EXPO_PUBLIC_SENTRY_DSN` | mobile (optional) | Sentry DSN for the mobile bundle. |
| `ANDROID_KEYSTORE_BASE64` | mobile | Base64 of the Android upload keystore (PKCS#12 `.keystore`/`.jks`). |
| `ANDROID_KEYSTORE_PASSWORD` | mobile | Keystore (store) password. |
| `ANDROID_KEY_ALIAS` | mobile | Key alias inside the keystore. |
| `ANDROID_KEY_PASSWORD` | mobile | Key password (usually the same as the store password). |

The mobile job accepts either naming for the four signing secrets —
`ANDROID_*` or `KEYSTORE_*` (`ANDROID_KEYSTORE_BASE64 || KEYSTORE_BASE64 ||
KEYSTORE_BASE`, etc.) — so an existing `KEYSTORE_*` set works unchanged. The
Flutter CI workflow reads the same names.

The Flutter CI workflow (`.github/workflows/flutter.yml`) compiles
`SUPABASE_URL` / `SUPABASE_ANON_KEY` into the release APK/AAB with
`--dart-define` (the `FAM_SUPABASE_*` names are accepted too). Unlike the CD
jobs it is **not** scoped to a GitHub *environment*, so it reads **repository**
secrets or variables — environment secrets are not visible to it. It fails with
a `Missing Supabase config` error instead of uploading an app that cannot reach
the backend.

Edge Function *config* (URLs, provider keys) is set with
`supabase secrets set --project-ref <ref> KEY=value`, not in CI. Relevant keys:
`EXPO_ACCESS_TOKEN` (push delivery from `send-reminders`), `EMAIL_PROVIDER_KEY`
(`invite-member`), and the payment-provider secret used by `payment-webhook`.

## Deploy order

`db → functions → mobile`. Migrations are forward-only; the schema is never
behind the clients. The `functions`/`mobile` jobs run even if `db` is skipped
(e.g. deploying only the mobile app).

## Manual deploy

Actions → **CD** → *Run workflow* → choose `environment` and `components`
(`all`, or a comma list such as `functions,mobile`).

## Mobile client configuration

EAS Build runs in the cloud and cannot see this runner's environment, so the
`mobile` job pushes the client config into the EAS project before building:

- `eas.json` sets `"environment": "production"` on the `production` profile (and
  `ci` inherits it), so the cloud build loads the EAS `production` environment.
- The job runs `eas env:set` for `EXPO_PUBLIC_SUPABASE_URL`,
  `EXPO_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_APP_ENV=production` (and
  `EXPO_PUBLIC_SENTRY_DSN` when that secret is set), sourced from the repo
  secrets above.

This requires `EXPO_TOKEN` and a linked EAS project (`extra.eas.projectId` in
`app.json`, written by `eas init`). `EXPO_PUBLIC_*` values are public by design —
they ship inside the client bundle — so `--visibility plaintext` is correct.

## Release

Push a tag (`git tag v1.0.0 && git push origin v1.0.0`) to deploy all components
and cut a GitHub release. Mobile builds run with `--no-wait`, so once CI reports
the build ID, finish publishing from the EAS dashboard or locally:

```
cd apps/mobile
eas submit --platform android --profile production --latest
```

For `eas submit` locally, download a **Google Cloud service account** JSON
(Play Console → API access) to `apps/mobile/play-service-account.json` — that
path is referenced by the `submit` profile in `eas.json` and is gitignored.

## First-time setup

1. `pnpm --filter @fam/mobile exec eas init` to attach an EAS project ID
   (writes `extra.eas.projectId` into `app.json`).
2. Create the Supabase projects and add the `SUPABASE_*` secrets.
3. Add the mobile secrets (`EXPO_TOKEN`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
   the signing secrets). The CD job syncs the EAS environment variables for you.
4. Check the project's **Auth** settings (dashboard → Authentication):
   - **Providers → Email** must be enabled (it is by default). **Phone is not
     required** — the clients collect a phone number as profile data, not as a
     sign-in identifier.
   - **Confirm email**: if it stays on, `signUp` issues no session until the user
     opens the emailed link, and the built-in mailer only delivers to project
     team members (strict hourly limit). Either configure **custom SMTP** for
     production, or turn *Confirm email* off so sign-ups sign in immediately.
     The app handles both: with confirmation on it shows a "confirm your email"
     screen instead of routing into the app.
   - Apply migrations (CD → Run workflow → `components: db`) so
     `handle_new_user()` can store the phone number from the sign-up metadata
     (`0017`).

The admin app is not deployed by CD; if you host it, set
`NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_ANON_KEY` /
`NEXT_PUBLIC_SENTRY_DSN` in the hosting provider.

## Android signing & push

Two supported paths; the mobile job picks automatically:

- **CI-managed (used when `ANDROID_KEYSTORE_BASE64`/`KEYSTORE_BASE64` is set)** —
  the job decodes the keystore and writes `credentials.json` (both gitignored)
  via `apps/mobile/scripts/write-android-credentials.mjs`, then builds with the
  `ci` profile (`credentialsSource: local`, Android). This is the path to use
  when you hold the upload key yourself.
- **EAS-managed**: with no keystore secret present the job builds
  `--profile production`, using credentials EAS holds. Seed them once with
  `eas credentials` (Android → production) — have the keystore **file**, **store
  password**, **key alias** and **key password** ready. They are stored
  server-side and never committed.

Either way the signing key is created once and must be kept: Play rejects a
released app signed with a different key unless you use Play App Signing / key
reset.

- **Push**: delivery needs FCM (Android). The app only stores its Expo token via
  `register_device_token`; there is no sender key in this repo.
  `extra.eas.projectId` (step 1) is required for `getExpoPushTokenAsync` —
  without it, token registration is skipped.
