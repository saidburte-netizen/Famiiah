-- ============================================================================
-- Fam — manual SQL regression suite
-- ============================================================================
-- HOW TO RUN (Supabase SQL editor or psql, as the `postgres` role):
--   * Part 1  : preflight / schema inventory            (read-only)
--   * Part 2  : install the fam_test helpers            (COMMITS - run once)
--   * Part 2b : smoke-test the helpers
--   * Part 3  : constraints, triggers, auditing
--   * Part 4  : RLS isolation and role capabilities
--   * Part 5  : grants / privilege lockdown
--   * Part 6  : org, member and invitation RPCs
--   * Part 7  : lease lifecycle and charge generation
--   * Part 8  : payments (record / allocate / void)
--   * Part 9  : lists, dashboard and reports
--   * Part 10 : stock, notifications, devices, client logs
--   * Part 11 : platform-admin RPCs and the version gate
--   * Part 12 : teardown (drops the fam_test schema)
--
-- Each part from 3..11 is wrapped in `begin; ... rollback;` so it leaves no
-- data behind and is safe to re-run. Only Part 2 commits (it creates the
-- helper schema/functions) and Part 12 removes it again.
--
-- Every grid that ends with columns (name, ok, detail) is a CHECK GRID:
-- every row must read result = PASS. If a part raises an error, run
-- `rollback;` once before retrying that part.
--
-- Parts 2..11 need the helper functions from Part 2 to already exist.
-- ============================================================================


-- ============================================================================
-- PART 1 — preflight / schema inventory  (read-only)
-- ============================================================================
begin;

with c as (
  select 'server major version >= 15' as name,
         (current_setting('server_version_num')::int >= 150000) as ok,
         current_setting('server_version') as detail
  union all
  select 'auth schema present',
         exists (select 1 from pg_namespace where nspname = 'auth'), null
  union all
  select 'storage schema present',
         exists (select 1 from pg_namespace where nspname = 'storage'), null
  union all
  select 'extensions pg_trgm + pgcrypto installed',
         (select count(*) from pg_extension where extname in ('pg_trgm','pgcrypto')) = 2,
         (select string_agg(extname, ', ' order by extname) from pg_extension)
  union all
  select 'all 22 public tables exist',
         (select count(*) from pg_class cl join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r'
             and c.relname in ('profiles','organizations','organization_members','invitations',
               'properties','units','tenants','leases','org_counters','rent_charges','payments',
               'payment_allocations','stock_items','stock_movements','stock_rentals',
               'maintenance_requests','notifications','device_tokens','audit_logs',
               'app_event_logs','app_versions','feature_flags')) = 22,
         (select count(*)::text || ' tables in public'
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r')
  union all
  select 'RLS enabled on every public table',
         not exists (
           select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
         (select string_agg(c.relname, ', ' order by c.relname)
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity)
  union all
  select 'storage buckets (5)',
         (select count(*) from storage.buckets
           where id in ('property-images','tenant-documents','lease-documents','receipts','avatars')) = 5,
         (select string_agg(id, ', ' order by id) from storage.buckets)
  union all
  select 'realtime publication lists 4 tables',
         (select count(*) from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'
             and tablename in ('rent_charges','payments','notifications','stock_items')) = 4,
         null
  union all
  select 'updated_at triggers installed (11)',
         (select count(*) from pg_trigger where not tgisinternal and tgname like 'set_updated_at_%') = 11,
         (select count(*)::text from pg_trigger where not tgisinternal and tgname like 'set_updated_at_%')
  union all
  select 'audit triggers installed (11)',
         (select count(*) from pg_trigger where not tgisinternal and tgname like 'audit_%') = 11,
         (select count(*)::text from pg_trigger where not tgisinternal and tgname like 'audit_%')
  union all
  select 'core RPCs present (7)',
         (select count(distinct proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public'
             and proname in ('record_payment','void_payment','dashboard_summary','stock_adjust',
                             'create_organization','check_app_version','admin_list_members')) = 7,
         null
)
select name, case when ok then 'PASS' else 'FAIL' end as result, detail
from c order by ok, name;

rollback;


-- ============================================================================
-- PART 2 — install the fam_test helpers   (THIS PART COMMITS — run once)
-- ============================================================================
create schema if not exists fam_test;

-- set the JWT claims used by auth.uid() / auth.jwt() for the current transaction
create or replace function fam_test.set_jwt(
  p_uid uuid, p_aal text default 'aal1', p_role text default 'authenticated')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid::text, 'role', p_role, 'aal', p_aal)::text, true);
end $$;

-- true when p_sql raises (optionally a specific SQLSTATE). Runs as the CALLER,
-- so RLS and column privileges apply.
create or replace function fam_test.raises(p_sql text, p_state text default null)
returns boolean language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    return p_state is null or sqlstate = p_state;
  end;
  return false;
end $$;

-- the SQLSTATE: message text of whatever p_sql raises, or NULL if it succeeds.
create or replace function fam_test.raise_error(p_sql text)
returns text language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    return sqlstate || ': ' || sqlerrm;
  end;
  return null;
end $$;

-- row count of a SELECT, executed as the CALLER (so RLS applies).
create or replace function fam_test.num(p_sql text)
returns bigint language plpgsql as $$
declare v bigint;
begin
  execute 'select count(*) from (' || p_sql || ') q' into v;
  return v;
end $$;

grant usage on schema fam_test to authenticated;
grant execute on function fam_test.raises(text, text)      to authenticated;
grant execute on function fam_test.raise_error(text)        to authenticated;
grant execute on function fam_test.num(text)                to authenticated;
grant execute on function fam_test.set_jwt(uuid, text, text) to authenticated;

select 'fam_test helpers installed' as check, count(*) as functions
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'fam_test';


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


-- ============================================================================
-- PART 3 — constraints, triggers and auditing
-- ============================================================================
begin;

-- ---- fixtures (as postgres; RLS bypassed) ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
        'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}',
        '{"full_name":"Owner A"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by, default_billing_day, default_grace_days)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-reg','00000000-0000-0000-0000-00000000a001',5,5)
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status)
values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent)
values ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000aaa1','A-01',5000)
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent)
values ('00000000-0000-0000-0000-00000000ddd2','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000aaa1','A-02',5000)
on conflict (id) do nothing;

insert into tenants (id, org_id, full_name)
values ('00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000000aa','Tenant A')
on conflict (id) do nothing;

-- active lease => sync_unit_status should mark the unit rented
insert into leases (id, org_id, unit_id, tenant_id, start_date, end_date, monthly_rent,
                    billing_day, grace_days, status)
values ('00000000-0000-0000-0000-0000000f0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-00000000eee1',
        current_date, (current_date + interval '12 months')::date, 5000, 1, 5, 'active')
on conflict (id) do nothing;

