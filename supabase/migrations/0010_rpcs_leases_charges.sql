-- 0010_rpcs_leases_charges.sql
-- create_tenant_with_lease, assign_tenant_to_unit, renew_lease, terminate_lease,
-- generate_monthly_charges, mark_overdue_charges.

-- ==================== create_tenant_with_lease ====================
-- Creates a tenant and an active lease in one transaction, and sets the unit rented.
create or replace function public.create_tenant_with_lease(
  p_org uuid,
  p_tenant jsonb,
  p_unit uuid,
  p_start date,
  p_end date default null,
  p_rent numeric default 0,
  p_deposit numeric default 0,
  p_billing_day int default 1,
  p_grace_days int default 5
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_tenant public.tenants;
  v_lease public.leases;
  v_unit public.units;
begin
  if not has_org_role(p_org, array['owner','manager','staff']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_rent is null or p_rent < 0 then
    raise exception 'invalid_amount' using errcode = '22023';
  end if;

  select * into v_unit from units where id = p_unit and org_id = p_org and deleted_at is null for update;
  if not found then
    raise exception 'unit_not_found' using errcode = 'P0002';
  end if;

  -- a unit can only host one active lease
  if exists (select 1 from leases where unit_id = p_unit and status = 'active') then
    raise exception 'unit_not_vacant' using errcode = '23505';
  end if;

  insert into tenants (org_id, full_name, business_name, phone, email)
  values (
    p_org,
    nullif(p_tenant->>'fullName',''),
    nullif(p_tenant->>'businessName',''),
    nullif(p_tenant->>'phone',''),
    nullif(p_tenant->>'email','')
  )
  returning * into v_tenant;

  insert into leases (org_id, unit_id, tenant_id, start_date, end_date, monthly_rent,
                      deposit_amount, billing_day, grace_days, status)
  values (p_org, p_unit, v_tenant.id, p_start, p_end, p_rent, p_deposit,
          p_billing_day, p_grace_days, 'active')
  returning * into v_lease;

  -- trigger sets unit rented; ensure explicitly in case status already rented
  update units set status = 'rented' where id = p_unit and status <> 'rented';

  return jsonb_build_object('tenant', to_jsonb(v_tenant), 'lease', to_jsonb(v_lease));
end;
$$;

-- ==================== assign_tenant_to_unit ====================
create or replace function public.assign_tenant_to_unit(
  p_unit uuid, p_tenant uuid, p_start date, p_end date default null,
  p_rent numeric default 0, p_deposit numeric default 0,
  p_billing_day int default 1, p_grace_days int default 5)
returns public.leases
language plpgsql security definer set search_path = public as $$
declare
  v_unit public.units;
  v_lease public.leases;
begin
  select * into v_unit from units where id = p_unit and deleted_at is null for update;
  if not found then
    raise exception 'unit_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_unit.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if exists (select 1 from leases where unit_id = p_unit and status = 'active') then
    raise exception 'unit_not_vacant' using errcode = '23505';
  end if;

  insert into leases (org_id, unit_id, tenant_id, start_date, end_date, monthly_rent,
                      deposit_amount, billing_day, grace_days, status)
  values (v_unit.org_id, p_unit, p_tenant, p_start, p_end, p_rent, p_deposit,
          p_billing_day, p_grace_days, 'active')
  returning * into v_lease;

  update units set status = 'rented' where id = p_unit and status <> 'rented';

  return v_lease;
end;
$$;

-- ==================== renew_lease ====================
create or replace function public.renew_lease(p_lease uuid, p_new_end date, p_new_rent numeric default null)
returns public.leases
language plpgsql security definer set search_path = public as $$
declare v_lease public.leases;
begin
  select * into v_lease from leases where id = p_lease for update;
  if not found then
    raise exception 'lease_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_lease.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_new_end is null or p_new_end < v_lease.start_date then
    raise exception 'invalid_input' using errcode = '22023';
  end if;

  update leases
     set end_date = p_new_end,
         monthly_rent = coalesce(p_new_rent, monthly_rent),
         status = 'active'
   where id = p_lease
   returning * into v_lease;
  return v_lease;
end;
$$;

-- ==================== terminate_lease ====================
create or replace function public.terminate_lease(p_lease uuid, p_end_date date, p_reason text default null)
returns public.leases
language plpgsql security definer set search_path = public as $$
declare v_lease public.leases;
begin
  select * into v_lease from leases where id = p_lease for update;
  if not found then
    raise exception 'lease_not_found' using errcode = 'P0002';
  end if;
  if not has_org_role(v_lease.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update leases
     set status = 'terminated', end_date = coalesce(p_end_date, end_date), ended_reason = p_reason
   where id = p_lease
   returning * into v_lease;

  -- trigger frees the unit; ensure it is vacant
  update units set status = 'vacant' where id = v_lease.unit_id and status = 'rented';

  return v_lease;
end;
$$;

-- ==================== generate_monthly_charges ====================
-- Idempotent: on conflict (lease_id, period_start) do nothing.
-- For each active lease, create the charge for the target month if missing.
create or replace function public.generate_monthly_charges(p_org uuid default null)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_lease record;
  v_period_start date;
  v_period_end date;
  v_due date;
  v_created int := 0;
  v_target_month date := date_trunc('month', now())::date;
begin
  for v_lease in
    select l.id, l.org_id, l.monthly_rent, l.billing_day, o.default_billing_day
      from leases l
      join organizations o on o.id = l.org_id
     where l.status = 'active'
       and (p_org is null or l.org_id = p_org)
       and (l.end_date is null or l.end_date >= v_target_month)
  loop
    v_period_start := v_target_month;
    v_period_end := (v_target_month + interval '1 month - 1 day')::date;
    v_due := (v_period_start + make_interval(days => coalesce(v_lease.billing_day, v_lease.default_billing_day) - 1))::date;

    insert into rent_charges (org_id, lease_id, period_start, period_end, due_date, amount, status)
    values (v_lease.org_id, v_lease.id, v_period_start, v_period_end, v_due, v_lease.monthly_rent, 'pending')
    on conflict (lease_id, period_start) do nothing;

    if found then
      v_created := v_created + 1;
    end if;
  end loop;

  return v_created;
end;
$$;

-- ==================== mark_overdue_charges ====================
-- pending/partial charges whose due_date + grace_days has passed become overdue.
create or replace function public.mark_overdue_charges() returns int
language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  with updated as (
    update rent_charges rc
       set status = 'overdue'
      from leases l
     where rc.lease_id = l.id
       and rc.status in ('pending','partial')
       and rc.due_date + make_interval(days => l.grace_days) < current_date
    returning rc.id
  )
  select count(*) into v_count from updated;
  return v_count;
end;
$$;
