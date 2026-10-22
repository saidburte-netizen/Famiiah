-- supabase/tests/archive.test.sql
-- Archive/restore invariants (migration 0020).
--
-- Archiving is the only delete the app has: RLS has no delete policy on
-- properties/units/tenants/stock_items, and every list filters `deleted_at is
-- null`. These RPCs must therefore (a) be authorised to owner/manager only,
-- (b) refuse while a live dependant still points at the record, and (c) be
-- reversible with restore.
-- Run with: supabase test db
begin;
select plan(13);

-- ---- fixtures: one org, an owner and a plain staff member ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000f1','authenticated','authenticated',
        'owner@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Owner"}', now(), now()),
       ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000f2','authenticated','authenticated',
        'staff@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"Staff"}', now(), now());

insert into organizations (id, name, slug, created_by)
  values ('00000000-0000-0000-0000-0000000000f0','Archive Org','archive-org','00000000-0000-0000-0000-0000000000f1');
insert into organization_members (org_id, user_id, role, status)
  values ('00000000-0000-0000-0000-0000000000f0','00000000-0000-0000-0000-0000000000f1','owner','active'),
         ('00000000-0000-0000-0000-0000000000f0','00000000-0000-0000-0000-0000000000f2','staff','active');

insert into properties (id, org_id, name, type)
  values ('00000000-0000-0000-0000-00000000fff1','00000000-0000-0000-0000-0000000000f0','Archive Prop','residential');
insert into units (id, org_id, property_id, code, monthly_rent)
  values ('00000000-0000-0000-0000-00000000fee1','00000000-0000-0000-0000-0000000000f0','00000000-0000-0000-0000-00000000fff1','A-01', 1000),
         ('00000000-0000-0000-0000-00000000fee2','00000000-0000-0000-0000-0000000000f0','00000000-0000-0000-0000-00000000fff1','A-02', 1000);
insert into tenants (id, org_id, full_name)
  values ('00000000-0000-0000-0000-00000000fed1','00000000-0000-0000-0000-0000000000f0','Archive Tenant');
insert into stock_items (id, org_id, sku, name, quantity)
  values ('00000000-0000-0000-0000-00000000fec1','00000000-0000-0000-0000-0000000000f0','ARC-1','Archive Item', 0),
         ('00000000-0000-0000-0000-00000000fec2','00000000-0000-0000-0000-0000000000f0','ARC-2','Stocked Item', 5);

-- an active lease on A-01 in the prop
insert into leases (id, org_id, unit_id, tenant_id, start_date, monthly_rent, status)
  values ('00000000-0000-0000-0000-00000000feb1','00000000-0000-0000-0000-0000000000f0',
          '00000000-0000-0000-0000-00000000fee1','00000000-0000-0000-0000-00000000fed1',
          current_date, 1000, 'active');

-- ---- owner ----
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000f1","role":"authenticated","aal":"aal1"}';

-- a property with a unit is refused
select throws_ok(
  $$ select public.archive_property('00000000-0000-0000-0000-00000000fff1') $$,
  '23503', null, 'a property that still has units cannot be archived');

-- a unit with an active lease is refused
select throws_ok(
  $$ select public.archive_unit('00000000-0000-0000-0000-00000000fee1') $$,
  '23503', null, 'a unit with an active lease cannot be archived');

-- a tenant with an active lease is refused
select throws_ok(
  $$ select public.archive_tenant('00000000-0000-0000-0000-00000000fed1') $$,
  '23503', null, 'a tenant with an active lease cannot be archived');

-- a stocked item is refused
select throws_ok(
  $$ select public.archive_stock_item('00000000-0000-0000-0000-00000000fec2') $$,
  '23503', null, 'a stock item with quantity on hand cannot be archived');

-- an empty, unleased unit archives, and disappears from list_units
select lives_ok(
  $$ select public.archive_unit('00000000-0000-0000-0000-00000000fee2') $$,
  'a vacant unit archives');
select is(
  (select count(*) from units where id = '00000000-0000-0000-0000-00000000fee2' and deleted_at is not null),
  1::bigint, 'archive sets deleted_at');
select is(
  (select count(*) from public.list_units('00000000-0000-0000-0000-00000000fff1', null, null, 50, 0)
     where code = 'A-02'),
  0::bigint, 'an archived unit is hidden from list_units');

-- an empty, unrented stock item archives
select lives_ok(
  $$ select public.archive_stock_item('00000000-0000-0000-0000-00000000fec1') $$,
  'a zero-quantity stock item archives');
select is(
  (select count(*) from public.list_low_stock('00000000-0000-0000-0000-0000000000f0')),
  0::bigint, 'an archived item is hidden from list_low_stock');

-- restore brings it back
select lives_ok(
  $$ select public.restore_unit('00000000-0000-0000-0000-00000000fee2') $$,
  'restore clears deleted_at');
select is(
  (select count(*) from units where id = '00000000-0000-0000-0000-00000000fee2' and deleted_at is null),
  1::bigint, 'restored unit is live again');

-- archiving a missing record is a clean not-found, not a silent no-op
select throws_ok(
  $$ select public.archive_unit('00000000-0000-0000-0000-0000000000aa') $$,
  'P0002', null, 'archiving an unknown unit reports not_found');

-- ---- staff may not archive ----
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000f2","role":"authenticated","aal":"aal1"}';
select throws_ok(
  $$ select public.archive_unit('00000000-0000-0000-0000-00000000fee2') $$,
  '42501', null, 'staff cannot archive');

select * from finish();
rollback;
