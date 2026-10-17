-- ============================================================================
-- PART 6 — organization, member and invitation RPCs
-- ============================================================================
begin;

-- ---- fixtures ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a001','authenticated',
  'authenticated','owner.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Owner A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a002','authenticated',
  'authenticated','mgr.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Manager A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000a003','authenticated',
  'authenticated','staff.a@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Staff A"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000c001','authenticated',
  'authenticated','newcomer@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Newcomer"}', now(), now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-00000000d001','authenticated',
  'authenticated','invitee@fam.test', crypt('Password123', gen_salt('bf')), now(), '{}','{"full_name":"Invitee"}', now(), now())
on conflict (id) do nothing;

insert into organizations (id, name, slug, created_by)
values ('00000000-0000-0000-0000-0000000000aa','Org A','org-a-adm','00000000-0000-0000-0000-00000000a001')
on conflict (id) do nothing;

insert into organization_members (org_id, user_id, role, status) values
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a001','owner','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a002','manager','active'),
  ('00000000-0000-0000-0000-0000000000aa','00000000-0000-0000-0000-00000000a003','staff','active')
on conflict (org_id, user_id) do nothing;

insert into properties (id, org_id, name, type)
values ('00000000-0000-0000-0000-00000000aaa1','00000000-0000-0000-0000-0000000000aa','Prop A','residential')
on conflict (id) do nothing;

insert into invitations (id, org_id, email, role, token_hash, expires_at)
values ('00000000-0000-0000-0000-00000000ab01','00000000-0000-0000-0000-0000000000aa','invitee@fam.test',
        'staff','hash_exp', now() - interval '1 day'),
       ('00000000-0000-0000-0000-00000000ab02','00000000-0000-0000-0000-0000000000aa','someoneelse@fam.test',
        'staff','hash_wrong', now() + interval '1 day')
on conflict (id) do nothing;

-- ================= newcomer creates an organization =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000c001','aal1');
set local role authenticated;
do $$ begin perform public.create_organization('Kefeta Rentals'); end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'create_organization creates org + owner membership' as name,
         fam_test.num($sql$ select 1 from organizations o
                             join organization_members m on m.org_id = o.id
                            where o.created_by = '00000000-0000-0000-0000-00000000c001'
                              and m.user_id = '00000000-0000-0000-0000-00000000c001'
                              and m.role = 'owner' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'slug is derived from the name',
         fam_test.num($sql$ select 1 from organizations
                             where created_by = '00000000-0000-0000-0000-00000000c001'
                               and slug = 'kefeta-rentals' $sql$) = 1, null
  union all
  select 'empty name is rejected',
         fam_test.raises($sql$ select public.create_organization('   ') $sql$, '22023'), null
  union all
  select 'duplicate slug is rejected',
         fam_test.raises($sql$ select public.create_organization('Other','kefeta-rentals') $sql$, '23505'), null
) c order by ok, name;

-- ================= owner A: invitations =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.invite_member('00000000-0000-0000-0000-0000000000aa','invitee@fam.test',null,
                               'staff'::public.org_role,'hash_acc');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner can invite a member' as name,
         fam_test.num($sql$ select 1 from invitations
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and token_hash = 'hash_acc' and email = 'invitee@fam.test' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'invitation records the inviter',
         fam_test.num($sql$ select 1 from invitations where token_hash = 'hash_acc'
                             and invited_by = '00000000-0000-0000-0000-00000000a001' $sql$) = 1, null
  union all
  select 'missing email and phone is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa',null,null,
                                 'staff'::public.org_role,'hash_no_contact') $sql$, '22023'), null
  union all
  select 'empty token hash is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','x@fam.test',null,
                                 'staff'::public.org_role,'') $sql$, '22023'), null
  union all
  select 'duplicate token hash is rejected',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','y@fam.test',null,
                                 'staff'::public.org_role,'hash_acc') $sql$, '23505'), null
  union all
  select 'admin_list_members returns the roster with emails',
         fam_test.num($sql$ select * from public.admin_list_members('00000000-0000-0000-0000-0000000000aa') $sql$) >= 3
     and fam_test.num($sql$ select 1 from public.admin_list_members('00000000-0000-0000-0000-0000000000aa')
                            where user_id = '00000000-0000-0000-0000-00000000a001' and email is not null $sql$) = 1, null
) c order by ok, name;

