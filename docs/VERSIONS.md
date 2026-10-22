# Versions

Runtime and library versions. Pin exact versions in lockfiles; record the
resolved versions here at build time.

## Runtimes

| Runtime | Version |
|---|---|
| Node.js | 22.x |
| pnpm | 12.x (workspace) |
| PostgreSQL | 15.x (Supabase local + hosted) |
| Deno (Edge Functions) | Supabase-managed |
| Flutter | `stable` channel (latest at build, resolved by CI) |
| Dart SDK | `^3.5.0` (`apps/mobile_flutter/pubspec.yaml`) |
| Expo SDK | latest stable at build |
| Next.js | latest stable at build |

## App versions

| App | Version | Source |
|---|---|---|
| Expo mobile | 1.0.0 | `apps/mobile/app.json` (`expo.version`) |
| Flutter mobile | 1.2.0+12 | `apps/mobile_flutter/pubspec.yaml` (`version`) |
| Android application id | `com.fami.myapp` | `.github/workflows/flutter.yml`, `tool/setup_android.sh` |

## Backend schema

| Item | Version |
|---|---|
| Migrations | `0001`–`0020` |
| API/RPC contract | `v1` |
| Database tag | `db-<timestamp>` |

## Shared library (`@fam/shared`)

| Package | Range |
|---|---|
| zod | ^3.25 |
| typescript | ^5.9 |

## Apps

| Package | Range | Notes |
|---|---|---|
| @supabase/supabase-js | ^2.45 | mobile + admin |
| @supabase/ssr | ^0.12 | admin; older `0.6.x` d.ts imports a removed `dist/module/lib/types` path and breaks row inference |
| @tanstack/react-query | ^5.81 | mobile |
| expo | ^53 | mobile SDK |
| expo-router | ^5.1 | mobile routing |
| next | ^15.4 | admin |
| react / react-native | 19.1 / 0.79 | mobile |

### Flutter mobile (`apps/mobile_flutter`)

| Package | Range | Notes |
|---|---|---|
| flutter_secure_storage | ^11.2.0 | session + invitation tokens (Keystore / Keychain), plain-prefs fallback when the Keystore throws |
| shared_preferences | ^2.3.0 | session fallback store (same place `supabase_flutter` keeps it by default) |
| flutter_riverpod | ^2.6.1 | state |
| go_router | ^14.6.2 | routing |
| supabase_flutter | ^2.8.4 | resolves to the newest 2.x |
| google_fonts | ^6.2.1 | Manrope / Playfair, fetched at runtime with a fallback |
| package_info_plus | ^10.2.2 | version gate |
| intl | ^0.19.0 | money / dates |

## Tooling

| Package | Range | Notes |
|---|---|---|
| turbo | ^2.5 | workspace task runner |
| eslint-plugin-react-hooks | ^7.1 | mobile; only the classic `rules-of-hooks` + `exhaustive-deps` rules are enabled |

## How to update

1. Bump dependency, run `pnpm install`, commit `pnpm-lock.yaml`.
2. Record the resolved version here.
3. For the DB, add a new migration (never edit an applied one) and tag `db-<timestamp>`.
4. For releases, tag `mobile-vX.Y.Z` / `admin-vX.Y.Z` and note it in `CHANGELOG.md`.
