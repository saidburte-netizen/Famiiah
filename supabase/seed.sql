-- supabase/seed.sql — DEV ONLY. Never run in production.
-- Creates one demo org with properties, units/shops, tenants, leases,
-- 6 months of charges and payments, stock, notifications and app versions.
-- Clearly fake data. Runs as the postgres/service role so RLS is bypassed.

-- deterministic ids for repeatable seeding (db reset)
do $$
declare
  v_owner uuid := '11111111-1111-1111-1111-111111111111';
  v_manager uuid := '22222222-2222-2222-2222-222222222222';
  v_org uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_prop_res uuid := 'bbbbbbbb-0000-0000-0000-000000000001';
  v_prop_com uuid := 'bbbbbbbb-0000-0000-0000-000000000002';
  v_prop_mix uuid := 'bbbbbbbb-0000-0000-0000-000000000003';
  v_tenant uuid;
  v_unit uuid;
  v_lease uuid;
  v_charge uuid;
  v_pay uuid;
  v_item uuid;
  i int;
  m int;
  v_rent numeric;
begin
  -- ---- auth users (password: Password123) ----
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                          email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  values
    ('00000000-0000-0000-0000-000000000000', v_owner, 'authenticated', 'authenticated',
     'owner@demo.fam', crypt('Password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Demo Owner"}', now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_manager, 'authenticated', 'authenticated',
     'manager@demo.fam', crypt('Password123', gen_salt('bf')), now(),
     '{"provider":"email","providers":["email"]}', '{"full_name":"Demo Manager"}', now(), now())
  on conflict (id) do nothing;

  update profiles set full_name = 'Demo Owner' where id = v_owner;
  update profiles set full_name = 'Demo Manager' where id = v_manager;

  -- ---- org + members ----
  insert into organizations (id, name, slug, created_by)
  values (v_org, 'Demo Properties', 'demo-properties', v_owner)
  on conflict (id) do nothing;

  insert into organization_members (org_id, user_id, role, status)
  values (v_org, v_owner, 'owner', 'active'),
         (v_org, v_manager, 'manager', 'active')
  on conflict (org_id, user_id) do nothing;

  -- ---- properties ----
  insert into properties (id, org_id, name, type, city, sub_city, floors)
  values
    (v_prop_res, v_org, 'Bole Residential', 'residential', 'Addis Ababa', 'Bole', 4),
    (v_prop_com, v_org, 'Merkato Shops', 'commercial', 'Addis Ababa', 'Addis Ketema', 3),
    (v_prop_mix, v_org, 'Piassa Mixed Use', 'mixed_use', 'Addis Ababa', 'Arada', 5)
  on conflict (id) do nothing;

  -- ---- units (~40 across 3 properties) ----
  for i in 1..16 loop
    insert into units (org_id, property_id, code, kind, floor_label, area_sqm, monthly_rent)
    values (v_org, v_prop_res, 'A-' || lpad(i::text, 2, '0'), 'apartment', 'F' || ((i-1)/4 + 1), 75 + i, 8000 + i * 250);
  end loop;
  for i in 1..14 loop
    insert into units (org_id, property_id, code, kind, floor_label, area_sqm, monthly_rent)
    values (v_org, v_prop_com, 'S-' || lpad(i::text, 2, '0'), 'shop', 'G', 18 + i, 12000 + i * 400);
  end loop;
  for i in 1..10 loop
    insert into units (org_id, property_id, code, kind, floor_label, area_sqm, monthly_rent)
    values (v_org, v_prop_mix, 'M-' || lpad(i::text, 2, '0'), 'office', 'F' || ((i-1)/3 + 1), 40 + i, 15000 + i * 300);
  end loop;

  -- ---- tenants + leases (25 active) ----
  for v_unit in
    select id from units where org_id = v_org order by code limit 25
  loop
    insert into tenants (org_id, full_name, phone, email)
    values (v_org, 'Tenant ' || substr(v_unit::text, 1, 4), '+251911' || lpad((random()*999999)::int::text, 6, '0'),
            'tenant' || substr(v_unit::text, 1, 4) || '@demo.fam')
    returning id into v_tenant;

    select monthly_rent into v_rent from units where id = v_unit;

    insert into leases (org_id, unit_id, tenant_id, start_date, end_date, monthly_rent,
                        deposit_amount, billing_day, grace_days, status)
    values (v_org, v_unit, v_tenant, current_date - interval '6 months', current_date + interval '6 months',
            v_rent, v_rent, 5, 5, 'active')
    returning id into v_lease;

    -- ---- 6 months of charges ----
    for m in 0..5 loop
      insert into rent_charges (org_id, lease_id, period_start, period_end, due_date, amount, status)
      values (
        v_org, v_lease,
        (date_trunc('month', now()) - make_interval(months => m))::date,
        (date_trunc('month', now()) - make_interval(months => m) + interval '1 month - 1 day')::date,
        (date_trunc('month', now()) - make_interval(months => m) + interval '4 days')::date,
        v_rent,
        case when m = 0 and random() < 0.3 then 'pending'::charge_status else 'paid'::charge_status end
      )
      returning id into v_charge;

      -- pay most charges (leave some current-month ones pending)
      if (select status from rent_charges where id = v_charge) = 'paid' then
        insert into payments (org_id, tenant_id, lease_id, amount, method, reference, paid_at)
        values (v_org, v_tenant, v_lease, v_rent,
                (array['cash','bank_transfer','telebirr']::payment_method[])[1 + (random()*2)::int],
                'REF-' || substr(v_charge::text,1,6),
                (date_trunc('month', now()) - make_interval(months => m) + interval '3 days'))
        returning id into v_pay;

        insert into payment_allocations (payment_id, charge_id, amount) values (v_pay, v_charge, v_rent);
        update rent_charges set amount_paid = v_rent where id = v_charge;
      end if;
    end loop;
  end loop;

  -- mark a few charges overdue (older than grace)
  update rent_charges set status = 'overdue'
   where org_id = v_org and status = 'pending' and due_date < current_date - interval '10 days';

  -- ---- stock items (15; 2 low, 1 out, 2 rentable) ----
  for i in 1..15 loop
    insert into stock_items (org_id, property_id, name, sku, category, uom, quantity, min_quantity,
                             is_rentable, rental_rate, barcode)
    values (
      v_org, v_prop_com, 'Item ' || i, 'SKU-' || lpad(i::text, 3, '0'),
      case when i % 2 = 0 then 'consumable' else 'tool' end, 'pcs',
      case when i = 3 then 0 when i in (1,2) then 1 else 20 + i end,
      5, i in (4,5), case when i in (4,5) then 150.00 else null end, 'BAR' || lpad(i::text, 6, '0')
    ) returning id into v_item;

    if i not in (1,2,3) then
      insert into stock_movements (org_id, item_id, type, quantity, balance_after, performed_by)
      values (v_org, v_item, 'in', 20 + i, 20 + i, v_owner);
    end if;
  end loop;

  -- ---- notifications ----
  insert into notifications (org_id, user_id, channel, title, body, status)
  values (v_org, v_owner, 'in_app', 'Welcome to Fam', 'Your demo workspace is ready.', 'read'),
         (v_org, v_owner, 'in_app', '3 payments received today', 'Collections are up this week.', 'queued');

  -- ---- app versions ----
  insert into app_versions (platform, version, min_supported_version, force_update, store_url)
  values ('ios', '1.0.0', '1.0.0', false, 'https://apps.apple.com/app/id000000000'),
         ('android', '1.0.0', '1.0.0', false, 'https://play.google.com/store/apps/details?id=com.fami.myapp'),
         ('web', '1.0.0', '1.0.0', false, 'https://admin.fam.app')
  on conflict (platform, version) do nothing;

  -- ---- one platform admin (also promote owner) ----
  update profiles set is_platform_admin = true where id = v_owner;
end $$;
