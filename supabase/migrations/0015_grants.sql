-- 0015_grants.sql
-- Lock down RPC execute privileges. Postgres grants EXECUTE to PUBLIC by default,
-- which would let anon call security-definer business functions. Revoke from
-- PUBLIC/anon and grant explicitly. check_app_version is the only anon-callable RPC
-- (granted in 0009).

-- Internal cron helpers: no client access at all.
revoke all on function public.prune_app_event_logs(int) from public, anon, authenticated;
revoke all on function public.invoke_edge_function(text) from public, anon, authenticated;

-- Atomic counter used for receipt numbers. It is only ever called from the
-- SECURITY DEFINER assign_receipt_no() trigger, which runs as the owner, so no
-- client role (public/anon/authenticated) needs EXECUTE on it.
revoke all on function public.next_number(uuid, text) from public, anon, authenticated;

-- Authenticated-only RPCs.
do $$
declare
  fns text[] := array[
    'create_organization(text, text)',
    'invite_member(uuid, text, text, public.org_role, text)',
    'accept_invitation(text)',
    'create_tenant_with_lease(uuid, jsonb, uuid, date, date, numeric, numeric, int, int)',
    'assign_tenant_to_unit(uuid, uuid, date, date, numeric, numeric, int, int)',
    'renew_lease(uuid, date, numeric)',
    'terminate_lease(uuid, date, text)',
    'generate_monthly_charges(uuid)',
    'mark_overdue_charges()',
    'dashboard_summary(uuid)',
    'list_properties_with_stats(uuid, public.property_type, text, int, int)',
    'list_units(uuid, public.unit_status, text, int, int)',
    'list_tenants_with_status(uuid, text, text, int, int)',
    'rent_overview(uuid, date, public.charge_status, text, int, int)',
    'report_collections(uuid, date, date, text)',
    'report_occupancy(uuid, date, date)',
    'report_overdue_ageing(uuid)',
    'stock_adjust(uuid, public.stock_movement_type, numeric, text, uuid)',
    'rent_stock_item(uuid, uuid, numeric, numeric, date)',
    'return_stock_item(uuid)',
    'list_low_stock(uuid)',
    'register_device_token(text, text)',
    'mark_notification_read(uuid)',
    'mark_all_notifications_read(uuid)',
    'send_reminder(uuid, public.notification_channel)',
    'send_reminders_bulk(uuid, date)',
    'log_client_event(text, text, text, jsonb, text, text, text)',
    'admin_list_members(uuid, text, int, int)',
    'admin_set_member_role(uuid, uuid, public.org_role)',
    'admin_set_member_status(uuid, uuid, text)',
    'admin_approve_member(uuid, uuid)',
    'admin_list_audit_logs(uuid, text, uuid, timestamptz, timestamptz, int, int)',
    'admin_publish_app_version(text, text, text, boolean, text, text)',
    'admin_set_feature_flag(text, uuid, boolean)',
    'admin_list_event_logs(text, timestamptz, timestamptz, int, int)'
  ];
  f text;
begin
  foreach f in array fns loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
