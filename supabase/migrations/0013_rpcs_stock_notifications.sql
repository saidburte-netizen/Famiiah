-- 0013_rpcs_stock_notifications.sql
-- stock_adjust, rent_stock_item, return_stock_item, list_low_stock,
-- register_device_token, mark_notification_read(s), log_client_event.

-- ==================== stock_adjust ====================
-- Locks the item row, rejects negative balance, writes a movement with balance_after.
create or replace function public.stock_adjust(
  p_item uuid, p_type public.stock_movement_type, p_qty numeric,
  p_reason text default null, p_unit uuid default null)
returns public.stock_items
language plpgsql security definer set search_path = public as $$
declare
  v_item public.stock_items;
  v_delta numeric;
  v_new numeric;
begin
  select * into v_item from stock_items where id = p_item for update;
  if not found then raise exception 'item_not_found' using errcode = 'P0002'; end if;
  if not has_org_role(v_item.org_id, array['owner','manager','staff']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_qty is null
     or (p_type in ('in','out') and p_qty <= 0)
     or (p_type = 'adjustment' and p_qty < 0) then
    raise exception 'invalid_qty' using errcode = '22023';
  end if;

  v_delta := case when p_type = 'in' then p_qty
                  when p_type = 'out' then -p_qty
                  else 0 end;  -- adjustment handled via p_qty sign below

  if p_type = 'adjustment' then
    -- adjustment sets an absolute target stored in p_qty as the new balance
    v_new := p_qty;
  else
    v_new := v_item.quantity + v_delta;
  end if;

  if v_new < 0 then
    raise exception 'negative_balance' using errcode = '22023';
  end if;

  update stock_items set quantity = v_new where id = p_item returning * into v_item;

  insert into stock_movements (org_id, item_id, type, quantity, balance_after, reason, unit_id, performed_by)
  values (v_item.org_id, p_item, p_type, p_qty, v_new, p_reason, p_unit, (select auth.uid()));

  return v_item;
end;
$$;

-- ==================== rent_stock_item ====================
create or replace function public.rent_stock_item(
  p_item uuid, p_tenant uuid, p_qty numeric, p_rate numeric default null,
  p_due date default null)
returns public.stock_rentals
language plpgsql security definer set search_path = public as $$
declare
  v_item public.stock_items;
  v_rate numeric;
  v_due date;
  v_rental public.stock_rentals;
begin
  select * into v_item from stock_items where id = p_item for update;
  if not found then raise exception 'item_not_found' using errcode = 'P0002'; end if;
  if not has_org_role(v_item.org_id, array['owner','manager','staff']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not v_item.is_rentable then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  if p_qty is null or p_qty <= 0 or v_item.quantity < p_qty then
    raise exception 'insufficient_stock' using errcode = '22023';
  end if;

  v_rate := coalesce(p_rate, v_item.rental_rate, 0);
  v_due := coalesce(p_due, current_date + 1);

  insert into stock_rentals (org_id, item_id, tenant_id, quantity, daily_rate, start_date, due_date, status)
  values (v_item.org_id, p_item, p_tenant, p_qty, v_rate, current_date, v_due, 'out')
  returning * into v_rental;

  -- decrement stock and record movement
  update stock_items set quantity = quantity - p_qty where id = p_item;
  insert into stock_movements (org_id, item_id, type, quantity, balance_after, performed_by)
  values (v_item.org_id, p_item, 'rental_out', p_qty, v_item.quantity - p_qty, (select auth.uid()));

  return v_rental;
end;
$$;

-- ==================== return_stock_item ====================
create or replace function public.return_stock_item(p_rental uuid)
returns public.stock_rentals
language plpgsql security definer set search_path = public as $$
declare
  v_rental public.stock_rentals;
  v_item public.stock_items;
begin
  select * into v_rental from stock_rentals where id = p_rental for update;
  if not found then raise exception 'invalid_input' using errcode = 'P0002'; end if;
  if not has_org_role(v_rental.org_id, array['owner','manager','staff']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_rental.status = 'returned' then return v_rental; end if;

  update stock_rentals set status = 'returned', returned_at = now() where id = p_rental
    returning * into v_rental;

  select * into v_item from stock_items where id = v_rental.item_id for update;
  update stock_items set quantity = quantity + v_rental.quantity where id = v_rental.item_id;
  insert into stock_movements (org_id, item_id, type, quantity, balance_after, performed_by)
  values (v_rental.org_id, v_rental.item_id, 'rental_return', v_rental.quantity,
          v_item.quantity + v_rental.quantity, (select auth.uid()));

  return v_rental;
end;
$$;

-- ==================== list_low_stock ====================
create or replace function public.list_low_stock(p_org uuid)
returns setof public.stock_items
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_org_member(p_org) then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
    select * from stock_items
     where org_id = p_org and deleted_at is null and quantity <= min_quantity
     order by (quantity / nullif(min_quantity,0)) asc;
end;
$$;

-- ==================== device + notifications + logs ====================
create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into device_tokens (user_id, token, platform)
  values ((select auth.uid()), p_token, p_platform)
  on conflict (token) do update set platform = excluded.platform, user_id = excluded.user_id;
end;
$$;

create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update notifications
     set status = 'read', read_at = now()
   where id = p_id and user_id = (select auth.uid());
end;
$$;

create or replace function public.mark_all_notifications_read(p_org uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update notifications
     set status = 'read', read_at = now()
   where user_id = (select auth.uid()) and org_id = p_org and status <> 'read';
end;
$$;

create or replace function public.send_reminder(p_charge uuid, p_channel public.notification_channel default 'in_app')
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_ch record; v_uid uuid; v_notif uuid;
begin
  select rc.*, l.tenant_id, t.user_id as tenant_user, t.full_name
    into v_ch
    from rent_charges rc
    join leases l on l.id = rc.lease_id
    join tenants t on t.id = l.tenant_id
   where rc.id = p_charge;

  if not found then raise exception 'lease_not_found' using errcode = 'P0002'; end if;
  if not has_org_role(v_ch.org_id, array['owner','manager','staff']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  v_uid := v_ch.tenant_user;
  insert into notifications (org_id, user_id, tenant_id, channel, title, body, data, status)
  values (v_ch.org_id, v_uid, v_ch.tenant_id, p_channel,
          'Rent reminder', 'Rent of ' || v_ch.amount || ' is due on ' || v_ch.due_date,
          jsonb_build_object('charge_id', p_charge), 'queued')
  returning id into v_notif;

  return v_notif;
end;
$$;

create or replace function public.send_reminders_bulk(p_org uuid, p_month date)
returns int
language plpgsql security definer set search_path = public as $$
declare v_count int := 0; v_start date := date_trunc('month', p_month)::date;
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into notifications (org_id, user_id, tenant_id, channel, title, body, data, status)
  select rc.org_id, t.user_id, t.id, 'in_app', 'Rent reminder',
         'Rent of ' || rc.amount || ' is due on ' || rc.due_date,
         jsonb_build_object('charge_id', rc.id), 'queued'
    from rent_charges rc
    join leases l on l.id = rc.lease_id
    join tenants t on t.id = l.tenant_id
   where rc.org_id = p_org
     and date_trunc('month', rc.period_start)::date = v_start
     and rc.status in ('pending','partial','overdue');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.log_client_event(
  p_level text, p_source text, p_message text, p_context jsonb default '{}',
  p_app_version text default null, p_platform text default null, p_request_id text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := (select auth.uid()); v_recent int;
begin
  -- rate limit: max 60 events per user per hour
  select count(*) into v_recent from app_event_logs
   where user_id = v_uid and created_at > now() - interval '1 hour';
  if v_recent >= 60 then
    raise exception 'rate_limited' using errcode = '22023';
  end if;

  insert into app_event_logs (level, source, message, context, user_id, org_id, app_version, platform, request_id)
  values (
    case when p_level in ('debug','info','warn','error','fatal') then p_level else 'info' end,
    case when p_source in ('mobile','admin','edge','db') then p_source else 'mobile' end,
    left(coalesce(p_message,''), 2000),
    case when octet_length(coalesce(p_context::text,'')) <= 8192 then coalesce(p_context,'{}'::jsonb) else '{}'::jsonb end,
    v_uid, null, p_app_version, p_platform, p_request_id
  );
end;
$$;
