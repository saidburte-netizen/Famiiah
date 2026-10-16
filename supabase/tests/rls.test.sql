-- supabase/tests/rls.test.sql
-- RLS matrix: a user from org A must not read or write org B.
-- Run with: supabase test db
begin;
select plan(12);

-- ---- fixtures (created as postgres, RLS bypassed) ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000a1','authenticated','authenticated',
  'a@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000b1','authenticated','authenticated',
  'b@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"B"}', now(), now());

insert into organizations (id, name, slug, created_by) values
 ('00000000-0000-0000-0000-0000000000aa','Org A','org-a','00000000-0000-0000-0000-0000000000a1'),
 ('00000000-0000-0000-0000-0000000000bb','Org B','org-b','00000000-0000-0000-0000-0000000000b1');

insert into organization_members (org_id, user_id, role, status) values
 ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000000a1','owner','active'),
 ('00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-0000000000b1','owner','active');

insert into properties (id, org_id, name, type) values
 ('00000000-0000-0000-0000-00000000paa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential'),
 ('00000000-0000-0000-0000-00000000pbb1','00000000-0000-0000-0000-0000000000bb','Prop B','residential');

-- ---- act as user A ----
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000a1","role":"authenticated","aal":"aal1"}';

select is((select count(*)::int from properties where id = '00000000-0000-0000-0000-00000000paa1'), 1,
  'A can read its own org property');
select is((select count(*)::int from properties where id = '00000000-0000-0000-0000-00000000pbb1'), 0,
  'A cannot read org B property');
select is((select count(*)::int from organizations where id = '00000000-0000-0000-0000-0000000000bb'), 0,
  'A cannot read org B organization');

-- A cannot insert into org B
select throws_ok($$ insert into properties (org_id, name, type)
  values ('00000000-0000-0000-0000-0000000000bb','Hack','residential') $$,
  '42501', null, 'A cannot insert a property into org B');

-- A can insert into its own org
select lives_ok($$ insert into properties (org_id, name, type)
  values ('00000000-0000-0000-0000-0000000000aa','OK','residential') $$,
  'A can insert a property into its own org');

-- A cannot set is_platform_admin (column privilege)
select throws_ok($$ update profiles set is_platform_admin = true
  where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '42501', null, 'A cannot self-promote to platform admin');

-- A can update its own profile fields
select lives_ok($$ update profiles set full_name = 'AA'
  where id = '00000000-0000-0000-0000-0000000000a1' $$,
  'A can update its own profile');

-- staff cannot write properties (add a staff member to org A and test)
reset role;
insert into organization_members (org_id, user_id, role, status) values
 ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000000b1','staff','active');
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000b1","role":"authenticated","aal":"aal1"}';

select is((select count(*)::int from properties where id = '00000000-0000-0000-0000-00000000paa1'), 1,
  'staff can read org A property');
select throws_ok($$ insert into properties (org_id, name, type)
  values ('00000000-0000-0000-0000-0000000000aa','X','residential') $$,
  '42501', null, 'staff cannot insert properties');

-- audit_logs append-only: no client insert path
select throws_ok($$ insert into audit_logs (action, table_name)
  values ('x','y') $$, '42501', null, 'clients cannot write audit_logs');

-- app_event_logs insert only via RPC: direct insert denied
select throws_ok($$ insert into app_event_logs (level, source, message)
  values ('info','mobile','hi') $$, '42501', null, 'clients cannot directly insert app_event_logs');

select * from finish();
rollback;
