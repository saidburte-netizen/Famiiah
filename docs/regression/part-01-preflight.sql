-- ============================================================================
-- PART 1 — preflight / schema inventory  (read-only)
-- ============================================================================
begin;

with c as (
  select 'server major version >= 15' as name,
         (current_setting('server_version_num')::int >= 150000) as ok,
         current_setting('server_version') as detail
  union all
  select 'auth schema present',
         exists (select 1 from pg_namespace where nspname = 'auth'), null
  union all
  select 'storage schema present',
         exists (select 1 from pg_namespace where nspname = 'storage'), null
  union all
  select 'extensions pg_trgm + pgcrypto installed',
         (select count(*) from pg_extension where extname in ('pg_trgm','pgcrypto')) = 2,
         (select string_agg(extname, ', ' order by extname) from pg_extension)
  union all
  select 'all 22 public tables exist',
         (select count(*) from pg_class cl join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r'
             and c.relname in ('profiles','organizations','organization_members','invitations',
               'properties','units','tenants','leases','org_counters','rent_charges','payments',
               'payment_allocations','stock_items','stock_movements','stock_rentals',
               'maintenance_requests','notifications','device_tokens','audit_logs',
               'app_event_logs','app_versions','feature_flags')) = 22,
         (select count(*)::text || ' tables in public'
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r')
  union all
  select 'RLS enabled on every public table',
         not exists (
           select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
         (select string_agg(c.relname, ', ' order by c.relname)
            from pg_class c join pg_namespace n on n.oid = c.relnamespace
           where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity)
  union all
  select 'storage buckets (5)',
         (select count(*) from storage.buckets
           where id in ('property-images','tenant-documents','lease-documents','receipts','avatars')) = 5,
         (select string_agg(id, ', ' order by id) from storage.buckets)
  union all
  select 'realtime publication lists 4 tables',
         (select count(*) from pg_publication_tables
           where pubname = 'supabase_realtime' and schemaname = 'public'
             and tablename in ('rent_charges','payments','notifications','stock_items')) = 4,
         null
  union all
  select 'updated_at triggers installed (11)',
         (select count(*) from pg_trigger where not tgisinternal and tgname like 'set_updated_at_%') = 11,
         (select count(*)::text from pg_trigger where not tgisinternal and tgname like 'set_updated_at_%')
  union all
  select 'audit triggers installed (11)',
         (select count(*) from pg_trigger where not tgisinternal and tgname like 'audit_%') = 11,
         (select count(*)::text from pg_trigger where not tgisinternal and tgname like 'audit_%')
  union all
  select 'core RPCs present (7)',
         (select count(distinct proname) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public'
             and proname in ('record_payment','void_payment','dashboard_summary','stock_adjust',
                             'create_organization','check_app_version','admin_list_members')) = 7,
         null
)
select name, case when ok then 'PASS' else 'FAIL' end as result, detail
from c order by ok, name;

rollback;

