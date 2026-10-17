-- 0016_security_hardening.sql
-- Defense-in-depth fixes from the security review. All additive: nothing from an
-- earlier migration is edited, and every change tightens rather than loosens.
--
--  1. `invitations` is no longer readable by every member, and the bearer
--     credential (`token_hash`) is not selectable by any client role.
--  2. `accept_invitation` fails closed: it can only be claimed by the exact
--     email or phone the invitation was addressed to.
--  3. `invite_member` cannot mint an `owner` invitation unless the caller is one.
--  4. The cron-only charge RPCs are no longer callable by client roles.
--  5. `assign_tenant_to_unit` cannot attach a tenant from another org.
--  6. Avatar writes are scoped to the caller's own storage folder.
--  7. `admin_set_member_status` cannot be used by a manager to lock out an owner.
--  8. `register_device_token` cannot reassign an existing token to a new user.
--  9. DML on RPC-only tables is revoked from client roles.

-- ==================== 1. invitations ====================
-- Any member (including `viewer`) could read every invitation in the org,
-- including `token_hash`. Restrict the rows to the people who manage them...
drop policy if exists invitations_select_member on public.invitations;
create policy invitations_select_admin on public.invitations
  for select to authenticated
  using (has_org_role(org_id, array['owner','manager']::public.org_role[]));

-- ...and remove the credential from every client role at the column level, so a
-- stray `select *` cannot leak it. `service_role` (Edge Functions) is unaffected.
revoke select on public.invitations from anon, authenticated;
grant select (id, org_id, email, phone, role, invited_by, expires_at, accepted_at, created_at)
  on public.invitations to authenticated;

-- ==================== 2. accept_invitation (fail closed) ====================
-- The previous check was skipped whenever either side was NULL, so a phone-only
-- invitation could be claimed by anyone holding the token.
create or replace function public.accept_invitation(p_token_hash text)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := (select auth.uid());
  v_inv public.invitations;
  v_email text;
  v_phone text;
  v_member public.organization_members;
begin
  if v_uid is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select au.email::text, au.phone::text into v_email, v_phone
    from auth.users au where au.id = v_uid;

  select * into v_inv from invitations
   where token_hash = p_token_hash and accepted_at is null
   for update;

  if not found then
    raise exception 'invalid_token' using errcode = 'P0002';
  end if;
  if v_inv.expires_at < now() then
    raise exception 'invitation_expired' using errcode = '22023';
  end if;

  -- Fail closed: the caller must be exactly who the invitation was addressed to.
  if v_inv.email is not null then
    if v_email is null or lower(v_inv.email) <> lower(v_email) then
      raise exception 'forbidden' using errcode = '42501';
    end if;
  elsif v_inv.phone is not null then
    if v_phone is null or v_inv.phone <> v_phone then
      raise exception 'forbidden' using errcode = '42501';
    end if;
  else
    -- The table check constraint forbids this, but never trust it here.
    raise exception 'invalid_token' using errcode = 'P0002';
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

-- ==================== 3. invite_member ====================
-- A manager could invite an `owner`, i.e. escalate someone (or an accomplice)
-- straight to owner. Only an owner may hand out owner.
create or replace function public.invite_member(
  p_org uuid, p_email text, p_phone text, p_role public.org_role, p_token_hash text)
returns public.invitations
language plpgsql security definer set search_path = public as $$
declare v_inv public.invitations;
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_role = 'owner' and not has_org_role(p_org, array['owner']::public.org_role[]) then
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

-- ==================== 4. cron-only charge RPCs ====================
-- Granted to `authenticated` in 0015, but both are scheduled jobs that run as
-- the job owner. No client should be able to generate or age charges for an
-- arbitrary org.
revoke all on function public.generate_monthly_charges(uuid) from public, anon, authenticated;
revoke all on function public.mark_overdue_charges() from public, anon, authenticated;

-- ==================== 5. assign_tenant_to_unit ====================
-- The unit's org was checked but the tenant's was not, so a staff member could
-- attach a tenant from another org to one of their units.
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
  if p_tenant is null or not exists (
    select 1 from tenants t
     where t.id = p_tenant and t.org_id = v_unit.org_id and t.deleted_at is null
  ) then
    raise exception 'tenant_not_found' using errcode = 'P0002';
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

-- ==================== 6. avatars ====================
-- Writes were unscoped: any authenticated user could upload/overwrite at any
-- path in the shared bucket. Scope writes to `{user_id}/...`.
drop policy if exists "own write avatars" on storage.objects;
drop policy if exists "own update avatars" on storage.objects;
create policy "own write avatars" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy "own update avatars" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ==================== 7. admin_set_member_status ====================
-- A manager could suspend an owner (lockout). Owners (and platform admins) are
-- the only ones who may change an owner's status.
create or replace function public.admin_set_member_status(p_org uuid, p_user uuid, p_status text)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare v_member public.organization_members;
begin
  if not has_org_role(p_org, array['owner','manager']::public.org_role[]) and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('pending','active','suspended') then
    raise exception 'invalid_input' using errcode = '22023';
  end if;

  select * into v_member from organization_members
   where org_id = p_org and user_id = p_user
   for update;
  if not found then
    raise exception 'forbidden' using errcode = 'P0002';
  end if;

  if v_member.role = 'owner'
     and not has_org_role(p_org, array['owner']::public.org_role[])
     and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update organization_members set status = p_status
   where org_id = p_org and user_id = p_user
   returning * into v_member;

  return v_member;
end;
$$;

-- ==================== 8. register_device_token ====================
-- `on conflict (token) do update ... user_id = excluded.user_id` let anyone who
-- learned a token reassign another user's device to themselves (push hijack).
create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or length(p_token) = 0 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  if exists (
    select 1 from device_tokens
     where token = p_token and user_id <> (select auth.uid())
  ) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  insert into device_tokens (user_id, token, platform)
  values ((select auth.uid()), p_token, p_platform)
  on conflict (token) do update set platform = excluded.platform;
end;
$$;

-- ==================== 9. profiles INSERT columns ====================
-- The row is normally created by the `on_auth_user_created` trigger, but the
-- self-insert policy allowed a crafted insert to set `is_platform_admin`.
revoke insert on public.profiles from anon, authenticated;
grant insert (id, full_name, phone, avatar_url, locale) on public.profiles to authenticated;

-- ==================== 10. RPC-only tables: no client DML ====================
-- These tables are only written by SECURITY DEFINER RPCs and triggers. They have
-- no client write *policies*, so nothing was ever reachable; revoke the
-- privileges too so a future policy can't silently open a write path.
revoke insert, update, delete, truncate on
  public.rent_charges,
  public.payments,
  public.payment_allocations,
  public.stock_movements,
  public.stock_rentals,
  public.org_counters
from anon, authenticated;
