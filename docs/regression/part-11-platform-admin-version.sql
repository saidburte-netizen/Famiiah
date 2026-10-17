-- ============================================================================
-- PART 11 — platform-admin RPCs and the version gate
-- ============================================================================
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000c001','authenticated',
  'authenticated','platform@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Platform"}', now(), now())
on conflict (id) do nothing;
update profiles set is_platform_admin = true where id = '00000000-0000-0000-0000-00000000c001';

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-plat','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;
insert into organization_members (org_id, user_id, role, status)
values ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active')
on conflict (org_id, user_id) do nothing;

-- version rows for the public gate (explicit released_at => deterministic ordering)
insert into app_versions (id, platform, version, min_supported_version, force_update, released_at)
values ('00000000-0000-0000-0000-0000000a0001','android','2.0.0','1.2.0',true,  now() - interval '1 day'),
       ('00000000-0000-0000-0000-0000000a0002','web','1.10.0','1.0.0',false, now() - interval '2 day')
on conflict (id) do nothing;

-- the gate is anon-callable
reset role;
set local role anon;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'gate: up-to-date client is ok' as name,
         (public.check_app_version('android','2.0.0') ->> 'status') = 'ok' as ok,
         (public.check_app_version('android','2.0.0') ->> 'status') as detail
  union all
  select 'gate: below latest with force_update => force_update',
         (public.check_app_version('android','1.9.0') ->> 'status') = 'force_update', null
  union all
  select 'gate: below min_supported => force_update',
         (public.check_app_version('android','1.1.0') ->> 'status') = 'force_update', null
  union all
  select 'gate: unknown platform => ok',
         (public.check_app_version('ios','0.0.1') ->> 'status') = 'ok', null
  union all
  select 'gate: int-array compare treats 1.10.0 > 1.9.0',
         (public.check_app_version('web','1.9.0') ->> 'status') = 'update_available', null
  union all
  select 'gate: latest web build is ok',
         (public.check_app_version('web','1.10.0') ->> 'status') = 'ok', null
) c order by ok, name;
reset role;

-- platform admin requires MFA (aal2)
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal1');
set local role authenticated;
select 'platform admin without MFA is refused' as name,
       fam_test.raises($sql$ select public.admin_publish_app_version('android','9.9.9','9.0.0') $sql$, '42501') as ok,
       null::text as detail;

-- normal user is refused
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal2');
set local role authenticated;
select 'non-admin is refused for platform RPCs' as name,
       fam_test.raises($sql$ select public.admin_publish_app_version('android','9.9.9','9.0.0') $sql$, '42501')
   and fam_test.raises($sql$ select public.admin_set_feature_flag('maintenance_requests', null, true) $sql$, '42501')
   and fam_test.raises($sql$ select * from public.admin_list_event_logs() $sql$, '42501') as ok,
       null::text as detail;

-- platform admin with MFA succeeds
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
do $$ begin
  perform public.admin_publish_app_version('android','9.9.9','9.0.0', false, 'https://example.test/app', 'notes');
end $$;
do $$ begin
  perform public.admin_set_feature_flag('maintenance_requests','00000000-0000-0000-0000-0000000000aa', true);
end $$;
do $$ begin
  perform public.admin_set_feature_flag('tenant_portal', null, false);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'admin_publish_app_version inserts the version' as name,
         fam_test.num($sql$ select 1 from app_versions where platform = 'android' and version = '9.9.9' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'publishing writes a version.publish audit row',
         fam_test.num($sql$ select 1 from audit_logs where action = 'version.publish' $sql$) >= 1, null
  union all
  select 'admin_set_feature_flag sets an org override',
         fam_test.num($sql$ select 1 from feature_flags where key = 'maintenance_requests'
                             and org_id = '00000000-0000-0000-0000-0000000000aa' and enabled $sql$) = 1, null
  union all
  select 'admin_set_feature_flag toggles a global flag',
         fam_test.num($sql$ select 1 from feature_flags where key = 'tenant_portal'
                             and org_id is null and not enabled $sql$) = 1, null
) c order by ok, name;

-- event log listing (needs a row)
reset role;
insert into app_event_logs (level, source, message) values ('error','edge','boom');
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal2');
set local role authenticated;
select 'admin_list_event_logs filters by level' as name,
       fam_test.num($sql$ select * from public.admin_list_event_logs('error') $sql$) >= 1 as ok,
       null::text as detail;

reset role;
rollback;

