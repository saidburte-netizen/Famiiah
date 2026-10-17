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