-- one charge + two payments (receipt numbers are assigned by trigger)
insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, status)
values ('00000000-0000-0000-0000-0000000e0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-0000000f0001',
        date_trunc('month', current_date)::date,
        (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
        date_trunc('month', current_date)::date, 5000, 'pending')
on conflict (id) do nothing;

insert into payments (id, org_id, tenant_id, lease_id, amount, method, reference)
values ('00000000-0000-0000-0000-0000000c0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000f0001',100,'cash','reg-1');

insert into payments (id, org_id, tenant_id, lease_id, amount, method, reference)
values ('00000000-0000-0000-0000-0000000c0002','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000f0001',100,'cash','reg-2');

-- ---- checks ----
select name, case when ok then 'PASS' else 'FAIL' end as result, detail
from (
  select 'handle_new_user created a profile' as name,
         (select count(*) = 1 from profiles where id = '00000000-0000-0000-0000-00000000a001') as ok,
         null::text as detail
  union all
  select 'sync_unit_status marks unit rented on active lease',
         (select status = 'rented' from units where id = '00000000-0000-0000-0000-00000000ddd1'), null
  union all
  select 'assign_receipt_no produced RCP-<year>-000001',
         (select receipt_no = 'RCP-' || to_char(now(),'YYYY') || '-000001'
            from payments where id = '00000000-0000-0000-0000-0000000c0001'),
         (select receipt_no from payments where id = '00000000-0000-0000-0000-0000000c0001')
  union all
  select 'receipt numbers increment per org',
         (select receipt_no = 'RCP-' || to_char(now(),'YYYY') || '-000002'
            from payments where id = '00000000-0000-0000-0000-0000000c0002'),
         (select receipt_no from payments where id = '00000000-0000-0000-0000-0000000c0002')
  union all
  select 'receipt number matches expected pattern',
         (select receipt_no ~ '^RCP-\d{4}-\d{6}$' from payments where id = '00000000-0000-0000-0000-0000000c0001'), null
  union all
  select 'audit_row_change logged the property insert',
         (select count(*) >= 1 from audit_logs
           where table_name = 'properties'
             and record_id = '00000000-0000-0000-0000-00000000aaa1' and action = 'INSERT'), null
  union all
  select 'organizations.slug is unique',
         fam_test.raises($sql$ insert into organizations (name, slug) values ('X','org-a-reg') $sql$,
                         '23505'), null
  union all
  select 'units (property_id, code) is unique',
         fam_test.raises($sql$ insert into units (org_id, property_id, code)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000aaa1','A-01') $sql$, '23505'), null
  union all
  select 'one active lease per unit is enforced',
         fam_test.raises($sql$ insert into leases (org_id, unit_id, tenant_id, start_date, monthly_rent, status)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000ddd1',
                                        '00000000-0000-0000-0000-00000000eee1', current_date, 1000, 'active') $sql$,
                         '23505'), null
  union all
  select 'units.monthly_rent cannot be negative',
         fam_test.raises($sql$ insert into units (org_id, property_id, code, monthly_rent)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000aaa1','A-99',-1) $sql$, '23514'), null
  union all
  select 'rent_charges (lease_id, period_start) is unique',
         fam_test.raises($sql$ insert into rent_charges (org_id, lease_id, period_start, period_end, due_date, amount)
                                select '00000000-0000-0000-0000-0000000000aa',
                                       '00000000-0000-0000-0000-0000000f0001',
                                       period_start, period_end, due_date, 1
                                  from rent_charges where id = '00000000-0000-0000-0000-0000000e0001' $sql$,
                         '23505'), null
  union all
  select 'rent_charges.amount cannot be negative',
         fam_test.raises($sql$ insert into rent_charges (org_id, lease_id, period_start, period_end, due_date, amount)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-0000000f0001',
                                        (date_trunc('month', current_date) + interval '1 month')::date,
                                        (date_trunc('month', current_date) + interval '2 month - 1 day')::date,
                                        current_date, -1) $sql$, '23514'), null
  union all
  select 'payments.amount must be > 0',
         fam_test.raises($sql$ insert into payments (org_id, tenant_id, amount, method)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000eee1', 0, 'cash') $sql$, '23514'), null
  union all
  select 'payments (org_id, receipt_no) is unique',
         fam_test.raises($sql$
           insert into payments (org_id, tenant_id, amount, method, receipt_no)
           values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000eee1',10,'cash','RCP-DUP');
           insert into payments (org_id, tenant_id, amount, method, receipt_no)
           values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000eee1',10,'cash','RCP-DUP') $sql$,
                         '23505'), null
  union all
  select 'payments (org_id, idempotency_key) is unique',
         fam_test.raises($sql$
           insert into payments (org_id, tenant_id, amount, method, idempotency_key)
           values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000eee1',10,'cash','dup-key');
           insert into payments (org_id, tenant_id, amount, method, idempotency_key)
           values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000eee1',10,'cash','dup-key') $sql$,
                         '23505'), null
  union all
  select 'stock_items.quantity cannot be negative',
         fam_test.raises($sql$ insert into stock_items (org_id, name, quantity)
                                values ('00000000-0000-0000-0000-0000000000aa','neg',-1) $sql$, '23514'), null
  union all
  select 'app_versions.version must be x.y.z',
         fam_test.raises($sql$ insert into app_versions (platform, version, min_supported_version)
                                values ('android','1.0','1.0.0') $sql$, '23514'), null
  union all
  select 'leases.end_date cannot precede start_date',
         fam_test.raises($sql$ insert into leases (org_id, unit_id, tenant_id, start_date, end_date, monthly_rent)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000ddd2',
                                        '00000000-0000-0000-0000-00000000eee1',
                                        current_date, current_date - 1, 1000) $sql$, '23514'), null
  union all
  select 'organizations.default_billing_day must be 1..28',
         fam_test.raises($sql$ insert into organizations (name, slug, default_billing_day)
                                values ('B','bad-billing-reg',30) $sql$, '23514'), null
) c
order by ok, name;

rollback;


-- ============================================================================
-- PART 4 — RLS isolation and role capabilities
-- ============================================================================
begin;

-- ---- fixtures (as postgres) ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
       crypt('Password123', gen_salt('bf')), now(), '{}', jsonb_build_object('full_name', u.nm), now(), now()
  from (values
    ('00000000-0000-0000-0000-00000000a001'::uuid,'owner.a@fam.test','Owner A'),
    ('00000000-0000-0000-0000-00000000a002'::uuid,'mgr.a@fam.test','Manager A'),
    ('00000000-0000-0000-0000-00000000a003'::uuid,'staff.a@fam.test','Staff A'),
    ('00000000-0000-0000-0000-00000000a004'::uuid,'viewer.a@fam.test','Viewer A'),
    ('00000000-0000-0000-0000-00000000b001'::uuid,'owner.b@fam.test','Owner B'),
    ('00000000-0000-0000-0000-00000000c001'::uuid,'platform@fam.test','Platform Admin'),
    ('00000000-0000-0000-0000-00000000d001'::uuid,'tenant.i@fam.test','Tenant I')
  ) u(id,email,nm)
on conflict (id) do nothing;

-- promote the platform admin (only the service role / postgres may do this)
update profiles set is_platform_admin = true where id = '00000000-0000-0000-0000-00000000c001';

insert into organizations (id, name, slug, created_by) values
  ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-rls','00000000-0000-0000-0000-00000000a001'),
  ('00000000-0000-0000-0000-0000000000bb','Org B','org-b-rls','00000000-0000-0000-0000-00000000b001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a002','manager','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','staff','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a004','viewer','active'),
  ('00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-00000000b001','owner','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type) values
  ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential'),
  ('00000000-0000-0000-0000-00000000bbb1','00000000-0000-0000-0000-0000000000bb','Prop B','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent) values
  ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-01',1000),
  ('00000000-0000-0000-0000-00000000ddd3','00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-00000000bbb1','B-01',1000)
on conflict (id) do nothing;

insert into tenants (id, org_id, full_name, user_id) values
  ('00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000000aa','Tenant A','00000000-0000-0000-0000-00000000d001'),
  ('00000000-0000-0000-0000-00000000eee2','00000000-0000-0000-0000-0000000000bb','Tenant B',null)
on conflict (id) do nothing;

insert into leases (id, org_id, unit_id, tenant_id, start_date, monthly_rent, status) values
  ('00000000-0000-0000-0000-0000000f0001','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-00000000eee1',current_date,1000,'active'),
  ('00000000-0000-0000-0000-0000000f0002','00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-00000000ddd3','00000000-0000-0000-0000-00000000eee2',current_date,1000,'active')
on conflict (id) do nothing;

insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, status) values
  ('00000000-0000-0000-0000-0000000e0001','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000f0001',
   date_trunc('month',current_date)::date,(date_trunc('month',current_date)+interval '1 month - 1 day')::date,
   date_trunc('month',current_date)::date,1000,'pending'),
  ('00000000-0000-0000-0000-0000000e0002','00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-0000000f0002',
   date_trunc('month',current_date)::date,(date_trunc('month',current_date)+interval '1 month - 1 day')::date,
   date_trunc('month',current_date)::date,1000,'pending')
on conflict (id) do nothing;

insert into payments (id, org_id, tenant_id, lease_id, amount, method) values
  ('00000000-0000-0000-0000-0000000c0001','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000f0001',100,'cash')
on conflict (id) do nothing;

insert into payment_allocations (payment_id, charge_id, amount)
values ('00000000-0000-0000-0000-0000000c0001','00000000-0000-0000-0000-0000000e0001',100)
on conflict do nothing;

insert into notifications (id, org_id, user_id, channel, title)
values ('00000000-0000-0000-0000-00000000f1f1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','in_app','for staff')
on conflict (id) do nothing;
insert into notifications (id, org_id, user_id, channel, title)
values ('00000000-0000-0000-0000-00000000f2f2','00000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-00000000b001','in_app','for owner B')
on conflict (id) do nothing;

insert into device_tokens (id, user_id, token, platform)
values ('00000000-0000-0000-0000-00000000d0d0','00000000-0000-0000-0000-00000000a003','tok-staff','android')
on conflict (id) do nothing;

-- ================= identity: owner A =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner reads own-org property' as name,
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000aaa1' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'owner cannot read other-org property',
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000bbb1' $sql$) = 0, null
  union all
  select 'owner reads own org, not the other',
         fam_test.num($sql$ select 1 from organizations where id = '00000000-0000-0000-0000-0000000000bb' $sql$) = 0, null
  union all
  select 'owner reads own profile and co-member profile, not a stranger',
         fam_test.num($sql$ select 1 from profiles where id = '00000000-0000-0000-0000-00000000a001' $sql$) = 1
     and fam_test.num($sql$ select 1 from profiles where id = '00000000-0000-0000-0000-00000000a003' $sql$) = 1
     and fam_test.num($sql$ select 1 from profiles where id = '00000000-0000-0000-0000-00000000b001' $sql$) = 0, null
  union all
  select 'owner cannot read other-org payment allocation',
         fam_test.num($sql$ select 1 from payment_allocations where payment_id = '00000000-0000-0000-0000-0000000c0001' $sql$) = 1, null
  union all
  select 'owner cannot insert a property into another org',
         fam_test.raises($sql$ insert into properties (org_id, name, type)
                                values ('00000000-0000-0000-0000-0000000000bb','Hack','residential') $sql$, '42501'), null
  union all
  select 'owner cannot update another org (0 rows)',
         fam_test.num($sql$ with u as (update organizations set name = 'h'
                                        where id = '00000000-0000-0000-0000-0000000000bb' returning 1)
                           select * from u $sql$) = 0, null
  union all
  select 'owner cannot self-promote to platform admin',
         fam_test.raises($sql$ update profiles set is_platform_admin = true
                                where id = '00000000-0000-0000-0000-00000000a001' $sql$, '42501'), null
  union all
  select 'clients cannot write organization_members directly',
         fam_test.raises($sql$ insert into organization_members (org_id, user_id, role)
                                values ('00000000-0000-0000-0000-0000000000aa',
                                        '00000000-0000-0000-0000-00000000b001','staff') $sql$, '42501'), null
  union all
  select 'clients cannot write audit_logs directly',
         fam_test.raises($sql$ insert into audit_logs (action, table_name) values ('x','y') $sql$, '42501'), null
  union all
  select 'clients cannot write app_event_logs directly',
         fam_test.raises($sql$ insert into app_event_logs (level, source, message)
                                values ('info','mobile','hi') $sql$, '42501'), null
) c order by ok, name;

-- owner A: allowed write (own org)
select 'owner can insert a property into own org' as name,
       not fam_test.raises($sql$ insert into properties (id, org_id, name, type)
                                 values ('00000000-0000-0000-0000-00000000aaa9',
                                         '00000000-0000-0000-0000-0000000000aa','P9','residential') $sql$) as ok,
       fam_test.raise_error($sql$ insert into properties (id, org_id, name, type)
                                  values ('00000000-0000-0000-0000-00000000aaa8',
                                          '00000000-0000-0000-0000-0000000000aa','P8','residential') $sql$) as detail;

-- ================= identity: manager A =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a002','aal1');
set local role authenticated;
select 'manager can insert a property' as name,
       not fam_test.raises($sql$ insert into properties (id, org_id, name, type)
                                 values ('00000000-0000-0000-0000-00000000aaa7',
                                         '00000000-0000-0000-0000-0000000000aa','P7','residential') $sql$) as ok,
       fam_test.raise_error($sql$ insert into properties (id, org_id, name, type)
                                  values ('00000000-0000-0000-0000-00000000aaa6',
                                          '00000000-0000-0000-0000-0000000000aa','P6','residential') $sql$) as detail;

-- ================= identity: staff A =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'staff reads own-org property' as name,
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000aaa1' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'staff cannot insert a property',
         fam_test.raises($sql$ insert into properties (org_id, name, type)
                                values ('00000000-0000-0000-0000-0000000000aa','X','residential') $sql$, '42501'), null
  union all
  select 'staff can insert a tenant (own org)',
         not fam_test.raises($sql$ insert into tenants (id, org_id, full_name)
                                   values ('00000000-0000-0000-0000-00000000eee9',
                                           '00000000-0000-0000-0000-0000000000aa','Staff Tenant') $sql$), null
  union all
  select 'staff sees only their own notification',
         fam_test.num($sql$ select 1 from notifications where id = '00000000-0000-0000-0000-00000000f1f1' $sql$) = 1
     and fam_test.num($sql$ select 1 from notifications where id = '00000000-0000-0000-0000-00000000f2f2' $sql$) = 0, null
  union all
  select 'staff sees only their own device token',
         fam_test.num($sql$ select 1 from device_tokens where id = '00000000-0000-0000-0000-00000000d0d0' $sql$) = 1, null
) c order by ok, name;

