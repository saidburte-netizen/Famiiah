-- 0005_rls.sql
-- Row Level Security: helper functions, enable RLS on every public table,
-- and per-table policies. Deny by default. Multi-tenant by org_id.

-- ==================== helper functions ====================
create or replace function public.is_org_member(p_org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from organization_members m
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function public.has_org_role(p_org uuid, p_roles public.org_role[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from organization_members m
    where m.org_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and m.role = any(p_roles)
  );
$$;

create or replace function public.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from profiles where id = (select auth.uid())), false);
$$;

create or replace function public.require_platform_admin(p_require_mfa boolean default true) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_require_mfa and coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'mfa_required' using errcode = '42501';
  end if;
end $$;

revoke all on function public.is_org_member(uuid),
  public.has_org_role(uuid, public.org_role[]),
  public.is_platform_admin(),
  public.require_platform_admin(boolean) from public, anon;

grant execute on function public.is_org_member(uuid),
  public.has_org_role(uuid, public.org_role[]),
  public.is_platform_admin(),
  public.require_platform_admin(boolean) to authenticated;

-- convenience role arrays
-- owner/manager: ['owner','manager']
-- staff+: ['owner','manager','staff']

-- ==================== profiles ====================
alter table public.profiles enable row level security;
create policy profiles_select_own_or_comember on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or is_platform_admin()
    or exists (
      select 1 from organization_members me
      join organization_members them
        on them.org_id = me.org_id and them.user_id = profiles.id
      where me.user_id = (select auth.uid()) and me.status = 'active' and them.status = 'active'
    )
  );
-- users may edit only their own row; is_platform_admin cannot be self-set (column grant below)
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));
-- no delete policy

-- lock is_platform_admin from client writes via column-level privilege
revoke update on public.profiles from authenticated;
grant update (full_name, phone, avatar_url, locale) on public.profiles to authenticated;

-- ==================== organizations ====================
alter table public.organizations enable row level security;
create policy organizations_select_member on public.organizations
  for select to authenticated using (is_org_member(id) or is_platform_admin());
create policy organizations_update_owner on public.organizations
  for update to authenticated
  using (has_org_role(id, array['owner']::public.org_role[]))
  with check (has_org_role(id, array['owner']::public.org_role[]));
-- creation happens via create_organization RPC; direct insert blocked
-- (no insert/delete policies)

-- ==================== organization_members ====================
alter table public.organization_members enable row level security;
create policy organization_members_select_member on public.organization_members
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());
-- no direct client writes; managed through admin_* RPCs only

-- ==================== invitations ====================
alter table public.invitations enable row level security;
create policy invitations_select_member on public.invitations
  for select to authenticated using (is_org_member(org_id));
-- writes via invite_member / accept_invitation RPCs only

-- ==================== properties ====================
alter table public.properties enable row level security;
create policy properties_select on public.properties
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());
create policy properties_insert on public.properties
  for insert to authenticated
  with check (has_org_role(org_id, array['owner','manager']::public.org_role[]));
create policy properties_update on public.properties
  for update to authenticated
  using (has_org_role(org_id, array['owner','manager']::public.org_role[]))
  with check (has_org_role(org_id, array['owner','manager']::public.org_role[]));
-- no delete policy: archive via deleted_at

-- ==================== units ====================
alter table public.units enable row level security;
create policy units_select on public.units
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());
create policy units_insert on public.units
  for insert to authenticated
  with check (has_org_role(org_id, array['owner','manager']::public.org_role[]));
create policy units_update on public.units
  for update to authenticated
  using (has_org_role(org_id, array['owner','manager']::public.org_role[]))
  with check (has_org_role(org_id, array['owner','manager']::public.org_role[]));
-- archive via deleted_at; no delete policy

-- ==================== tenants ====================
alter table public.tenants enable row level security;
create policy tenants_select on public.tenants
  for select to authenticated
  using (
    is_org_member(org_id)
    or user_id = (select auth.uid())   -- the tenant themself
    or is_platform_admin()
  );
create policy tenants_insert on public.tenants
  for insert to authenticated
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));
create policy tenants_update on public.tenants
  for update to authenticated
  using (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]))
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));
-- archive via deleted_at; no delete policy

