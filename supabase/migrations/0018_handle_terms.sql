-- 0018_handle_terms.sql
-- Sign-up now collects a unique @handle (with the phone number and password)
-- and a terms toggle that has to be ticked before the account is created.
--
-- The handle is the account's public name and must be unique across the whole
-- project, so the database owns the rule: `handle_available()` lets the
-- unauthenticated sign-up form ask whether a handle is free, and the unique
-- index is what actually guarantees it. Handles are stored lowercase without
-- the leading '@', matching `Handle` in packages/shared/src/schemas.ts.
--
-- `accept_terms_at` is the audit trail for the toggle: the clients stamp it
-- into the sign-up metadata and the trigger records it on the profile.

alter table public.profiles
  add column if not exists handle text,
  add column if not exists accept_terms_at timestamptz;

-- Format: 3-24 chars, starting with a letter, then letters/digits/underscores.
-- Legacy accounts keep `handle = null` (the index below treats NULLs as
-- distinct), so nothing existing is touched by adding the constraint.
alter table public.profiles
  drop constraint if exists profiles_handle_format;
alter table public.profiles
  add constraint profiles_handle_format
  check (handle is null or handle ~ '^[a-z][a-z0-9_]{2,23}$');

create unique index if not exists profiles_handle_key on public.profiles (handle);

-- Normalises exactly the way handle_new_user() does, so the answer the form
-- gets is the answer the insert will get. Anon may call it: sign-up is
-- unauthenticated and handles are public by nature.
create or replace function public.handle_available(p_handle text)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.profiles
     where handle = nullif(lower(regexp_replace(btrim(coalesce(p_handle, '')), '^@+', '', 'g')), '')
  );
$$;

revoke all on function public.handle_available(text) from public, anon, authenticated;
grant execute on function public.handle_available(text) to anon, authenticated;

-- Profiles are created from the sign-up metadata: 0017 taught the function to
-- read a phone number from there, this version adds the handle, falls back to
-- '@handle' for the display name and stamps the terms acceptance.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_handle text;
begin
  v_handle := nullif(lower(regexp_replace(btrim(coalesce(new.raw_user_meta_data->>'handle', '')), '^@+', '', 'g')), '');

  insert into public.profiles (id, full_name, phone, handle, accept_terms_at)
  values (
    new.id,
    case
      -- an explicit name always wins (older email sign-ups send full_name)
      when nullif(new.raw_user_meta_data->>'full_name', '') is not null
        then new.raw_user_meta_data->>'full_name'
      -- otherwise show the handle so members are never nameless
      when v_handle is not null then '@' || v_handle
      else ''
    end,
    -- auth.users.phone is only populated for phone sign-ins; the metadata
    -- carries the number typed into the old email sign-up form instead
    coalesce(nullif(new.phone, ''), nullif(new.raw_user_meta_data->>'phone', '')),
    v_handle,
    -- defensive: a malformed timestamp must never break account creation
    case when new.raw_user_meta_data->>'accept_terms_at' ~ '^\d{4}-\d{2}-\d{2}'
         then (new.raw_user_meta_data->>'accept_terms_at')::timestamptz
    end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
