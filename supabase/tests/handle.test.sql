-- supabase/tests/handle.test.sql
-- Sign-up carries a unique @handle and the terms acceptance into the profile,
-- and the database — not the client — is what enforces both.
-- Run with: supabase test db
begin;
select plan(9);

-- ---- a handle sign-up lands on the profile, normalised ----
insert into auth.users (instance_id, id, aud, role, phone, encrypted_password, phone_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000h1','authenticated',
          'authenticated','+251933333333','x', now(),
          '{"handle":"@Abebe","accept_terms_at":"2026-10-18T10:00:00.000Z"}'::jsonb);

select is(
  (select handle from public.profiles where id = '00000000-0000-0000-0000-0000000000h1'),
  'abebe',
  'the handle is stored lowercase without the @');

select is(
  (select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000h1'),
  '@abebe',
  'the display name falls back to the handle');

select is(
  (select accept_terms_at from public.profiles where id = '00000000-0000-0000-0000-0000000000h1'),
  '2026-10-18T10:00:00Z'::timestamptz,
  'the terms acceptance time is recorded');

-- ---- availability is asked the same way it is stored ----
select is(handle_available('@ABEBE'), false, 'a taken handle is reported as unavailable');
select ok(handle_available('free_handle'), true, 'a free handle is reported as available');

-- ---- the database enforces uniqueness and format ----
select throws_ok(
  $$ insert into auth.users (instance_id, id, aud, role, phone, encrypted_password, phone_confirmed_at, raw_user_meta_data)
     values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000h2','authenticated',
             'authenticated','+251933333334','x', now(), '{"handle":"abebe"}'::jsonb) $$,
  '23505', null,
  'a second account cannot take an existing handle'
);

select throws_ok(
  $$ insert into auth.users (instance_id, id, aud, role, phone, encrypted_password, phone_confirmed_at, raw_user_meta_data)
     values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000h3','authenticated',
             'authenticated','+251933333335','x', now(), '{"handle":"12ab"}'::jsonb) $$,
  '23514', null,
  'a handle must match the format'
);

-- ---- a sign-up that carries no handle keeps working ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000h4','authenticated',
          'authenticated','nohandle@test.fam','x', now(), '{"full_name":"No Handle"}'::jsonb);

select ok(
  (select handle is null from public.profiles where id = '00000000-0000-0000-0000-0000000000h4'),
  'a sign-up without a handle leaves it null');

select ok(
  (select accept_terms_at is null from public.profiles where id = '00000000-0000-0000-0000-0000000000h4'),
  'no terms timestamp is recorded when none was accepted');

select * from finish();
rollback;
