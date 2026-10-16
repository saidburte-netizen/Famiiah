-- 0008_cron.sql
-- Scheduled jobs (pg_cron runs in UTC; Addis Ababa is UTC+3).
-- Secrets are read from Supabase Vault — never hard-code them in SQL.

-- helper: prune old app_event_logs (retention, default 90 days)
create or replace function public.prune_app_event_logs(p_days int default 90) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.app_event_logs
  where created_at < now() - make_interval(days => greatest(p_days, 1));
end;
$$;

-- helper: invoke an edge function via pg_net, reading the service key from Vault.
-- The Vault secrets `service_role_key` and `project_url` must be set once:
--   select vault.create_secret('<service-role-key>', 'service_role_key');
--   select vault.create_secret('https://<ref>.supabase.co', 'project_url');
create or replace function public.invoke_edge_function(p_function text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_key text;
  v_url text;
begin
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'service_role_key';
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'project_url';
  if v_key is null or v_url is null then
    raise warning 'invoke_edge_function: vault secrets not set, skipping %', p_function;
    return;
  end if;
  perform net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/' || p_function,
    headers := jsonb_build_object('Authorization', 'Bearer ' || v_key, 'Content-Type', 'application/json'),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000
  );
end;
$$;

-- Schedule jobs (UTC).
select cron.schedule('fam-generate-charges', '0 1 * * *',  $$select public.generate_monthly_charges(null)$$);
select cron.schedule('fam-mark-overdue',     '10 1 * * *', $$select public.mark_overdue_charges()$$);
select cron.schedule('fam-send-reminders',   '0 5 * * *',  $$select public.invoke_edge_function('send-reminders')$$);
select cron.schedule('fam-prune-logs',       '30 2 * * 0', $$select public.prune_app_event_logs(90)$$);
