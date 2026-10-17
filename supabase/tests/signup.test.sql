-- supabase/tests/signup.test.sql
-- Sign-up must always produce a profile, including the phone number that the
-- clients can only send in the sign-up metadata (handing it to GoTrue as
-- `phone` makes it reject the request when phone sign-in is disabled).
-- Run with: supabase test db
begin;
select plan(4);

-- ---- email sign-up with the phone in the metadata ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000f1','authenticated',
          'authenticated','metadata@test.fam','x', now(),
          '{"full_name":"Metadata User","phone":"+251911111111"}'::jsonb);

select is(
  (select full_name from public.profiles where id = '00000000-0000-0000-0000-0000000000f1'),
  'Metadata User',
  'full_name is taken from the sign-up metadata');

select is(
  (select phone from public.profiles where id = '00000000-0000-0000-0000-0000000000f1'),
  '+251911111111',
  'phone falls back to the sign-up metadata');

-- ---- phone sign-in still wins when auth.users.phone is set ----
insert into auth.users (instance_id, id, aud, role, phone, encrypted_password, phone_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000f2','authenticated',
          'authenticated','+251922222222','x', now(), '{"full_name":"Phone User"}'::jsonb);

select is(
  (select phone from public.profiles where id = '00000000-0000-0000-0000-0000000000f2'),
  '+251922222222',
  'a phone sign-in keeps auth.users.phone');

-- ---- no phone anywhere stays null ----
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data)
  values ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000f3','authenticated',
          'authenticated','nophone@test.fam','x', now(), '{"full_name":"No Phone"}'::jsonb);

select is(
  (select phone from public.profiles where id = '00000000-0000-0000-0000-0000000000f3'),
  null,
  'a user without a phone number keeps a null phone');

select * from finish();
rollback;