-- ================= staff A: denied =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'staff cannot list members' as name,
         fam_test.raises($sql$ select * from public.admin_list_members('00000000-0000-0000-0000-0000000000aa') $sql$,
                         '42501') as ok, null::text as detail
  union all
  select 'staff cannot invite',
         fam_test.raises($sql$ select public.invite_member('00000000-0000-0000-0000-0000000000aa','z@fam.test',null,
                                 'staff'::public.org_role,'hash_staff') $sql$, '42501'), null
  union all
  select 'staff cannot change a role',
         fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '42501'), null
) c order by ok, name;

-- ================= owner A: role and status management =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                       '00000000-0000-0000-0000-00000000a003','manager'::public.org_role);
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'owner promoted staff to manager' as name,
         fam_test.num($sql$ select 1 from organization_members
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and user_id = '00000000-0000-0000-0000-00000000a003'
                               and role = 'manager' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'cannot demote the last owner',
         fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '23505'), null
  union all
  select 'invalid member status is rejected',
         fam_test.raises($sql$ select public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                 '00000000-0000-0000-0000-00000000a003','zzz') $sql$, '22023'), null
) c order by ok, name;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'manager cannot change a role' as name,
       fam_test.raises($sql$ select public.admin_set_member_role('00000000-0000-0000-0000-0000000000aa',
                               '00000000-0000-0000-0000-00000000a001','staff'::public.org_role) $sql$, '42501') as ok,
       null::text as detail;

-- owner suspends the member, member loses access, owner reactivates
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                         '00000000-0000-0000-0000-00000000a003','suspended');
end $$;
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a003','aal1');
set local role authenticated;
select 'a suspended member loses access' as name,
       fam_test.num($sql$ select 1 from properties
                           where org_id = '00000000-0000-0000-0000-0000000000aa' $sql$) = 0 as ok,
       null::text as detail;

reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000a001','aal1');
set local role authenticated;
do $$ begin
  perform public.admin_set_member_status('00000000-0000-0000-0000-0000000000aa',
                                         '00000000-0000-0000-0000-00000000a003','active');
end $$;
select 'owner reactivated the member' as name,
       fam_test.num($sql$ select 1 from organization_members
                           where org_id = '00000000-0000-0000-0000-0000000000aa'
                             and user_id = '00000000-0000-0000-0000-00000000a003'
                             and status = 'active' $sql$) = 1 as ok,
       null::text as detail;

-- ================= invitation acceptance (as the invitee) =================
reset role;
select fam_test.set_jwt('00000000-0000-0000-0000-00000000d001','aal1');
set local role authenticated;
select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'unknown token is rejected' as name,
         fam_test.raises($sql$ select public.accept_invitation('does-not-exist') $sql$, 'P0002') as ok,
         null::text as detail
  union all
  select 'expired invitation is rejected',
         fam_test.raises($sql$ select public.accept_invitation('hash_exp') $sql$, '22023'), null
  union all
  select 'email mismatch is rejected',
         fam_test.raises($sql$ select public.accept_invitation('hash_wrong') $sql$, '42501'), null
) c order by ok, name;

do $$ begin
  perform public.accept_invitation('hash_acc');
end $$;

select name, case when ok then 'PASS' else 'FAIL' end as result, detail from (
  select 'accepting the invitation creates the membership' as name,
         fam_test.num($sql$ select 1 from organization_members
                             where org_id = '00000000-0000-0000-0000-0000000000aa'
                               and user_id = '00000000-0000-0000-0000-00000000d001'
                               and role = 'staff' and status = 'active' $sql$) = 1 as ok,
         null::text as detail
  union all
  select 'invitation is marked accepted',
         fam_test.num($sql$ select 1 from invitations where token_hash = 'hash_acc' and accepted_at is not null $sql$) = 1, null
  union all
  select 'accepted token cannot be reused',
         fam_test.raises($sql$ select public.accept_invitation('hash_acc') $sql$, 'P0002'), null
) c order by ok, name;

reset role;
rollback;

