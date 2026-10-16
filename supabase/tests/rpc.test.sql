-- supabase/tests/rpc.test.sql
-- Core RPC invariants: record_payment allocation/idempotency/void,
-- charge generation idempotency, unit status sync, negative stock guard,
-- last-owner protection.
begin;
select plan(18);

-- ---- fixtures ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1','authenticated','authenticated',
        'c@test.fam', crypt('Password123', gen_salt('bf')), now(), '{}', '{"full_name":"C"}', now(), now());
insert into organizations (id, name, slug, created_by)
  values ('00000000-0000-0000-0000-0000000000cc','Org C','org-c','00000000-0000-0000-0000-0000000000c1');
insert into organization_members (org_id, user_id, role, status)
  values ('00000000-0000-0000-0000-0000000000cc','00000000-0000-0000-0000-0000000000c1','owner','active');
insert into properties (id, org_id, name, type)
  values ('00000000-0000-0000-0000-00000000pcc1','00000000-0000-0000-0000-0000000000cc','Prop C','residential');
insert into units (id, org_id, property_id, code, monthly_rent)
  values ('00000000-0000-0000-0000-00000000ucc1','00000000-0000-0000-0000-0000000000cc','00000000-0000-0000-0000-00000000pcc1','C-01', 1000);

set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated","aal":"aal1"}';

-- create tenant + lease via RPC
select lives_ok($$ select public.create_tenant_with_lease(
  '00000000-0000-0000-0000-0000000000cc',
  '{"fullName":"Tenant C","phone":"+251911000000"}'::jsonb,
  '00000000-0000-0000-0000-00000000ucc1',
  current_date, (current_date + interval '6 months')::date, 1000, 1000, 5, 5) $$,
  'create_tenant_with_lease succeeds');

select is((select status::text from units where id = '00000000-0000-0000-0000-00000000ucc1'), 'rented',
  'unit becomes rented after lease');

-- a second active lease on the same unit fails
select throws_ok($$ select public.assign_tenant_to_unit(
  '00000000-0000-0000-0000-00000000ucc1',
  (select id from tenants limit 1), current_date, null, 1000, 0, 5, 5) $$,
  '23505', 'unit_not_vacant', 'cannot double-book an occupied unit');

-- generate charges (idempotent)
select is(public.generate_monthly_charges('00000000-0000-0000-0000-0000000000cc'), 1,
  'one charge generated for the active lease');
select is(public.generate_monthly_charges('00000000-0000-0000-0000-0000000000cc'), 0,
  'charge generation is idempotent');

-- partial payment
select lives_ok($$ select public.record_payment(
  (select id from leases limit 1), 400, 'cash', 'R1', now(), null, 'idem-partial-1') $$,
  'partial payment recorded');
select is((select amount_paid from rent_charges limit 1), 400::numeric, 'charge shows partial paid');
select is((select status::text from rent_charges limit 1), 'partial', 'charge status partial');

-- idempotent retry returns same payment, does not double-allocate
select is((select count(*)::int from public.record_payment(
  (select id from leases limit 1), 400, 'cash', 'R1', now(), null, 'idem-partial-1')), 1,
  'idempotent retry returns a single payment');
select is((select count(*)::int from payments), 1, 'no duplicate payment created');

-- complete the payment
select lives_ok($$ select public.record_payment(
  (select id from leases limit 1), 600, 'cash', 'R2', now(), null, 'idem-partial-2') $$,
  'second payment recorded');
select is((select status::text from rent_charges limit 1), 'paid', 'charge fully paid');

-- over-payment leaves unallocated credit
select lives_ok($$ select public.record_payment(
  (select id from leases limit 1), 500, 'cash', 'R3', now(), null, 'idem-over-1') $$,
  'over-payment recorded');
select is((select unallocated_amount from payments where reference = 'R3'), 500::numeric,
  'over-payment left as unallocated credit');

-- void reverses allocations
select lives_ok($$ select public.void_payment(
  (select id from payments where reference = 'R2'), 'customer error') $$,
  'void payment succeeds');
select is((select status::text from rent_charges limit 1), 'partial', 'charge reverts to partial after void');
select isnt((select voided_at from payments where reference = 'R2'), null, 'void stamped');

-- stock cannot go negative
select lives_ok($$ insert into stock_items (org_id, name, quantity) 
  values ('00000000-0000-0000-0000-0000000000cc','Widget', 5) $$, 'stock item created');
select throws_ok($$ select public.stock_adjust(
  (select id from stock_items where name = 'Widget'), 'out', 10, 'too many') $$,
  '22023', 'negative_balance', 'stock adjust rejects negative balance');

-- last-owner protection
select throws_ok($$ select public.admin_set_member_role(
  '00000000-0000-0000-0000-0000000000cc','00000000-0000-0000-0000-0000000000c1','staff') $$,
  '23505', 'cannot_demote_last_owner', 'cannot demote the last owner');

select * from finish();
rollback;