-- ==================== leases ====================
alter table public.leases enable row level security;
create policy leases_select on public.leases
  for select to authenticated
  using (
    is_org_member(org_id)
    or exists (select 1 from tenants t where t.id = tenant_id and t.user_id = (select auth.uid()))
    or is_platform_admin()
  );
-- writes through create/assign/renew/terminate RPCs only

-- ==================== rent_charges ====================  (RPC only for writes)
alter table public.rent_charges enable row level security;
create policy rent_charges_select on public.rent_charges
  for select to authenticated
  using (
    is_org_member(org_id)
    or exists (
      select 1 from leases l join tenants t on t.id = l.tenant_id
      where l.id = lease_id and t.user_id = (select auth.uid())
    )
    or is_platform_admin()
  );
-- no insert/update/delete policies

-- ==================== org_counters ====================  (internal only)
alter table public.org_counters enable row level security;
-- no policies: only security-definer functions touch this

-- ==================== payments / allocations ====================  (RPC only for writes)
alter table public.payments enable row level security;
create policy payments_select on public.payments
  for select to authenticated
  using (
    is_org_member(org_id)
    or exists (
      select 1 from tenants t
      where t.id = tenant_id and t.user_id = (select auth.uid())
    )
    or is_platform_admin()
  );
-- no write policies

alter table public.payment_allocations enable row level security;
create policy payment_allocations_select on public.payment_allocations
  for select to authenticated
  using (
    exists (
      select 1 from payments p where p.id = payment_id
    )
  );
-- no write policies

-- ==================== stock_items ====================
alter table public.stock_items enable row level security;
create policy stock_items_select on public.stock_items
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());
create policy stock_items_insert on public.stock_items
  for insert to authenticated
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));
create policy stock_items_update on public.stock_items
  for update to authenticated
  using (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]))
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));
create policy stock_items_delete on public.stock_items
  for delete to authenticated
  using (has_org_role(org_id, array['owner','manager']::public.org_role[]));

-- ==================== stock_movements ====================  (RPC only for writes)
alter table public.stock_movements enable row level security;
create policy stock_movements_select on public.stock_movements
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());

-- ==================== stock_rentals ====================  (RPC only for writes)
alter table public.stock_rentals enable row level security;
create policy stock_rentals_select on public.stock_rentals
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());

-- ==================== maintenance_requests ====================
alter table public.maintenance_requests enable row level security;
create policy maintenance_select on public.maintenance_requests
  for select to authenticated using (is_org_member(org_id) or is_platform_admin());
create policy maintenance_insert on public.maintenance_requests
  for insert to authenticated
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));
create policy maintenance_update on public.maintenance_requests
  for update to authenticated
  using (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]))
  with check (has_org_role(org_id, array['owner','manager','staff']::public.org_role[]));

-- ==================== notifications ====================
alter table public.notifications enable row level security;
create policy notifications_select_recipient on public.notifications
  for select to authenticated
  using (user_id = (select auth.uid()) or is_platform_admin());
create policy notifications_update_recipient on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
-- creation via RPC / edge function only

-- ==================== device_tokens ====================
alter table public.device_tokens enable row level security;
create policy device_tokens_select_own on public.device_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy device_tokens_insert_own on public.device_tokens
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy device_tokens_delete_own on public.device_tokens
  for delete to authenticated using (user_id = (select auth.uid()));

-- ==================== logs ====================
-- audit_logs: read for org owner/manager or platform admin; append-only (no client writes)
alter table public.audit_logs enable row level security;
create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (has_org_role(org_id, array['owner','manager']::public.org_role[]) or is_platform_admin());

-- app_event_logs: insert via log_client_event RPC only; read for platform admin
alter table public.app_event_logs enable row level security;
create policy app_event_logs_select_platform on public.app_event_logs
  for select to authenticated using (is_platform_admin());

-- ==================== versioning & flags ====================
alter table public.app_versions enable row level security;
-- read via check_app_version RPC; management via admin RPC only
create policy app_versions_select_platform on public.app_versions
  for select to authenticated using (is_platform_admin());

alter table public.feature_flags enable row level security;
create policy feature_flags_select on public.feature_flags
  for select to authenticated
  using (org_id is null or is_org_member(org_id) or is_platform_admin());
-- management via admin_set_feature_flag RPC only

-- anon read access for version gate
grant select on public.app_versions to anon;
grant execute on function public.check_app_version(text, text) to anon;
