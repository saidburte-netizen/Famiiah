-- 0012_rpcs_lists_reports.sql
-- dashboard_summary, list_properties_with_stats, list_units,
-- list_tenants_with_status, rent_overview, report_* RPCs.

-- ==================== dashboard_summary ====================
create or replace function public.dashboard_summary(p_org uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_month_start date := date_trunc('month', now())::date;
  v_month_end date := (date_trunc('month', now()) + interval '1 month - 1 day')::date;
  v_due jsonb;
  v record;
begin
  if not is_org_member(p_org) then raise exception 'forbidden' using errcode = '42501'; end if;

  select
    coalesce(sum(rc.amount) filter (where rc.period_start between v_month_start and v_month_end), 0) as expected,
    coalesce(sum(rc.amount_paid) filter (where rc.period_start between v_month_start and v_month_end), 0) as collected,
    count(*) filter (where rc.status = 'overdue') as overdue_count,
    coalesce(sum(rc.amount - rc.amount_paid) filter (where rc.status = 'overdue'), 0) as overdue_amount
    into v
    from rent_charges rc where rc.org_id = p_org;

  select coalesce(jsonb_agg(sub), '[]'::jsonb) into v_due from (
    select rc.id, rc.amount, rc.due_date, t.full_name as tenant_name, u.code as unit_code
      from rent_charges rc
      join leases l on l.id = rc.lease_id
      join tenants t on t.id = l.tenant_id
      join units u on u.id = l.unit_id
     where rc.org_id = p_org
       and rc.status in ('pending','partial','overdue')
       and rc.due_date between current_date and current_date + interval '7 days'
     order by rc.due_date limit 10
  ) sub;

  return jsonb_build_object(
    'collected_month', v.collected,
    'expected_month', v.expected,
    'collection_rate', case when v.expected > 0 then round(v.collected / v.expected * 100, 1) else 0 end,
    'properties_count', (select count(*) from properties where org_id = p_org and deleted_at is null),
    'units_total', (select count(*) from units where org_id = p_org and deleted_at is null),
    'units_rented', (select count(*) from units where org_id = p_org and status = 'rented' and deleted_at is null),
    'units_vacant', (select count(*) from units where org_id = p_org and status = 'vacant' and deleted_at is null),
    'active_tenants', (select count(*) from tenants where org_id = p_org and status = 'active' and deleted_at is null),
    'overdue_count', v.overdue_count,
    'overdue_amount', v.overdue_amount,
    'due_this_week', v_due,
    'unread_notifications', (select count(*) from notifications where user_id = (select auth.uid()) and status <> 'read')
  );
end;
$$;

-- ==================== list_properties_with_stats ====================
create or replace function public.list_properties_with_stats(
  p_org uuid, p_type public.property_type default null,
  p_search text default null, p_limit int default 20, p_offset int default 0)
returns table (
  id uuid, name text, type public.property_type, city text,
  cover_image_path text, units_total bigint, units_rented bigint,
  occupancy_pct numeric, monthly_total numeric, created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_org_member(p_org) then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
    select p.id, p.name, p.type, p.city, p.cover_image_path,
           count(u.id) as units_total,
           count(u.id) filter (where u.status = 'rented') as units_rented,
           case when count(u.id) > 0
                then round(count(u.id) filter (where u.status = 'rented')::numeric / count(u.id) * 100, 1)
                else 0 end as occupancy_pct,
           coalesce(sum(u.monthly_rent), 0) as monthly_total,
           p.created_at
      from properties p
      left join units u on u.property_id = p.id and u.deleted_at is null
     where p.org_id = p_org and p.deleted_at is null
       and (p_type is null or p.type = p_type)
       and (p_search is null or p.name % p_search)
     group by p.id
     order by p.created_at desc
     limit p_limit offset p_offset;
end;
$$;

-- ==================== list_units ====================
create or replace function public.list_units(
  p_property uuid, p_status public.unit_status default null,
  p_search text default null, p_limit int default 50, p_offset int default 0)
returns table (
  id uuid, code text, kind text, floor_label text, monthly_rent numeric,
  status public.unit_status, tenant_name text, overdue boolean
)
language plpgsql stable security definer set search_path = public as $$
declare v_org uuid;
begin
  select pr.org_id into v_org from properties pr where pr.id = p_property;
  if v_org is null or not is_org_member(v_org) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select u.id, u.code, u.kind, u.floor_label, u.monthly_rent, u.status,
           t.full_name as tenant_name,
           exists (
             select 1 from leases l join rent_charges rc on rc.lease_id = l.id
             where l.unit_id = u.id and l.status = 'active' and rc.status = 'overdue'
           ) as overdue
      from units u
      left join leases l on l.unit_id = u.id and l.status = 'active'
      left join tenants t on t.id = l.tenant_id
     where u.property_id = p_property and u.deleted_at is null
       and (p_status is null or u.status = p_status)
       and (p_search is null or u.code % p_search)
     order by u.code
     limit p_limit offset p_offset;
end;
$$;

-- ==================== list_tenants_with_status ====================
create or replace function public.list_tenants_with_status(
  p_org uuid, p_filter text default 'all', p_search text default null,
  p_limit int default 20, p_offset int default 0)
returns table (
  id uuid, full_name text, phone text, unit_code text, monthly_rent numeric,
  lease_end date, overdue_days int, status text
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_org_member(p_org) then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
    select t.id, t.full_name, t.phone, u.code as unit_code, l.monthly_rent,
           l.end_date as lease_end,
           case when exists (
             select 1 from rent_charges rc
             where rc.lease_id = l.id and rc.status = 'overdue'
           ) then (current_date - (select min(rc.due_date) from rent_charges rc
                                    where rc.lease_id = l.id and rc.status = 'overdue'))::int
           else 0 end as overdue_days,
           t.status
      from tenants t
      left join leases l on l.tenant_id = t.id and l.status = 'active'
      left join units u on u.id = l.unit_id
     where t.org_id = p_org and t.deleted_at is null
       and (p_search is null or t.full_name % p_search)
       and (
         p_filter = 'all'
         or (p_filter = 'active' and t.status = 'active')
         or (p_filter = 'overdue' and exists (
               select 1 from rent_charges rc where rc.lease_id = l.id and rc.status = 'overdue'))
         or (p_filter = 'expiring' and l.end_date is not null
               and l.end_date between current_date and current_date + interval '30 days')
       )
     order by t.created_at desc
     limit p_limit offset p_offset;
end;
$$;

-- ==================== rent_overview ====================
create or replace function public.rent_overview(
  p_org uuid, p_month date, p_status public.charge_status default null,
  p_search text default null, p_limit int default 50, p_offset int default 0)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_start date := date_trunc('month', p_month)::date;
  v_end date := (date_trunc('month', p_month) + interval '1 month - 1 day')::date;
  v_rows jsonb;
  v_expected numeric; v_collected numeric; v_outstanding numeric;
begin
  if not is_org_member(p_org) then raise exception 'forbidden' using errcode = '42501'; end if;

  select coalesce(sum(rc.amount),0), coalesce(sum(rc.amount_paid),0),
         coalesce(sum(rc.amount - rc.amount_paid),0)
    into v_expected, v_collected, v_outstanding
    from rent_charges rc
   where rc.org_id = p_org and rc.period_start between v_start and v_end;

  select coalesce(jsonb_agg(sub), '[]'::jsonb) into v_rows from (
    select rc.id, rc.amount, rc.amount_paid, rc.status, rc.due_date,
           t.full_name as tenant_name, u.code as unit_code, l.id as lease_id
      from rent_charges rc
      join leases l on l.id = rc.lease_id
      join tenants t on t.id = l.tenant_id
      join units u on u.id = l.unit_id
     where rc.org_id = p_org and rc.period_start between v_start and v_end
       and (p_status is null or rc.status = p_status)
       and (p_search is null or t.full_name % p_search or u.code % p_search)
     order by rc.due_date
     limit p_limit offset p_offset
  ) sub;

  return jsonb_build_object('rows', v_rows, 'expected', v_expected,
                            'collected', v_collected, 'outstanding', v_outstanding);
end;
$$;

-- ==================== reports ====================
create or replace function public.report_collections(
  p_org uuid, p_from date, p_to date, p_group_by text default 'month')
returns table (bucket text, expected numeric, collected numeric, outstanding numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_group_by = 'property' then
    return query
      select coalesce(p.name,'(none)') as bucket,
             sum(rc.amount) as expected, sum(rc.amount_paid) as collected,
             sum(rc.amount - rc.amount_paid) as outstanding
        from rent_charges rc
        join leases l on l.id = rc.lease_id
        join units u on u.id = l.unit_id
        join properties p on p.id = u.property_id
       where rc.org_id = p_org and rc.period_start between p_from and p_to
       group by p.name order by p.name;
  else
    return query
      select to_char(rc.period_start,'YYYY-MM') as bucket,
             sum(rc.amount), sum(rc.amount_paid), sum(rc.amount - rc.amount_paid)
        from rent_charges rc
       where rc.org_id = p_org and rc.period_start between p_from and p_to
       group by 1 order by 1;
  end if;
end;
$$;

create or replace function public.report_occupancy(p_org uuid, p_from date, p_to date)
returns table (bucket text, total_units bigint, rented_units bigint, occupancy_pct numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select p.name as bucket,
           count(u.id) as total_units,
           count(u.id) filter (where u.status = 'rented') as rented_units,
           case when count(u.id) > 0
                then round(count(u.id) filter (where u.status='rented')::numeric / count(u.id) * 100,1)
                else 0 end as occupancy_pct
      from properties p left join units u on u.property_id = p.id and u.deleted_at is null
     where p.org_id = p_org and p.deleted_at is null
     group by p.name order by p.name;
end;
$$;

create or replace function public.report_overdue_ageing(p_org uuid)
returns table (ageing text, charges bigint, amount numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select case
             when current_date - rc.due_date <= 30 then '0-30'
             when current_date - rc.due_date <= 60 then '31-60'
             when current_date - rc.due_date <= 90 then '61-90'
             else '90+' end as ageing,
           count(*), sum(rc.amount - rc.amount_paid)
      from rent_charges rc
     where rc.org_id = p_org and rc.status = 'overdue'
     group by 1 order by 1;
end;
$$;
