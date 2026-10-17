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

