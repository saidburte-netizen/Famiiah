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