-- ================= identity: viewer A =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a004','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'viewer reads own-org property' as name,
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000aaa1' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'viewer cannot insert a property',
         fam_test.raises($sql$ insert into properties (org_id, name, type)
                                values ('00000000-0000-0000-0000-0000000000aa','X','residential') $sql$, '42501'), null
  union all
  select 'viewer cannot insert a tenant',
         fam_test.raises($sql$ insert into tenants (org_id, full_name)
                                values ('00000000-0000-0000-0000-0000000000aa','X') $sql$, '42501'), null
  union all
  select 'viewer cannot update a unit (0 rows)',
         fam_test.num($sql$ with u as (update units set monthly_rent = 1
                                        where id = '00000000-0000-0000-0000-00000000ddd1' returning 1)
                           select * from u $sql$) = 0, null
) c order by ok, name;

-- ================= identity: owner B (cross-org) =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000b001','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner B reads own-org property' as name,
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000bbb1' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'owner B cannot read org A property',
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000aaa1' $sql$) = 0, null
  union all
  select 'owner B cannot read org A charges or payments',
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0001' $sql$) = 0
     and fam_test.num($sql$ select 1 from payments where id = '00000000-0000-0000-0000-0000000c0001' $sql$) = 0, null
  union all
  select 'owner B cannot read org A payment allocation',
         fam_test.num($sql$ select 1 from payment_allocations where payment_id = '00000000-0000-0000-0000-0000000c0001' $sql$) = 0, null
) c order by ok, name;

-- ================= identity: platform admin (cross-org) =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'platform admin reads org B property' as name,
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000bbb1' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'platform admin reads org B organization',
         fam_test.num($sql$ select 1 from organizations where id = '00000000-0000-0000-0000-0000000000bb' $sql$) = 1, null
) c order by ok, name;

-- ================= identity: tenant user I =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000d001','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'tenant reads own lease and charge' as name,
         fam_test.num($sql$ select 1 from leases where id = '00000000-0000-0000-0000-0000000f0001' $sql$) = 1
     and fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0001' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'tenant cannot read another lease',
         fam_test.num($sql$ select 1 from leases where id = '00000000-0000-0000-0000-0000000f0002' $sql$) = 0, null
  union all
  select 'tenant cannot read org properties',
         fam_test.num($sql$ select 1 from properties where id = '00000000-0000-0000-0000-00000000aaa1' $sql$) = 0, null
) c order by ok, name;

reset role;
rollback;


