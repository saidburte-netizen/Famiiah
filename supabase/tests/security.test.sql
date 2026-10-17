-- supabase/tests/security.test.sql
-- Regression tests for the 0016 hardening. Invitation tokens must not be
-- readable or replayable by the wrong user, and the privilege-escalation paths
-- must stay closed.
-- Run with: supabase test db
begin;
select plan(8);

-- ---- fixtures (created as postgres, RLS bypassed) ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000e1','authenticated','authenticated',
  'owner@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Owner"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000e2','authenticated','authenticated',
  'staff@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Staff"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000e3','authenticated','authenticated',
  'newcomer@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Newcomer"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000e4','authenticated','authenticated',
  'manager@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Manager"}', now(), now());

insert into organizations (id, name, slug, created_by)
  values ('00000000-0000-0000-0000-0000000000ee','Org E','org-e','00000000-0000-0000-0000-0000000000e1');

insert into organization_members (org_id, user_id, role, status) values
 ('00000000-0000-0000-0000-0000000000ee','00000000-0000-0000-0000-0000000000e1','owner','active'),
 ('00000000-0000-0000-0000-0000000000ee','00000000-0000-0000-0000-0000000000e2','staff','active'),
 ('00000000-0000-0000-0000-0000000000ee','00000000-0000-0000-0000-0000000000e4','manager','active');

insert into invitations (org_id, email, phone, role, token_hash) values
 ('00000000-0000-0000-0000-0000000000ee','newcomer@test.fam', null, 'staff', 'hash-for-newcomer'),
 ('00000000-0000-0000-0000-0000000000ee', null, '+251900000000', 'staff', 'hash-phone-only');

-- ---- act as a staff member ----
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000e2","role":"authenticated","aal":"aal1"}';

select is(
  (select count(*)::int from (select id from invitations) i),
  0,
  'staff member cannot list the org invitations'
);
select throws_ok(
  $$ select token_hash from invitations $$,
  '42501', null,
  'invitation token_hash is not selectable by client roles'
);
select throws_ok(
  $$ select accept_invitation('hash-for-newcomer') $$,
  '42501', null,
  'accept_invitation rejects a caller the invitation was not addressed to'
);

-- ---- act as the invited (unaffiliated) user ----
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000e3","role":"authenticated","aal":"aal1"}';

select lives_ok(
  $$ select accept_invitation('hash-for-newcomer') $$,
  'the invited user can accept their own invitation'
);
select throws_ok(
  $$ select accept_invitation('hash-phone-only') $$,
  '42501', null,
  'a phone-only invitation cannot be claimed by a caller with no matching phone'
);

-- ---- act as a manager, then an owner ----
reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000e4","role":"authenticated","aal":"aal1"}';

select throws_ok(
  $$ select invite_member('00000000-0000-0000-0000-0000000000ee','someone@test.fam', null, 'owner', 'hash-manager') $$,
  '42501', null,
  'a manager cannot invite an owner'
);

reset role;
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated","aal":"aal1"}';

select lives_ok(
  $$ select invite_member('00000000-0000-0000-0000-0000000000ee','successor@test.fam', null, 'owner', 'hash-owner') $$,
  'an owner can invite another owner'
);
select throws_ok(
  $$ select generate_monthly_charges(null) $$,
  '42501', null,
  'cron-only charge generation is not callable by clients'
);

select * from finish();
rollback;
