-- ============================================================================
-- PART 12 — teardown (drops the fam_test schema)
-- ============================================================================
drop schema if exists fam_test cascade;

select 'fam_test schema removed' as name,
       not exists (select 1 from pg_namespace where nspname = 'fam_test') as ok;