-- ============================================================================
-- PART 5 — grants / privilege lockdown   (runs as postgres; metadata only)
-- ============================================================================
begin;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'anon can execute check_app_version (version gate)' as name,
         (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'check_app_version') as ok,
         null::text as detail
  union all
  select 'anon cannot execute business RPCs',
         not (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('create_organization','record_payment','void_payment',
                                   'dashboard_summary','stock_adjust','log_client_event',
                                   'admin_list_members','invite_member')), null
  union all
  select 'anon cannot execute prune_app_event_logs / invoke_edge_function',
         not (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('prune_app_event_logs','invoke_edge_function')), null
  union all
  select 'authenticated can execute the business RPCs',
         (select bool_and(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public'
             and p.proname in ('create_organization','invite_member','accept_invitation',
                               'create_tenant_with_lease','assign_tenant_to_unit','renew_lease',
                               'terminate_lease','generate_monthly_charges','mark_overdue_charges',
                               'record_payment','void_payment','dashboard_summary','list_units',
                               'rent_overview','report_collections','stock_adjust','rent_stock_item',
                               'return_stock_item','register_device_token','mark_notification_read',
                               'send_reminder','send_reminders_bulk','log_client_event',
                               'admin_list_members','admin_set_member_role','admin_set_member_status',
                               'admin_publish_app_version','admin_set_feature_flag')), null
  union all
  select 'authenticated cannot execute internal cron helpers',
         not (select bool_or(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('prune_app_event_logs','invoke_edge_function')), null
  union all
  -- KNOWN FINDING: next_number() is not revoked from PUBLIC, so it stays
  -- callable by anon. A PASS here means it has been hardened (see FIX part).
  select 'FINDING: next_number is not executable by anon',
         not coalesce((select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'next_number'), false),
         'if FAIL run the FIX block after this part'
  union all
  select 'authenticated cannot self-promote via column privilege',
         not has_column_privilege('authenticated','public.profiles','is_platform_admin','UPDATE'), null
  union all
  select 'authenticated can update their own profile columns',
         has_column_privilege('authenticated','public.profiles','full_name','UPDATE'), null
  union all
  select 'no RLS policy targets the anon role',
         (select count(*) from pg_policies where schemaname = 'public' and 'anon' = any(roles)) = 0, null
) c order by ok, name;

rollback;

-- OPTIONAL FIX for the next_number finding (uncomment to harden):
-- revoke all on function public.next_number(uuid, text) from public, anon, authenticated;


-- ============================================================================
-- PART 6 — organization, member and invitation RPCs
-- ============================================================================
begin;

-- ---- fixtures ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a002','authenticated',
  'authenticated','mgr.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Manager A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a003','authenticated',
  'authenticated','staff.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Staff A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000c001','authenticated',
  'authenticated','newcomer@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Newcomer"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000d001','authenticated',
  'authenticated','invitee@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Invitee"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-adm','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a002','manager','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','staff','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into invitations (id, org_id, email, role, token_hash, expires_at)
values ('00000000-0000-0000-0000-00000000ab01','00000000-0000-0000-0000-0000000000aa','invitee@fam.test',
        'staff','hash_exp', now() - interval '1 day'),
       ('00000000-0000-0000-0000-00000000ab02','00000000-0000-0000-0000-0000000000aa','someoneelse@fam.test',
        'staff','hash_wrong', now() + interval '1 day')
on conflict (id) do nothing;

-- ================= newcomer creates an organization =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal1');
set local role authenticated;
do $$ begin perform public.create_organization('Kefeta Rentals'); end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'create_organization creates org + owner membership' as name,
         fam_test.num($sql$ select 1 from organizations o
                             join organization_members m on m.org_id = o.id
                            where o.created_by = '00000000-0000-0000-0000-00000000c001'
                              and m.user_id = '00000000-0000-0000-0000-00000000c001'
                              and m.role = 'owner' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'slug is derived from the name',
         fam_test.num($sql$ select 1 from organizations
                             where created_by = '00000000-0000-0000-0000-00000000c001'
                               and slug = 'kefeta-rentals' $sql$) = 1, null
  union all
  select 'empty name is rejected',
         fam_test.raises($sql$ select public.create_organization('   ') $sql$, '22023'), null
  union all
  select 'duplicate slug is rejected',
         fam_test.raises($sql$ select public.create_organization('Other','kefeta-rentals') $sql$, '23505'), null
) c order by ok, name;

-- ================= owner A: invitations =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.invite_member('00000000-0000-0000-0000-0000000000aa','invitee@fam.test',null,
                               'staff'::public.org_role,'hash_acc');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner can invite a member' as name,
         fam_test.num($sql$ select 1 from invitations
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and token_hash = 'hash_acc' and email = 'invitee@fam.test' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'invitation records the inviter',
         fam_test.num($sql$ select 1 from invitations where token_hash = 'hash_acc'
                             and invited_by = '00000000-0000-0000-0000-00000000a001' $sql$) = 1, null
  union all
  select 'missing email and phone is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa',null,null,
                                 'staff'::public.org_role,'hash_no_contact') $sql$, '22023'), null
  union all
  select 'empty token hash is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','x@fam.test',null,
                                 'staff'::public.org_role,'') $sql$, '22023'), null
  union all
  select 'duplicate token hash is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','y@fam.test',null,
                                 'staff'::public.org_role,'hash_acc') $sql$, '23505'), null
  union all
  select 'admin_list_members returns the roster with emails',
         fam_test.num($sql$ select * from public.admin_list_members('00000000-0000-0000-0000-0000000000aa') $sql$) >= 3
     and fam_test.num($sql$ select 1 from public.admin_list_members('00000000-0000-0000-0000-0000000000aa')
                            where user_id = '00000000-0000-0000-0000-00000000a001' and email is not null $sql$) = 1, null
) c order by ok, name;

-- ================= staff A: denied =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'staff cannot list members' as name,
         fam_test.raises($sql$ select * from public.admin_list_members('00000000-0000-0000-0000-0000000000aa') $sql$,
                         '42501') as ok, null::text as detail
  union all
  select 'staff cannot invite',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','z@fam.test',null,
                                 'staff'::public.org_role,'hash_staff') $sql$, '42501'), null
  union all
  select 'staff cannot change a role',
         fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '42501'), null
) c order by ok, name;

-- ================= owner A: role and status management =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                       '00000000-0000-0000-0000-00000000a003','manager'::public.org_role);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner promoted staff to manager' as name,
         fam_test.num($sql$ select 1 from organization_members
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and user_id = '00000000-0000-0000-0000-00000000a003'
                               and role = 'manager' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'cannot demote the last owner',
         fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '23505'), null
  union all
  select 'invalid member status is rejected',
         fam_test.raises($sql$ select public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a003','zzz') $sql$, '22023'), null
) c order by ok, name;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'manager cannot change a role' as name,
       fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                               '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '42501') as ok,
       null::text as detail;

-- owner suspends the member, member loses access, owner reactivates
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                         '00000000-0000-0000-0000-00000000a003','suspended');
end $$;
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'a suspended member loses access' as name,
       fam_test.num($sql$ select 1 from properties
                           where org_id = '00000000-0000-0000-0000-0000000000aa' $sql$) = 0 as ok,
       null::text as detail;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                         '00000000-0000-0000-0000-00000000a003','active');
end $$;
select 'owner reactivated the member' as name,
       fam_test.num($sql$ select 1 from organization_members
                           where org_id = '00000000-0000-0000-0000-0000000000aa'
                             and user_id = '00000000-0000-0000-0000-00000000a003'
                             and status = 'active' $sql$) = 1 as ok,
       null::text as detail;

-- ================= invitation acceptance (as the invitee) =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000d001','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'unknown token is rejected' as name,
         fam_test.raises($sql$ select public.accept_invitation('does-not-exist') $sql$, 'P0002') as ok,
         null::text as detail
  union all
  select 'expired invitation is rejected',
         fam_test.raises($sql$ select public.accept_invitation('hash_exp') $sql$, '22023'), null
  union all
  select 'email mismatch is rejected',
         fam_test.raises($sql$ select public.accept_invitation('hash_wrong') $sql$, '42501'), null
) c order by ok, name;

do $$ begin
  perform public.accept_invitation('hash_acc');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'accepting the invitation creates the membership' as name,
         fam_test.num($sql$ select 1 from organization_members
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and user_id = '00000000-0000-0000-0000-00000000d001'
                               and role = 'staff' and status = 'active' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'invitation is marked accepted',
         fam_test.num($sql$ select 1 from invitations where token_hash = 'hash_acc' and accepted_at is not null $sql$) = 1, null
  union all
  select 'accepted token cannot be reused',
         fam_test.raises($sql$ select public.accept_invitation('hash_acc') $sql$, 'P0002'), null
) c order by ok, name;

reset role;
rollback;


-- ============================================================================
-- PART 7 — lease lifecycle and charge generation
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a004','authenticated',
  'authenticated','viewer.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Viewer A"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-lease','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a004','viewer','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent) values
  ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-01',1000),
  ('00000000-0000-0000-0000-00000000ddd2','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-02',1000)
on conflict (id) do nothing;

