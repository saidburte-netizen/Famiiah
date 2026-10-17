-- 0017_signup_phone_metadata.sql
-- Sign-up collects a phone number, but the clients must not hand it to GoTrue
-- as the `phone` field: GoTrue accepts one identifier per sign-up and rejects
-- email + phone with
--   "Only an email address or phone number should be provided on signup."
-- (and a phone-only sign-up with `phone_provider_disabled`) unless phone
-- sign-in is enabled for the project, which is not the hosted default. The
-- number therefore travels in the sign-up metadata, so profile creation has to
-- accept either source.

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'full_name', ''), ''),
    -- auth.users.phone is only populated for phone sign-ins; the metadata
    -- carries the number typed into the email sign-up form.
    coalesce(nullif(new.phone, ''), nullif(new.raw_user_meta_data->>'phone', ''))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
