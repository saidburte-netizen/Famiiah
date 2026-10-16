-- 0002_core_tables.sql
-- Core schema: profiles, orgs, members, invitations, properties, units,
-- tenants, leases, rent_charges, counters, payments, allocations.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  avatar_url text,
  locale text not null default 'en',
  is_platform_admin boolean not null default false,   -- only changeable by service role / migration
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  currency char(3) not null default 'ETB',
  timezone text not null default 'Africa/Addis_Ababa',
  default_billing_day int not null default 1 check (default_billing_day between 1 and 28),
  default_grace_days int not null default 5 check (default_grace_days between 0 and 60),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index on public.organizations (created_by);

create table public.organization_members (
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.org_role not null default 'staff',
  status text not null default 'active' check (status in ('pending','active','suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (org_id, user_id)
);
create index on public.organization_members (user_id);

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  email text, phone text,
  role public.org_role not null default 'staff',
  token_hash text not null unique,        -- store a hash, never the raw token
  invited_by uuid references auth.users(id),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  check (email is not null or phone is not null)
);
create index on public.invitations (org_id);

create table public.properties (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  type public.property_type not null,
  address_line text, sub_city text, city text,
  latitude double precision, longitude double precision,
  floors int check (floors is null or floors > 0),
  cover_image_path text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index on public.properties (org_id) where deleted_at is null;
create index properties_name_trgm on public.properties using gin (name gin_trgm_ops);

create table public.units (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid not null references public.properties(id) on delete cascade,
  code text not null,                                  -- e.g. B-04
  kind text not null default 'shop' check (kind in ('shop','apartment','office','storage')),
  floor_label text,
  area_sqm numeric(10,2) check (area_sqm is null or area_sqm > 0),
  monthly_rent numeric(14,2) not null default 0 check (monthly_rent >= 0),
  status public.unit_status not null default 'vacant',
  has_separate_meter boolean not null default false,
  has_storage boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (property_id, code)
);
create index on public.units (org_id, status) where deleted_at is null;
create index on public.units (property_id);

create table public.tenants (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,   -- set when the tenant joins the app
  full_name text not null,
  business_name text,
  phone text, email text,
  id_document_path text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index on public.tenants (org_id) where deleted_at is null;
create index on public.tenants (user_id);
create index tenants_name_trgm on public.tenants using gin (full_name gin_trgm_ops);

create table public.leases (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete restrict,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  start_date date not null,
  end_date date,
  monthly_rent numeric(14,2) not null check (monthly_rent >= 0),
  deposit_amount numeric(14,2) not null default 0 check (deposit_amount >= 0),
  billing_day int not null default 1 check (billing_day between 1 and 28),
  grace_days int not null default 5 check (grace_days >= 0),
  status public.lease_status not null default 'active',
  lease_document_path text,
  ended_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);
-- at most one ACTIVE lease per unit
create unique index one_active_lease_per_unit on public.leases (unit_id) where status = 'active';
create index on public.leases (org_id, status);
create index on public.leases (tenant_id);

create table public.org_counters (
  org_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  value bigint not null default 0,
  primary key (org_id, name)
);

create table public.rent_charges (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  lease_id uuid not null references public.leases(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  due_date date not null,
  amount numeric(14,2) not null check (amount >= 0),
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  status public.charge_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lease_id, period_start)
);
create index on public.rent_charges (org_id, due_date, status);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  lease_id uuid references public.leases(id) on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  unallocated_amount numeric(14,2) not null default 0,   -- credit left after allocation
  method public.payment_method not null,
  reference text,
  paid_at timestamptz not null default now(),
  receipt_no text,
  notes text,
  idempotency_key text,
  received_by uuid references auth.users(id),
  voided_at timestamptz, voided_by uuid references auth.users(id), void_reason text,
  created_at timestamptz not null default now(),
  unique (org_id, receipt_no),
  unique (org_id, idempotency_key)
);
create index on public.payments (org_id, paid_at desc);
create index on public.payments (tenant_id);

create table public.payment_allocations (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments(id) on delete cascade,
  charge_id  uuid not null references public.rent_charges(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0)
);
create index on public.payment_allocations (payment_id);
create index on public.payment_allocations (charge_id);
