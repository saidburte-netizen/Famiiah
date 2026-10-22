-- 0020_archive_rpcs.sql
-- Archive (soft-delete) and restore for the records an org owns.
--
-- The schema deletes nothing: properties, units, tenants and stock_items all
-- carry `deleted_at`, every list RPC filters `deleted_at is null`, and RLS
-- deliberately has **no delete policy** on them (see 0005_rls.sql) so a client
-- cannot hard-delete a record and orphan its history.
--
-- These RPCs are the one supported way to remove a record. They are SECURITY
-- DEFINER because the RLS update policies differ per table while the business
-- rule ("owner or manager") is the same; the explicit has_org_role() check is
-- what actually authorises the call, exactly as the other write RPCs do.
--
-- Guards: a record that still has live dependants is refused with a specific
-- error code rather than silently hiding them:
--   * a property with units              -> property_has_units
--   * a unit with an active lease        -> unit_has_lease
--   * a tenant with an active lease      -> tenant_has_lease
--   * a stock item with an open rental   -> item_has_rental
--   * a stock item with stock on hand    -> item_has_stock
-- The client maps each code to friendly copy; see error.* in the i18n catalog.

-- ==================== properties ====================

create or replace function public.archive_property(p_property uuid)
returns public.properties
language plpgsql security definer set search_path = public as $$
declare v_prop public.properties;
begin
  select * into v_prop from properties where id = p_property and deleted_at is null for update;
  if not found then
    raise exception 'property_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_prop.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from units where property_id = p_property and deleted_at is null) then
    raise exception 'property_has_units' using errcode = '23503';
  end if;

  update properties set deleted_at = now() where id = p_property returning * into v_prop;
  return v_prop;
end;
$$;

create or replace function public.restore_property(p_property uuid)
returns public.properties
language plpgsql security definer set search_path = public as $$
declare v_prop public.properties;
begin
  select * into v_prop from properties where id = p_property and deleted_at is not null for update;
  if not found then
    raise exception 'property_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_prop.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update properties set deleted_at = null where id = p_property returning * into v_prop;
  return v_prop;
end;
$$;

-- ==================== units ====================

create or replace function public.archive_unit(p_unit uuid)
returns public.units
language plpgsql security definer set search_path = public as $$
declare v_unit public.units;
begin
  select * into v_unit from units where id = p_unit and deleted_at is null for update;
  if not found then
    raise exception 'unit_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_unit.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from leases where unit_id = p_unit and status = 'active') then
    raise exception 'unit_has_lease' using errcode = '23503';
  end if;

  update units set deleted_at = now() where id = p_unit returning * into v_unit;
  return v_unit;
end;
$$;

create or replace function public.restore_unit(p_unit uuid)
returns public.units
language plpgsql security definer set search_path = public as $$
declare v_unit public.units;
begin
  select * into v_unit from units where id = p_unit and deleted_at is not null for update;
  if not found then
    raise exception 'unit_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_unit.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update units set deleted_at = null where id = p_unit returning * into v_unit;
  return v_unit;
end;
$$;

-- ==================== tenants ====================

create or replace function public.archive_tenant(p_tenant uuid)
returns public.tenants
language plpgsql security definer set search_path = public as $$
declare v_tenant public.tenants;
begin
  select * into v_tenant from tenants where id = p_tenant and deleted_at is null for update;
  if not found then
    raise exception 'tenant_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_tenant.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from leases where tenant_id = p_tenant and status = 'active') then
    raise exception 'tenant_has_lease' using errcode = '23503';
  end if;

  update tenants set deleted_at = now(), status = 'inactive' where id = p_tenant returning * into v_tenant;
  return v_tenant;
end;
$$;

create or replace function public.restore_tenant(p_tenant uuid)
returns public.tenants
language plpgsql security definer set search_path = public as $$
declare v_tenant public.tenants;
begin
  select * into v_tenant from tenants where id = p_tenant and deleted_at is not null for update;
  if not found then
    raise exception 'tenant_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_tenant.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update tenants set deleted_at = null where id = p_tenant returning * into v_tenant;
  return v_tenant;
end;
$$;

-- ==================== stock items ====================

create or replace function public.archive_stock_item(p_item uuid)
returns public.stock_items
language plpgsql security definer set search_path = public as $$
declare v_item public.stock_items;
begin
  select * into v_item from stock_items where id = p_item and deleted_at is null for update;
  if not found then
    raise exception 'item_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_item.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from stock_rentals where item_id = p_item and returned_at is null) then
    raise exception 'item_has_rental' using errcode = '23503';
  end if;
  if v_item.quantity <> 0 then
    raise exception 'item_has_stock' using errcode = '23503';
  end if;

  update stock_items set deleted_at = now() where id = p_item returning * into v_item;
  return v_item;
end;
$$;

create or replace function public.restore_stock_item(p_item uuid)
returns public.stock_items
language plpgsql security definer set search_path = public as $$
declare v_item public.stock_items;
begin
  select * into v_item from stock_items where id = p_item and deleted_at is not null for update;
  if not found then
    raise exception 'item_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_item.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update stock_items set deleted_at = null where id = p_item returning * into v_item;
  return v_item;
end;
$$;

-- ==================== grants ====================
-- Same treatment as every other business RPC (0015_grants.sql): no anon/PUBLIC
-- EXECUTE, authenticated only.
do $$
declare
  fns text[] := array[
    'archive_property(uuid)', 'restore_property(uuid)',
    'archive_unit(uuid)',     'restore_unit(uuid)',
    'archive_tenant(uuid)',   'restore_tenant(uuid)',
    'archive_stock_item(uuid)','restore_stock_item(uuid)'
  ];
  f text;
begin
  foreach f in array fns loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
