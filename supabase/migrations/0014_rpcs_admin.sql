-- 0014_rpcs_admin.sql
-- Org admin (members/roles/audit) and platform-admin (versions/flags/logs) RPCs.
-- Each re-checks the caller server-side (the "admin gate" inner layer).

-- ==================== admin_list_members ====================
create or replace function public.admin_list_members(
  p_org uuid, p_search text default null, p_limit int default 50, p_offset int default 0)
returns table (user_id uuid, full_name text, phone text, email text,
               role public.org_role, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select m.user_id, pr.full_name, pr.phone, au.email::text,
           m.role, m.status, m.created_at
      from organization_members m
      join profiles pr on pr.id = m.user_id
      left join auth.users au on au.id = m.user_id
     where m.org_id = p_org
       and (p_search is null or pr.full_name % p_search)
     order by m.created_at
     limit p_limit offset p_offset;
end;
$$;

-- ==================== admin_set_member_role ====================
-- An owner cannot demote the last owner.
create or replace function public.admin_set_member_role(p_org uuid, p_user uuid, p_role public.org_role)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare v_member public.organization_members; v_owners int;
begin
  if not has_org_role(p_org, array['owner']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select * into v_member from organization_members
   where org_id = p_org and user_id = p_user for update;
  if not found then raise exception 'forbidden' using errcode = 'P0002'; end if;

  if v_member.role = 'owner' and p_role <> 'owner' then
    select count(*) into v_owners from organization_members
     where org_id = p_org and role = 'owner' and status = 'active';
    if v_owners <= 1 then
      raise exception 'cannot_demote_last_owner' using errcode = '23505';
    end if;
  end if;

  update organization_members set role = p_role
   where org_id = p_org and user_id = p_user returning * into v_member;

  insert into audit_logs(org_id, actor_id, action, table_name, record_id, new_data)
  values (p_org, (select auth.uid()), 'role.change', 'organization_members', null,
          jsonb_build_object('user_id', p_user, 'role', p_role));

  return v_member;
end;
$$;

-- ==================== admin_set_member_status ====================
create or replace function public.admin_set_member_status(p_org uuid, p_user uuid, p_status text)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare v_member public.organization_members;
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('pending','active','suspended') then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  update organization_members set status = p_status
   where org_id = p_org and user_id = p_user returning * into v_member;
  if not found then raise exception 'forbidden' using errcode = 'P0002'; end if;
  return v_member;
end;
$$;

-- ==================== admin_approve_member ====================
create or replace function public.admin_approve_member(p_org uuid, p_user uuid)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
begin
  return public.admin_set_member_status(p_org, p_user, 'active');
end;
$$;

-- ==================== admin_list_audit_logs ====================
create or replace function public.admin_list_audit_logs(
  p_org uuid, p_table text default null, p_actor uuid default null,
  p_from timestamptz default null, p_to timestamptz default null,
  p_limit int default 50, p_offset int default 0)
returns setof public.audit_logs
language plpgsql stable security definer set search_path = public as $$
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select * from audit_logs
     where org_id = p_org
       and (p_table is null or table_name = p_table)
       and (p_actor is null or actor_id = p_actor)
       and (p_from is null or created_at >= p_from)
       and (p_to is null or created_at <= p_to)
     order by created_at desc
     limit p_limit offset p_offset;
end;
$$;

-- ==================== platform admin (AAL2 required) ====================
create or replace function public.admin_publish_app_version(
  p_platform text, p_version text, p_min_supported text,
  p_force boolean default false, p_store_url text default null, p_notes text default null)
returns public.app_versions
language plpgsql security definer set search_path = public as $$
declare v_row public.app_versions;
begin
  perform require_platform_admin(true);
  insert into app_versions (platform, version, min_supported_version, force_update, store_url, release_notes)
  values (p_platform, p_version, p_min_supported, p_force, p_store_url, p_notes)
  returning * into v_row;
  insert into audit_logs(actor_id, action, table_name, record_id, new_data)
  values ((select auth.uid()), 'version.publish', 'app_versions', v_row.id, to_jsonb(v_row));
  return v_row;
end;
$$;

create or replace function public.admin_set_feature_flag(p_key text, p_org uuid, p_enabled boolean)
returns public.feature_flags
language plpgsql security definer set search_path = public as $$
declare v_row public.feature_flags;
begin
  perform require_platform_admin(true);
  insert into feature_flags (key, org_id, enabled)
  values (p_key, p_org, p_enabled)
  on conflict (key, org_id) do update set enabled = excluded.enabled, updated_at = now()
  returning * into v_row;
  insert into audit_logs(org_id, actor_id, action, table_name, record_id, new_data)
  values (p_org, (select auth.uid()), 'flag.change', 'feature_flags', null, to_jsonb(v_row));
  return v_row;
end;
$$;

create or replace function public.admin_list_event_logs(
  p_level text default null, p_from timestamptz default null, p_to timestamptz default null,
  p_limit int default 100, p_offset int default 0)
returns setof public.app_event_logs
language plpgsql stable security definer set search_path = public as $$
begin
  perform require_platform_admin(true);
  return query
    select * from app_event_logs
     where (p_level is null or level = p_level)
       and (p_from is null or created_at >= p_from)
       and (p_to is null or created_at <= p_to)
     order by created_at desc
     limit p_limit offset p_offset;
end;
$$;
