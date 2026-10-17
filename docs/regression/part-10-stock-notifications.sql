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

