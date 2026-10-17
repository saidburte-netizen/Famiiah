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
| Expo SDK | latest stable at build |
| Next.js | latest stable at build |

## Backend schema

| Item | Version |
|---|---|
| Migrations | `0001`–`0015` |
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
