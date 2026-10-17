-- ============================================================================
-- PART 2 — install the fam_test helpers   (THIS PART COMMITS — run once)
-- ============================================================================
create schema if not exists fam_test;

-- set the JWT claims used by auth.uid() / auth.jwt() for the current transaction
create or replace function fam_test.set_jwt(
  p_uid uuid, p_aal text default 'aal1', p_role text default 'authenticated')
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_uid::text, 'role', p_role, 'aal', p_aal)::text, true);
end $$;

-- true when p_sql raises (optionally a specific SQLSTATE). Runs as the CALLER,
-- so RLS and column privileges apply.
create or replace function fam_test.raises(p_sql text, p_state text default null)
returns boolean language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    return p_state is null or sqlstate = p_state;
  end;
  return false;
end $$;

-- the SQLSTATE: message text of whatever p_sql raises, or NULL if it succeeds.
create or replace function fam_test.raise_error(p_sql text)
returns text language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    return sqlstate || ': ' || sqlerrm;
  end;
  return null;
end $$;

-- row count of a SELECT, executed as the CALLER (so RLS applies).
create or replace function fam_test.num(p_sql text)
returns bigint language plpgsql as $$
declare v bigint;
begin
  execute 'select count(*) from (' || p_sql || ') q' into v;
  return v;
end $$;

grant usage on schema fam_test to authenticated;
grant execute on function fam_test.raises(text, text)      to authenticated;
grant execute on function fam_test.raise_error(text)        to authenticated;
grant execute on function fam_test.num(text)                to authenticated;
grant execute on function fam_test.set_jwt(uuid, text, text) to authenticated;

select 'fam_test helpers installed' as check, count(*) as functions
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'fam_test';

