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

