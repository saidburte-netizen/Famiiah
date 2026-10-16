-- 0004_triggers.sql
-- updated_at triggers, new-user profile creation, unit status sync,
-- receipt numbering, and audit logging.

-- ---- updated_at triggers ----
do $$
declare t text;
begin
  for t in
    select unnest(array[
      'profiles','organizations','organization_members','properties','units','tenants',
      'leases','rent_charges','stock_items','feature_flags','maintenance_requests'
    ])
  loop
    execute format(
      'create trigger set_updated_at_%I before update on public.%I for each row execute function public.set_updated_at()',
      t, t);
  end loop;
end $$;

-- ---- create profile on auth.users insert ----
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.phone
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---- sync unit status when lease status changes ----
create or replace function public.sync_unit_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' and new.status = 'active' then
    update public.units set status = 'rented' where id = new.unit_id and status = 'vacant';
  elsif tg_op = 'UPDATE' then
    if new.status = 'active' and old.status <> 'active' then
      update public.units set status = 'rented' where id = new.unit_id and status = 'vacant';
    elsif new.status in ('ended','terminated') and old.status = 'active' then
      -- only free the unit if it is still marked rented for this lease
      update public.units set status = 'vacant' where id = new.unit_id and status = 'rented';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_unit_status on public.leases;
create trigger sync_unit_status
  after insert or update of status on public.leases
  for each row execute function public.sync_unit_status();

-- ---- assign receipt number before insert on payments ----
create or replace function public.assign_receipt_no() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_seq bigint;
begin
  if new.receipt_no is null or new.receipt_no = '' then
    select public.next_number(new.org_id, 'receipt') into v_seq;
    new.receipt_no := 'RCP-' || to_char(now(),'YYYY') || '-' || lpad(v_seq::text, 6, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists assign_receipt_no on public.payments;
create trigger assign_receipt_no
  before insert on public.payments
  for each row execute function public.assign_receipt_no();

-- ---- audit logging ----
create or replace function public.audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  insert into audit_logs(org_id, actor_id, action, table_name, record_id, old_data, new_data)
  values (nullif(v->>'org_id','')::uuid, (select auth.uid()), tg_op, tg_table_name,
          nullif(v->>'id','')::uuid,
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  if tg_op = 'DELETE' then return old; else return new; end if;
end $$;

do $$
declare t text;
begin
  for t in
    select unnest(array[
      'properties','units','tenants','leases','rent_charges','payments',
      'stock_items','stock_rentals','organization_members','feature_flags','app_versions'
    ])
  loop
    execute format(
      'create trigger audit_%I after insert or update or delete on public.%I for each row execute function public.audit_row_change()',
      t, t);
  end loop;
end $$;
