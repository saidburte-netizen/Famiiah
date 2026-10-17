-- ============================================================================
-- PART 2b — helper smoke test  (should show uid_matches=t, jwt_role_ok=t)
-- ============================================================================
begin;
set local role authenticated;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001', 'aal1');
select (select auth.uid()) = '00000000-0000-0000-0000-00000000a001'::uuid as uid_matches,
       (select auth.jwt() ->> 'role') = 'authenticated'                  as jwt_role_ok,
       (select auth.jwt() ->> 'aal')  = 'aal1'                           as aal_ok;
reset role;
rollback;

