-- supabase/tests/user_delete.test.sql
-- Deleting an account from the Supabase dashboard must succeed even when that
-- user authored real records, and those records must survive without their
-- actor. Before migration 0019 the audit columns (organizations.created_by,
-- invitations.invited_by, payments.received_by / voided_by,
-- stock_movements.performed_by) referenced auth.users with NO ACTION, so
-- Postgres refused the delete with "Database error deleting user".
-- Run with: supabase test db
begin;
select plan(7);

-- ---- a user who has done real work ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000d1','authenticated',
          'authenticated','author@test.fam','x', now(), '{"full_name":"Author"}'::jsonb);

-- An organization created by the user. (The audit column lives here, not on
-- properties: properties has no created_by.)
insert into public.organizations (id, name, slug, created_by)
  values ('00000000-0000-0000-0000-0000000000e1','Author Org','author-org',
          '00000000-0000-0000-0000-0000000000d1');

-- A property in that org, so the delete also exercises org-owned rows.
insert into public.properties (id, org_id, name, type)
  values ('00000000-0000-0000-0000-0000000000e2','00000000-0000-0000-0000-0000000000e1','Tower',
          'residential');

-- An invitation sent by the user.
insert into public.invitations (id, org_id, email, token_hash, invited_by)
  values ('00000000-0000-0000-0000-0000000000e3','00000000-0000-0000-0000-0000000000e1','invitee@test.fam',
          'hash-author','00000000-0000-0000-0000-0000000000d1');

-- A tenant + payment received and voided by the user. payments.tenant_id is
-- ON DELETE RESTRICT, so the tenant keeps the payment alive too.
insert into public.tenants (id, org_id, full_name)
  values ('00000000-0000-0000-0000-0000000000e4','00000000-0000-0000-0000-0000000000e1','Tenant');
insert into public.payments (id, org_id, tenant_id, amount, method, received_by, voided_at, voided_by, void_reason)
  values ('00000000-0000-0000-0000-0000000000e5','00000000-0000-0000-0000-0000000000e1',
          '00000000-0000-0000-0000-0000000000e4', 1000, 'cash',
          '00000000-0000-0000-0000-0000000000d1', now(),
          '00000000-0000-0000-0000-0000000000d1', 'mistake');

-- A stock movement performed by the user.
insert into public.stock_items (id, org_id, name)
  values ('00000000-0000-0000-0000-0000000000e6','00000000-0000-0000-0000-0000000000e1','Paint');
insert into public.stock_movements (id, org_id, item_id, type, quantity, balance_after, performed_by)
  values ('00000000-0000-0000-0000-0000000000e7','00000000-0000-0000-0000-0000000000e1',
          '00000000-0000-0000-0000-0000000000e6','in', 10, 10,
          '00000000-0000-0000-0000-0000000000d1');

-- ---- the delete that used to fail ----
delete from auth.users where id = '00000000-0000-0000-0000-0000000000d1';

select is(
  (select count(*) from auth.users where id = '00000000-0000-0000-0000-0000000000d1'),
  0::bigint,
  'the account is gone');

-- The owned rows cascade away with the profile.
select is(
  (select count(*) from public.profiles where id = '00000000-0000-0000-0000-0000000000d1'),
  0::bigint,
  'the profile cascades on delete');

-- The authored records survive, with their actor nulled out.
select is(
  (select created_by from public.organizations where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'an organization survives with created_by cleared');

select is(
  (select invited_by from public.invitations where id = '00000000-0000-0000-0000-0000000000e3'),
  null,
  'an invitation survives with invited_by cleared');

select is(
  (select received_by from public.payments where id = '00000000-0000-0000-0000-0000000000e5'),
  null,
  'a payment survives with received_by cleared');

select is(
  (select voided_by from public.payments where id = '00000000-0000-0000-0000-0000000000e5'),
  null,
  'a payment survives with voided_by cleared');

select is(
  (select performed_by from public.stock_movements where id = '00000000-0000-0000-0000-0000000000e7'),
  null,
  'a stock movement survives with performed_by cleared');

select * from finish();
rollback;