-- create tenant + lease via the RPC, then inspect
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.create_tenant_with_lease(
    '00000000-0000-0000-0000-0000000000aa',
    '{"fullName":"Tenant A","phone":"+251911000000"}'::jsonb,
    '00000000-0000-0000-0000-00000000ddd1',
    current_date, (current_date + interval '6 months')::date, 1000, 500, 5, 5);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'create_tenant_with_lease creates the tenant' as name,
         fam_test.num($sql$ select 1 from tenants
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and full_name = 'Tenant A' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'lease is active with the given rent and billing day',
         fam_test.num($sql$ select 1 from leases
                             where unit_id = '00000000-0000-0000-0000-00000000ddd1'
                               and status = 'active' and monthly_rent = 1000 and billing_day = 5 $sql$) = 1, null
  union all
  select 'unit is marked rented',
         fam_test.num($sql$ select 1 from units
                             where id = '00000000-0000-0000-0000-00000000ddd1' and status = 'rented' $sql$) = 1, null
  union all
  select 'cannot double-book an occupied unit',
         fam_test.raises($sql$ select public.create_tenant_with_lease(
                                 '00000000-0000-0000-0000-0000000000aa',
                                 '{"fullName":"X"}'::jsonb,
                                 '00000000-0000-0000-0000-00000000ddd1',
                                 current_date, null, 1000, 0, 1, 5) $sql$, '23505'), null
  union all
  select 'negative rent is rejected',
         fam_test.raises($sql$ select public.create_tenant_with_lease(
                                 '00000000-0000-0000-0000-0000000000aa',
                                 '{"fullName":"Y"}'::jsonb,
                                 '00000000-0000-0000-0000-00000000ddd1',
                                 current_date, null, -1, 0, 1, 5) $sql$, '22023'), null
  union all
  select 'unknown unit is rejected',
         fam_test.raises($sql$ select public.create_tenant_with_lease(
                                 '00000000-0000-0000-0000-0000000000aa',
                                 '{"fullName":"Z"}'::jsonb,
                                 '00000000-0000-0000-0000-0000000000ff',
                                 current_date, null, 1000, 0, 1, 5) $sql$, 'P0002'), null
) c order by ok, name;

-- viewer is forbidden
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a004','aal1');
set local role authenticated;
select 'viewer cannot create a tenant/lease' as name,
       fam_test.raises($sql$ select public.create_tenant_with_lease(
                               '00000000-0000-0000-0000-0000000000aa',
                               '{"fullName":"V"}'::jsonb,
                               '00000000-0000-0000-0000-00000000ddd2',
                               current_date, null, 1000, 0, 1, 5) $sql$, '42501') as ok,
       null::text as detail;

-- generate charges (twice, idempotent)
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin perform public.generate_monthly_charges('00000000-0000-0000-0000-0000000000aa'); end $$;
do $$ begin perform public.generate_monthly_charges('00000000-0000-0000-0000-0000000000aa'); end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'one charge created for the active lease (idempotent)' as name,
         fam_test.num($sql$ select 1 from rent_charges
                             where lease_id = (select id from leases
                                                where unit_id = '00000000-0000-0000-0000-00000000ddd1')
                               and period_start = date_trunc('month', current_date)::date $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'charge amount equals the lease rent',
         fam_test.num($sql$ select 1 from rent_charges rc join leases l on l.id = rc.lease_id
                             where l.unit_id = '00000000-0000-0000-0000-00000000ddd1'
                               and rc.amount = 1000 $sql$) = 1, null
  union all
  select 'charge due date honours billing_day',
         fam_test.num($sql$ select 1 from rent_charges rc join leases l on l.id = rc.lease_id
                             where l.unit_id = '00000000-0000-0000-0000-00000000ddd1'
                               and rc.due_date = (date_trunc('month', current_date) + interval '4 days')::date $sql$) = 1, null
  union all
  select 'charge period covers the whole month',
         fam_test.num($sql$ select 1 from rent_charges rc join leases l on l.id = rc.lease_id
                             where l.unit_id = '00000000-0000-0000-0000-00000000ddd1'
                               and rc.period_end = (date_trunc('month', current_date) + interval '1 month - 1 day')::date $sql$) = 1, null
) c order by ok, name;

-- assign a pre-existing tenant to a second unit
do $$ begin
  perform public.assign_tenant_to_unit('00000000-0000-0000-0000-00000000ddd2',
    (select id from tenants where org_id = '00000000-0000-0000-0000-0000000000aa' and full_name = 'Tenant A'),
    current_date, null, 800, 0, 1, 5);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'assign_tenant_to_unit creates an active lease' as name,
         fam_test.num($sql$ select 1 from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'
                             and status = 'active' and monthly_rent = 800 $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'assigned unit is rented',
         fam_test.num($sql$ select 1 from units where id = '00000000-0000-0000-0000-00000000ddd2'
                             and status = 'rented' $sql$) = 1, null
  union all
  select 'cannot assign a tenant to an occupied unit',
         fam_test.raises($sql$ select public.assign_tenant_to_unit(
                                 '00000000-0000-0000-0000-00000000ddd2',
                                 (select id from tenants where org_id = '00000000-0000-0000-0000-0000000000aa' limit 1),
                                 current_date, null, 1000, 0, 1, 5) $sql$, '23505'), null
) c order by ok, name;

-- renew then terminate the second lease
do $$ begin
  perform public.renew_lease(
    (select id from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'),
    (current_date + interval '18 months')::date, 900);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'renew_lease extends the term and updates rent' as name,
         fam_test.num($sql$ select 1 from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'
                             and monthly_rent = 900
                             and end_date = (current_date + interval '18 months')::date $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'renew_lease rejects an end date before the start',
         fam_test.raises($sql$ select public.renew_lease(
                                 (select id from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'),
                                 (current_date - interval '1 day')::date, null) $sql$, '22023'), null
) c order by ok, name;

-- overdue marking: plant an old charge and a due-today charge
reset role;
insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, status)
values ('00000000-0000-0000-0000-0000000e00a1','00000000-0000-0000-0000-0000000000aa',
        (select id from leases where unit_id = '00000000-0000-0000-0000-00000000ddd1'),
        (date_trunc('month', current_date) - interval '2 months')::date,
        (date_trunc('month', current_date) - interval '2 months' + interval '1 month - 1 day')::date,
        current_date - 60, 500, 'pending'),
       ('00000000-0000-0000-0000-0000000e00a2','00000000-0000-0000-0000-0000000000aa',
        (select id from leases where unit_id = '00000000-0000-0000-0000-00000000ddd1'),
        (date_trunc('month', current_date) + interval '20 days')::date,
        (date_trunc('month', current_date) + interval '20 days')::date,
        current_date, 300, 'pending')
on conflict (id) do nothing;

select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin perform public.mark_overdue_charges(); end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'mark_overdue_charges flips an old charge to overdue' as name,
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e00a1'
                             and status = 'overdue' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'mark_overdue_charges leaves a due-today charge pending',
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e00a2'
                             and status = 'pending' $sql$) = 1, null
) c order by ok, name;

-- terminate the second lease -> unit freed
do $$ begin
  perform public.terminate_lease(
    (select id from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'),
    current_date, 'moved out');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'terminate_lease sets status and reason' as name,
         fam_test.num($sql$ select 1 from leases where unit_id = '00000000-0000-0000-0000-00000000ddd2'
                             and status = 'terminated' and ended_reason = 'moved out' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'terminating a lease frees the unit',
         fam_test.num($sql$ select 1 from units where id = '00000000-0000-0000-0000-00000000ddd2'
                             and status = 'vacant' $sql$) = 1, null
) c order by ok, name;

reset role;
rollback;


-- ============================================================================
-- PART 8 — payments: record, allocate (FIFO), idempotency, void
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a003','authenticated',
  'authenticated','staff.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Staff A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a004','authenticated',
  'authenticated','viewer.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Viewer A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000e0e0','authenticated',
  'authenticated','service@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Service"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-pay','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','staff','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a004','viewer','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent)
values ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-01',1000)
on conflict (id) do nothing;

insert into tenants (id, org_id, full_name)
values ('00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000000aa','Tenant A')
on conflict (id) do nothing;

insert into leases (id, org_id, unit_id, tenant_id, start_date, monthly_rent, status)
values ('00000000-0000-0000-0000-0000000f0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-00000000eee1', current_date, 1000, 'active')
on conflict (id) do nothing;

-- two open charges, oldest due first
insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, status)
values ('00000000-0000-0000-0000-0000000e0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-0000000f0001',
        (date_trunc('month', current_date) - interval '2 months')::date,
        (date_trunc('month', current_date) - interval '2 months' + interval '1 month - 1 day')::date,
        current_date - 60, 1000, 'pending'),
       ('00000000-0000-0000-0000-0000000e0002','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-0000000f0001',
        (date_trunc('month', current_date) - interval '1 month')::date,
        (date_trunc('month', current_date) - interval '1 month' + interval '1 month - 1 day')::date,
        current_date - 10, 1000, 'pending')
