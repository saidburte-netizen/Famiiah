-- ============================================================================
-- PART 5 — grants / privilege lockdown   (runs as postgres; metadata only)
-- ============================================================================
begin;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'anon can execute check_app_version (version gate)' as name,
         (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname = 'check_app_version') as ok,
         null::text as detail
  union all
  select 'anon cannot execute business RPCs',
         not (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('create_organization','record_payment','void_payment',
                                   'dashboard_summary','stock_adjust','log_client_event',
                                   'admin_list_members','invite_member')), null
  union all
  select 'anon cannot execute prune_app_event_logs / invoke_edge_function',
         not (select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('prune_app_event_logs','invoke_edge_function')), null
  union all
  select 'authenticated can execute the business RPCs',
         (select bool_and(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
            from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public'
             and p.proname in ('create_organization','invite_member','accept_invitation',
                               'create_tenant_with_lease','assign_tenant_to_unit','renew_lease',
                               'terminate_lease','generate_monthly_charges','mark_overdue_charges',
                               'record_payment','void_payment','dashboard_summary','list_units',
                               'rent_overview','report_collections','stock_adjust','rent_stock_item',
                               'return_stock_item','register_device_token','mark_notification_read',
                               'send_reminder','send_reminders_bulk','log_client_event',
                               'admin_list_members','admin_set_member_role','admin_set_member_status',
                               'admin_publish_app_version','admin_set_feature_flag')), null
  union all
  select 'authenticated cannot execute internal cron helpers',
         not (select bool_or(has_function_privilege('authenticated', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname in ('prune_app_event_logs','invoke_edge_function')), null
  union all
  -- Should PASS now that migration 0015 revokes EXECUTE from PUBLIC/anon/
  -- authenticated on public.next_number(uuid, text). If it FAILs, the fix was
  -- not applied to this database (run the FIX block after this part).
  select 'FINDING: next_number is not executable by anon',
         not coalesce((select bool_or(has_function_privilege('anon', p.oid, 'EXECUTE'))
                from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'next_number'), false),
         'if FAIL run the FIX block after this part'
  union all
  select 'authenticated cannot self-promote via column privilege',
         not has_column_privilege('authenticated','public.profiles','is_platform_admin','UPDATE'), null
  union all
  select 'authenticated can update their own profile columns',
         has_column_privilege('authenticated','public.profiles','full_name','UPDATE'), null
  union all
  select 'no RLS policy targets the anon role',
         (select count(*) from pg_policies where schemaname = 'public' and 'anon' = any(roles)) = 0, null
) c order by ok, name;

rollback;

-- FIX for older databases that were migrated before 0015 revoked next_number
-- (this is already part of migration 0015, so a fresh install does not need it):
-- revoke all on function public.next_number(uuid, text) from public, anon, authenticated;

