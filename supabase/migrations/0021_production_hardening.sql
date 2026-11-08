-- 0021 — production hardening.
--
-- Closes two member-management holes in 0014's admin_set_member_status:
--
--   1. The RPC let any *manager* change the status of an *owner*, so a manager
--      could suspend every owner and leave the workspace ownerless (and
--      themselves unremovable, because role changes are owner-only).
--   2. An owner could suspend themselves/last remaining owner, which locks the
--      organization out permanently — nothing in the app can make an owner
--      active again.
--
-- Only the function body changes; ownership and grants from 0015 are preserved
-- by CREATE OR REPLACE.

create or replace function public.admin_set_member_status(p_org uuid, p_user uuid, p_status text)
returns public.organization_members
language plpgsql security definer set search_path = public as $$
declare
  v_member public.organization_members;
  v_owners int;
  v_is_owner boolean;
begin
  v_is_owner := has_org_role(p_org, array['owner']::public.org_role[]);
  if not v_is_owner
     and not has_org_role(p_org, array['manager']::public.org_role[])
     and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('pending','active','suspended') then
    raise exception 'invalid_input' using errcode = '22023';
  end if;

  select * into v_member from organization_members
   where org_id = p_org and user_id = p_user for update;
  if not found then raise exception 'forbidden' using errcode = 'P0002'; end if;

  -- Only an owner may touch another owner.
  if v_member.role = 'owner' and not v_is_owner and not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Never leave the workspace with no active owner: that cannot be repaired
  -- from inside the app.
  if v_member.role = 'owner' and v_member.status = 'active' and p_status <> 'active' then
    select count(*) into v_owners from organization_members
     where org_id = p_org and role = 'owner' and status = 'active';
    if v_owners <= 1 then
      raise exception 'cannot_suspend_last_owner' using errcode = '23505';
    end if;
  end if;

  update organization_members set status = p_status
   where org_id = p_org and user_id = p_user returning * into v_member;
  if not found then raise exception 'forbidden' using errcode = 'P0002'; end if;
  return v_member;
end;
$$;
