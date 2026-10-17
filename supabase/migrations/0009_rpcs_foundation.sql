-- 0009_rpcs_foundation.sql
-- check_app_version (anon), create_organization, invite_member, accept_invitation.

-- ==================== check_app_version ====================
-- Compare 'x.y.z' strings as int arrays so '1.10.0' > '1.9.0'.
create or replace function public.check_app_version(p_platform text, p_version text)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v record;
  v_status text := 'ok';
  v_latest text;
  v_min text;
begin
  select version, min_supported_version, force_update, store_url, release_notes
    into v
    from app_versions
   where platform = p_platform and is_active = true
   order by released_at desc
   limit 1;

  if not found then
    return jsonb_build_object('status','ok');
  end if;

  v_latest := v.version;
  v_min := v.min_supported_version;

  if (select string_to_array(p_version,'.')::int[] < string_to_array(v_min,'.')::int[]) then
    v_status := 'force_update';
  elsif v.force_update and (select string_to_array(p_version,'.')::int[] < string_to_array(v_latest,'.')::int[]) then
    v_status := 'force_update';
  elsif (select string_to_array(p_version,'.')::int[] < string_to_array(v_latest,'.')::int[]) then
    v_status := 'update_available';
  else
    v_status := 'ok';
  end if;

  return jsonb_build_object(
    'status', v_status,
    'latest', v_latest,
    'min_supported', v_min,
    'store_url', v.store_url,
    'notes', v.release_notes
  );
end;
$$;

-- The version gate is callable without a session (used on Splash before login).
grant execute on function public.check_app_version(text, text) to anon, authenticated;

-- ==================== create_organization ====================
-- Caller becomes owner. Creates org + owner membership atomically.
create or replace function public.create_organization(p_name text, p_slug text default null)
returns public.organizations
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_slug text;
  v_org public.organizations;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;

  v_slug := coalesce(
    nullif(trim(p_slug), ''),
    regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g')
  );

  insert into organizations (name, slug, created_by)
  values (trim(p_name), v_slug, v_uid)
  returning * into v_org;

  insert into organization_members (org_id, user_id, role, status)
  values (v_org.id, v_uid, 'owner', 'active');

  return v_org;
end;
$$;

-- ==================== invite_member ====================
-- Creates an invitation row; the invite-member Edge Function emails the deep link.
-- p_token_hash is supplied by the caller (Edge Function hashes the raw token).
create or replace function public.invite_member(
  p_org uuid, p_email text, p_phone text, p_role public.org_role, p_token_hash text)
returns public.invitations
language plpgsql security definer set search_path = public as $$
declare v_inv public.invitations;
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_token_hash is null or length(p_token_hash) = 0 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  if p_email is null and p_phone is null then
    raise exception 'invalid_input' using errcode = '22023';
  end if;

  insert into invitations (org_id, email, phone, role, token_hash, invited_by)
  values (p_org, p_email, p_phone, p_role, p_token_hash, (select auth.uid()))
  returning * into v_inv;

  return v_inv;
end;
$$;

-- ==================== accept_invitation ====================
-- p_token is the raw token; we match by hashing is not possible here without the
-- client, so the Edge Function passes the token and we look up by token_hash equality
-- using a caller-supplied hash. For direct use, the client sends the raw token and
-- the Edge Function resolves the invitation. This RPC accepts an already-resolved
-- invitation id for in-app acceptance by an authenticated user whose email matches.
create or replace function public.accept_invitation(p_token_hash text)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.invitations;
  v_email text;
  v_member public.organization_members;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select au.email::text into v_email from auth.users au where au.id = v_uid;

  select * into v_inv from invitations
   where token_hash = p_token_hash and accepted_at is null
   for update;

  if not found then
    raise exception 'invalid_token' using errcode = 'P0002';
  end if;
  if v_inv.expires_at < now() then
    raise exception 'invitation_expired' using errcode = '22023';
  end if;
  if v_inv.email is not null and v_email is not null and lower(v_inv.email) <> lower(v_email) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into organization_members (org_id, user_id, role, status)
  values (v_inv.org_id, v_uid, v_inv.role, 'active')
  on conflict (org_id, user_id)
  do update set role = excluded.role, status = 'active'
  returning * into v_member;

  update invitations set accepted_at = now() where id = v_inv.id;

  return v_member;
end;
$$;