on conflict (id) do nothing;

-- pay 1200 (FIFO: 1000 to oldest, 200 to next), then retry the same key
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.record_payment('00000000-0000-0000-0000-0000000f0001', 1200, 'cash'::public.payment_method,
                                'r1', now(), null, 'k1');
end $$;
do $$ begin
  perform public.record_payment('00000000-0000-0000-0000-0000000f0001', 1200, 'cash'::public.payment_method,
                                'r1-retry', now(), null, 'k1');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'payment gets an auto receipt number' as name,
         fam_test.num($sql$ select 1 from payments where org_id = '00000000-0000-0000-0000-0000000000aa'
                             and idempotency_key = 'k1'
                             and receipt_no = 'RCP-' || to_char(now(),'YYYY') || '-000001' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'payment allocated oldest-charge-first',
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0001'
                             and status = 'paid' and amount_paid = 1000 $sql$) = 1
     and fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0002'
                             and status = 'partial' and amount_paid = 200 $sql$) = 1, null
  union all
  select 'two allocations were written',
         fam_test.num($sql$ select 1 from payment_allocations pa
                             join payments p on p.id = pa.payment_id
                            where p.idempotency_key = 'k1' $sql$) = 2, null
  union all
  select 'no leftover credit on an exactly-covered payment',
         fam_test.num($sql$ select 1 from payments where idempotency_key = 'k1' and unallocated_amount = 0 $sql$) = 1, null
  union all
  select 'idempotency key prevents a duplicate payment',
         fam_test.num($sql$ select 1 from payments where org_id = '00000000-0000-0000-0000-0000000000aa'
                             and idempotency_key = 'k1' $sql$) = 1, null
) c order by ok, name;

-- pay another 1000: clears the second charge and leaves 200 credit, then void it
do $$ begin
  perform public.record_payment('00000000-0000-0000-0000-0000000f0001', 1000, 'cash'::public.payment_method,
                                'r2', now(), null, 'k2');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'remaining charge is settled' as name,
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0002'
                             and status = 'paid' and amount_paid = 1000 $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'surplus becomes unallocated credit',
         fam_test.num($sql$ select 1 from payments where idempotency_key = 'k2'
                             and unallocated_amount = 200 $sql$) = 1, null
) c order by ok, name;

do $$ begin
  perform public.void_payment((select id from payments where idempotency_key = 'k2'), 'customer error');
end $$;
do $$ begin
  perform public.void_payment((select id from payments where idempotency_key = 'k2'), 'again');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'void stamps the payment' as name,
         fam_test.num($sql$ select 1 from payments where idempotency_key = 'k2' and voided_at is not null $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'void reverses the allocation (charge back to partial)',
         fam_test.num($sql$ select 1 from rent_charges where id = '00000000-0000-0000-0000-0000000e0002'
                             and amount_paid = 200 and status = 'partial' $sql$) = 1, null
  union all
  select 'void removes the allocation rows',
         fam_test.num($sql$ select 1 from payment_allocations pa join payments p on p.id = pa.payment_id
                             where p.idempotency_key = 'k2' $sql$) = 0, null
  union all
  select 'void writes a payment.void audit row',
         fam_test.num($sql$ select 1 from audit_logs
                             where action = 'payment.void' and table_name = 'payments' $sql$) >= 1, null
) c order by ok, name;

-- role and input guards
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'staff cannot void a payment' as name,
       fam_test.raises($sql$ select public.void_payment(
                               (select id from payments where idempotency_key = 'k1'), 'x') $sql$, '42501') as ok,
       null::text as detail;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a004','aal1');
set local role authenticated;
select 'viewer cannot record a payment' as name,
       fam_test.raises($sql$ select public.record_payment('00000000-0000-0000-0000-0000000f0001', 10,
                               'cash'::public.payment_method, null, now(), null, 'vk') $sql$, '42501') as ok,
       null::text as detail;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'zero amount is rejected' as name,
         fam_test.raises($sql$ select public.record_payment('00000000-0000-0000-0000-0000000f0001', 0,
                                 'cash'::public.payment_method, null, now(), null, 'zero') $sql$, '22023') as ok,
         null::text as detail
  union all
  select 'unknown lease is rejected',
         fam_test.raises($sql$ select public.record_payment('00000000-0000-0000-0000-0000000000ff', 10,
                                 'cash'::public.payment_method, null, now(), null, 'nolease') $sql$, 'P0002'), null
) c order by ok, name;

-- service-role path (online payment webhook) is allowed without membership
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000e0e0','aal1','service_role');
set local role authenticated;
do $$ begin
  perform public.record_payment('00000000-0000-0000-0000-0000000f0001', 50, 'chapa'::public.payment_method,
                                'webhook', now(), null, 'k3');
end $$;
select 'service_role can record a payment for any org' as name,
       fam_test.num($sql$ select 1 from payments where idempotency_key = 'k3' $sql$) = 1 as ok,
       null::text as detail;

reset role;
rollback;


-- ============================================================================
-- PART 9 — lists, dashboard and reports
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a003','authenticated',
  'authenticated','staff.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Staff A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000b001','authenticated',
  'authenticated','owner.b@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner B"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000c001','authenticated',
  'authenticated','platform@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Platform"}', now(), now())
on conflict (id) do nothing;
update profiles set is_platform_admin = true where id = '00000000-0000-0000-0000-00000000c001';

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-list','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','staff','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent, status) values
  ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-01',1000,'rented'),
  ('00000000-0000-0000-0000-00000000ddd2','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-02',1000,'vacant')
on conflict (id) do nothing;

insert into tenants (id, org_id, full_name)
values ('00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000000aa','Tenant A')
on conflict (id) do nothing;

insert into leases (id, org_id, unit_id, tenant_id, start_date, end_date, monthly_rent, status)
values ('00000000-0000-0000-0000-0000000f0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-00000000eee1',
        current_date, current_date + 10, 1000, 'active')
on conflict (id) do nothing;

insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, amount_paid, status)
values
 ('00000000-0000-0000-0000-0000000e0001','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000f0001',
  date_trunc('month', current_date)::date,
  (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
  current_date, 1000, 0, 'pending'),
 ('00000000-0000-0000-0000-0000000e0002','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000f0001',
  (date_trunc('month', current_date) - interval '2 months')::date,
  (date_trunc('month', current_date) - interval '2 months' + interval '1 month - 1 day')::date,
  current_date - 40, 500, 0, 'overdue')
on conflict (id) do nothing;

insert into notifications (id, org_id, user_id, channel, title, status)
values ('00000000-0000-0000-0000-00000000f1f1','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000a001','in_app','hello','queued')
on conflict (id) do nothing;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'dashboard expected_month' as name,
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'expected_month') = '1000' as ok,
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'expected_month') as detail
  union all
  select 'dashboard collected_month is 0',
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'collected_month') = '0', null
  union all
  select 'dashboard property / unit / tenant counters',
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'properties_count') = '1'
     and (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'units_total') = '2'
     and (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'units_rented') = '1'
     and (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'units_vacant') = '1'
     and (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'active_tenants') = '1', null
  union all
  select 'dashboard overdue counters',
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'overdue_count') = '1'
     and (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'overdue_amount') = '500', null
  union all
  select 'dashboard unread notifications for the caller',
         (public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') ->> 'unread_notifications') = '1', null
  union all
  select 'dashboard due_this_week holds the charge due today',
         jsonb_array_length(public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') -> 'due_this_week') = 1, null
  union all
  select 'list_properties_with_stats occupancy',
         fam_test.num($sql$ select 1 from public.list_properties_with_stats('00000000-0000-0000-0000-0000000000aa')
                             where units_total = 2 and units_rented = 1 and occupancy_pct = 50.0
                               and monthly_total = 2000 $sql$) = 1, null
  union all
  select 'list_properties_with_stats type filter',
         fam_test.num($sql$ select 1 from public.list_properties_with_stats('00000000-0000-0000-0000-0000000000aa',
                                 'commercial'::public.property_type) $sql$) = 0, null
  union all
  select 'list_properties_with_stats name search',
         fam_test.num($sql$ select 1 from public.list_properties_with_stats('00000000-0000-0000-0000-0000000000aa',
                                 null,'Prop') $sql$) = 1, null
  union all
  select 'list_units returns tenant and overdue flag',
         fam_test.num($sql$ select 1 from public.list_units('00000000-0000-0000-0000-00000000aaa1')
                             where tenant_name = 'Tenant A' and overdue $sql$) = 1, null
  union all
  select 'list_tenants_with_status active filter',
         fam_test.num($sql$ select 1 from public.list_tenants_with_status('00000000-0000-0000-0000-0000000000aa','active') $sql$) = 1, null
  union all
  select 'list_tenants_with_status overdue flag',
         fam_test.num($sql$ select 1 from public.list_tenants_with_status('00000000-0000-0000-0000-0000000000aa','overdue') $sql$) = 1, null
  union all
  select 'list_tenants_with_status expiring filter',
         fam_test.num($sql$ select 1 from public.list_tenants_with_status('00000000-0000-0000-0000-0000000000aa','expiring') $sql$) = 1, null
  union all
  select 'rent_overview totals',
         (public.rent_overview('00000000-0000-0000-0000-0000000000aa', current_date) ->> 'expected') = '1000'
     and (public.rent_overview('00000000-0000-0000-0000-0000000000aa', current_date) ->> 'collected') = '0'
     and (public.rent_overview('00000000-0000-0000-0000-0000000000aa', current_date) ->> 'outstanding') = '1000', null
  union all
  select 'report_collections by month',
         fam_test.num($sql$ select 1 from public.report_collections('00000000-0000-0000-0000-0000000000aa',
                                 date_trunc('month', current_date)::date,
                                 (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
                                 'month')
                             where expected = 1000 and collected = 0 and outstanding = 1000 $sql$) = 1, null
  union all
  select 'report_collections by property',
         fam_test.num($sql$ select 1 from public.report_collections('00000000-0000-0000-0000-0000000000aa',
                                 date_trunc('month', current_date)::date,
                                 (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
                                 'property') where bucket = 'Prop A' $sql$) = 1, null
  union all
  select 'report_occupancy per property',
         fam_test.num($sql$ select 1 from public.report_occupancy('00000000-0000-0000-0000-0000000000aa',
                                 date_trunc('month', current_date)::date,
                                 (date_trunc('month', current_date) + interval '1 month - 1 day')::date)
                             where total_units = 2 and rented_units = 1 and occupancy_pct = 50.0 $sql$) = 1, null
  union all
  select 'report_overdue_ageing bucket 31-60',
         fam_test.num($sql$ select 1 from public.report_overdue_ageing('00000000-0000-0000-0000-0000000000aa')
                             where ageing = '31-60' and charges = 1 and amount = 500 $sql$) = 1, null
) c order by ok, name;

-- staff is not allowed to run the owner/manager reports
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'reports are forbidden to staff' as name,
       fam_test.raises($sql$ select * from public.report_collections('00000000-0000-0000-0000-0000000000aa',
                               current_date, current_date, 'month') $sql$, '42501') as ok,
       null::text as detail;

-- non-member and platform admin
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000b001','aal1');
set local role authenticated;
select 'dashboard is forbidden to a non-member' as name,
       fam_test.raises($sql$ select public.dashboard_summary('00000000-0000-0000-0000-0000000000aa') $sql$, '42501') as ok,
       null::text as detail;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
select 'reports are allowed to a platform admin' as name,
       fam_test.num($sql$ select * from public.report_occupancy('00000000-0000-0000-0000-0000000000aa',
                           current_date, current_date) $sql$) >= 1 as ok,
       null::text as detail;

reset role;
rollback;


-- ============================================================================
-- PART 10 — stock, notifications, devices, client logs
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a004','authenticated',
  'authenticated','viewer.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Viewer A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000d001','authenticated',
  'authenticated','tenant.i@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Tenant I"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-stock','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a004','viewer','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into units (id, org_id, property_id, code, monthly_rent)
values ('00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000aaa1','A-01',1000)
on conflict (id) do nothing;

insert into tenants (id, org_id, full_name, user_id)
values ('00000000-0000-0000-0000-00000000eee1','00000000-0000-0000-0000-0000000000aa','Tenant A','00000000-0000-0000-0000-00000000d001')
on conflict (id) do nothing;

insert into leases (id, org_id, unit_id, tenant_id, start_date, monthly_rent, status)
values ('00000000-0000-0000-0000-0000000f0001','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000ddd1','00000000-0000-0000-0000-00000000eee1', current_date, 1000, 'active')
on conflict (id) do nothing;

insert into rent_charges (id, org_id, lease_id, period_start, period_end, due_date, amount, status)
values ('00000000-0000-0000-0000-0000000e0001','00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-0000000f0001',
        date_trunc('month', current_date)::date,
        (date_trunc('month', current_date) + interval '1 month - 1 day')::date,
        current_date, 1000, 'pending')
on conflict (id) do nothing;

insert into stock_items (id, org_id, name, quantity, min_quantity, is_rentable, rental_rate)
values ('00000000-0000-0000-0000-00000000abc1','00000000-0000-0000-0000-0000000000aa','Widget',10,5,true,100)
on conflict (id) do nothing;
insert into stock_items (id, org_id, name, quantity, min_quantity, is_rentable)
values ('00000000-0000-0000-0000-00000000abc2','00000000-0000-0000-0000-0000000000aa','Nonrentable',0,0,false)
on conflict (id) do nothing;

insert into notifications (id, org_id, user_id, channel, title, status)
values ('00000000-0000-0000-0000-00000000f1f1','00000000-0000-0000-0000-0000000000aa',
        '00000000-0000-0000-0000-00000000a001','in_app','for owner','queued')
on conflict (id) do nothing;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;

do $$ begin
  perform public.stock_adjust('00000000-0000-0000-0000-00000000abc1','in'::public.stock_movement_type, 5, 'restock');
  perform public.stock_adjust('00000000-0000-0000-0000-00000000abc1','adjustment'::public.stock_movement_type, 3, 'count');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'stock_adjust in then adjustment sets the balance' as name,
         fam_test.num($sql$ select 1 from stock_items where id = '00000000-0000-0000-0000-00000000abc1'
                             and quantity = 3 $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'stock movements are written with balance_after',
         fam_test.num($sql$ select 1 from stock_movements where item_id = '00000000-0000-0000-0000-00000000abc1' $sql$) = 2, null
  union all
  select 'stock_out beyond the balance is rejected',
         fam_test.raises($sql$ select public.stock_adjust('00000000-0000-0000-0000-00000000abc1',
                                 'out'::public.stock_movement_type, 20, 'too many') $sql$, '22023'), null
  union all
  select 'list_low_stock reports the low item',
         fam_test.num($sql$ select 1 from public.list_low_stock('00000000-0000-0000-0000-0000000000aa')
                             where id = '00000000-0000-0000-0000-00000000abc1' $sql$) = 1, null
  union all
  select 'non-rentable items cannot be rented',
         fam_test.raises($sql$ select public.rent_stock_item('00000000-0000-0000-0000-00000000abc2',
                                 '00000000-0000-0000-0000-00000000eee1', 1) $sql$, '22023'), null
) c order by ok, name;

do $$ begin
  perform public.rent_stock_item('00000000-0000-0000-0000-00000000abc1',
                                 '00000000-0000-0000-0000-00000000eee1', 2, 50, current_date + 3);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'rent_stock_item decrements the balance' as name,
         fam_test.num($sql$ select 1 from stock_items where id = '00000000-0000-0000-0000-00000000abc1'
                             and quantity = 1 $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'rental is recorded as out with the rate',
         fam_test.num($sql$ select 1 from stock_rentals where item_id = '00000000-0000-0000-0000-00000000abc1'
                             and status = 'out' and daily_rate = 50 $sql$) = 1, null
  union all
  select 'insufficient stock is rejected',
         fam_test.raises($sql$ select public.rent_stock_item('00000000-0000-0000-0000-00000000abc1',
                                 '00000000-0000-0000-0000-00000000eee1', 10) $sql$, '22023'), null
) c order by ok, name;

do $$ begin
  perform public.return_stock_item((select id from stock_rentals where item_id = '00000000-0000-0000-0000-00000000abc1' limit 1));
  perform public.return_stock_item((select id from stock_rentals where item_id = '00000000-0000-0000-0000-00000000abc1' limit 1));
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'return restores the balance' as name,
         fam_test.num($sql$ select 1 from stock_items where id = '00000000-0000-0000-0000-00000000abc1'
                             and quantity = 3 $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'rental is marked returned',
         fam_test.num($sql$ select 1 from stock_rentals where item_id = '00000000-0000-0000-0000-00000000abc1'
                             and status = 'returned' and returned_at is not null $sql$) = 1, null
) c order by ok, name;

-- device tokens, notification reads, reminders
do $$ begin
  perform public.register_device_token('tok-owner','android');
  perform public.register_device_token('tok-owner','ios');
end $$;
do $$ begin
  perform public.mark_notification_read('00000000-0000-0000-0000-00000000f1f1');
end $$;
do $$ begin
  perform public.send_reminder('00000000-0000-0000-0000-0000000e0001','in_app'::public.notification_channel);
  perform public.send_reminders_bulk('00000000-0000-0000-0000-0000000000aa', current_date);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'device token upsert keeps one row and updates platform' as name,
         fam_test.num($sql$ select 1 from device_tokens
                             where token = 'tok-owner' and platform = 'ios'
                               and user_id = '00000000-0000-0000-0000-00000000a001' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'mark_notification_read only touches the caller''s row',
         fam_test.num($sql$ select 1 from notifications where id = '00000000-0000-0000-0000-00000000f1f1'
                             and status = 'read' $sql$) = 1, null
  union all
  select 'send_reminder queues a notification for the tenant',
         fam_test.num($sql$ select 1 from notifications where tenant_id = '00000000-0000-0000-0000-00000000eee1'
                             and title = 'Rent reminder' $sql$) >= 1, null
) c order by ok, name;

-- client logging
do $$ begin
  perform public.log_client_event('info','mobile','hello world','{"a":1}'::jsonb,'1.0.0','android',null);
  perform public.log_client_event('bogus','mobile','bad level', '{}'::jsonb, null, null, null);
  perform public.log_client_event('info','mobile','big', jsonb_build_object('x', repeat('a', 9000)), null, null, null);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'log_client_event inserts a row for the caller' as name,
         fam_test.num($sql$ select 1 from app_event_logs where message = 'hello world'
                             and user_id = '00000000-0000-0000-0000-00000000a001'
                             and app_version = '1.0.0' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'an unknown level is coerced to info',
         fam_test.num($sql$ select 1 from app_event_logs where message = 'bad level' and level = 'info' $sql$) = 1, null
  union all
  select 'an oversized context is dropped',
         fam_test.num($sql$ select 1 from app_event_logs where message = 'big' and context = '{}'::jsonb $sql$) = 1, null
) c order by ok, name;

-- rate limit: 60 rows in the last hour forces a rejection
reset role;
insert into app_event_logs (level, source, message, user_id, created_at)
select 'info','mobile','flood','00000000-0000-0000-0000-00000000a001', now()
  from generate_series(1,60);
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
select 'client logging is rate limited' as name,
       fam_test.raises($sql$ select public.log_client_event('info','mobile','flood') $sql$, '22023') as ok,
       null::text as detail;

-- viewer cannot touch stock
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a004','aal1');
set local role authenticated;
select 'viewer cannot adjust stock' as name,
       fam_test.raises($sql$ select public.stock_adjust('00000000-0000-0000-0000-00000000abc1',
                               'in'::public.stock_movement_type, 1) $sql$, '42501') as ok,
       null::text as detail;

reset role;
rollback;


-- ============================================================================
-- PART 11 — platform-admin RPCs and the version gate
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000c001','authenticated',
  'authenticated','platform@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Platform"}', now(), now())
on conflict (id) do nothing;
update profiles set is_platform_admin = true where id = '00000000-0000-0000-0000-00000000c001';

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-plat','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;
insert into organization_members (org_id, user_id, role, status)
values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active')
on conflict (org_id, user_id) do nothing;

-- version rows for the public gate (explicit released_at => deterministic ordering)
insert into app_versions (id, platform, version, min_supported_version, force_update, released_at)
values ('00000000-0000-0000-0000-0000000a0001','android','2.0.0','1.2.0',true,  now() - interval '1 day'),
       ('00000000-0000-0000-0000-0000000a0002','web','1.10.0','1.0.0',false, now() - interval '2 day')
on conflict (id) do nothing;

-- the gate is anon-callable
reset role;
set local role anon;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'gate: up-to-date client is ok' as name,
         (public.check_app_version('android','2.0.0') ->> 'status') = 'ok' as ok,
         (public.check_app_version('android','2.0.0') ->> 'status') as detail
  union all
  select 'gate: below latest with force_update => force_update',
         (public.check_app_version('android','1.9.0') ->> 'status') = 'force_update', null
  union all
  select 'gate: below min_supported => force_update',
         (public.check_app_version('android','1.1.0') ->> 'status') = 'force_update', null
  union all
  select 'gate: unknown platform => ok',
         (public.check_app_version('ios','0.0.1') ->> 'status') = 'ok', null
  union all
  select 'gate: int-array compare treats 1.10.0 > 1.9.0',
         (public.check_app_version('web','1.9.0') ->> 'status') = 'update_available', null
  union all
  select 'gate: latest web build is ok',
         (public.check_app_version('web','1.10.0') ->> 'status') = 'ok', null
) c order by ok, name;
reset role;

-- platform admin requires MFA (aal2)
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal1');
set local role authenticated;
select 'platform admin without MFA is refused' as name,
       fam_test.raises($sql$ select public.admin_publish_app_version('android','9.9.9','9.0.0') $sql$, '42501') as ok,
       null::text as detail;

-- normal user is refused
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal2');
set local role authenticated;
select 'non-admin is refused for platform RPCs' as name,
       fam_test.raises($sql$ select public.admin_publish_app_version('android','9.9.9','9.0.0') $sql$, '42501')
   and fam_test.raises($sql$ select public.admin_set_feature_flag('maintenance_requests', null, true) $sql$, '42501')
   and fam_test.raises($sql$ select * from public.admin_list_event_logs() $sql$, '42501') as ok,
       null::text as detail;

-- platform admin with MFA succeeds
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
do $$ begin
  perform public.admin_publish_app_version('android','9.9.9','9.0.0', false, 'https://example.test/app', 'notes');
end $$;
do $$ begin
  perform public.admin_set_feature_flag('maintenance_requests','00000000-0000-0000-0000-0000000000aa', true);
end $$;
do $$ begin
  perform public.admin_set_feature_flag('tenant_portal', null, false);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'admin_publish_app_version inserts the version' as name,
         fam_test.num($sql$ select 1 from app_versions where platform = 'android' and version = '9.9.9' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'publishing writes a version.publish audit row',
         fam_test.num($sql$ select 1 from audit_logs where action = 'version.publish' $sql$) >= 1, null
  union all
  select 'admin_set_feature_flag sets an org override',
         fam_test.num($sql$ select 1 from feature_flags where key = 'maintenance_requests'
                             and org_id = '00000000-0000-0000-0000-0000000000aa' and enabled $sql$) = 1, null
  union all
  select 'admin_set_feature_flag toggles a global flag',
         fam_test.num($sql$ select 1 from feature_flags where key = 'tenant_portal'
                             and org_id is null and not enabled $sql$) = 1, null
) c order by ok, name;

-- event log listing (needs a row)
reset role;
insert into app_event_logs (level, source, message) values ('error','edge','boom');
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
select 'admin_list_event_logs filters by level' as name,
       fam_test.num($sql$ select * from public.admin_list_event_logs('error') $sql$) >= 1 as ok,
       null::text as detail;

reset role;
rollback;


-- ============================================================================
-- PART 12 — teardown (drops the fam_test schema)
-- ============================================================================
drop schema if exists fam_test cascade;

select 'fam_test schema removed' as name,
       not exists (select 1 from pg_namespace where nspname = 'fam_test') as ok;
