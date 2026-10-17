# Famiiah regression suite (run part by part)

Split from `../regression-suite.sql`. Run the files in this order:

1. `part-01-preflight.sql` — read-only schema inventory
2. `part-02-install-helpers.sql` — **commits** (creates the `fam_test` schema)
3. `part-02b-helper-smoke.sql` — helper smoke test
4. `part-03-constraints-triggers-audit.sql`
5. `part-04-rls-isolation.sql`
6. `part-05-grants-lockdown.sql`
7. `part-06-org-members-invitations.sql`
8. `part-07-lease-lifecycle-charges.sql`
9. `part-08-payments.sql`
10. `part-09-lists-dashboard-reports.sql`
11. `part-10-stock-notifications.sql`
12. `part-11-platform-admin-version.sql`
13. `part-12-teardown.sql` — drops the `fam_test` schema

Only Part 2 commits; Parts 1 and 2b-11 wrap their work in `begin; ... rollback;`,
so they are safe to re-run. Part 12 cleans up the helpers.
