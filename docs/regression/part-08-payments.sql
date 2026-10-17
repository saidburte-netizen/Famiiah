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

