-- 0001_extensions_enums_helpers.sql
-- Extensions, enum types, and shared helper functions for Fam.

create extension if not exists pg_cron;
create extension if not exists pg_net;
create extension if not exists pg_trgm;

-- Enums (fixed sets)
create type public.org_role             as enum ('owner','manager','staff','viewer');
create type public.property_type        as enum ('residential','commercial','mixed_use');
create type public.unit_status          as enum ('vacant','rented','maintenance');
create type public.lease_status         as enum ('draft','active','ended','terminated');
create type public.charge_status        as enum ('pending','partial','paid','overdue','void');
create type public.payment_method       as enum ('cash','bank_transfer','telebirr','chapa','cheque','other');
create type public.stock_movement_type  as enum ('in','out','adjustment','rental_out','rental_return');
create type public.notification_channel as enum ('push','sms','email','in_app');

-- updated_at trigger helper
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Atomic counter used for receipt numbers.
create or replace function public.next_number(p_org uuid, p_name text) returns bigint
language plpgsql as $$
declare v bigint;
begin
  insert into public.org_counters(org_id, name, value)
  values (p_org, p_name, 1)
  on conflict (org_id, name)
  do update set value = public.org_counters.value + 1
  returning value into v;
  return v;
end;
$$;
