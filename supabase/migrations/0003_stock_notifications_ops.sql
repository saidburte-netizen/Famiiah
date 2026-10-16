-- 0003_stock_notifications_ops.sql
-- Stock, notifications, device tokens, logs, versioning, feature flags.

create table public.stock_items (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  property_id uuid references public.properties(id) on delete set null,
  sku text, name text not null, category text,
  uom text not null default 'pcs',
  quantity numeric(14,3) not null default 0 check (quantity >= 0),
  min_quantity numeric(14,3) not null default 0,
  is_rentable boolean not null default false,
  rental_rate numeric(14,2),                 -- per day, applies when is_rentable
  barcode text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (org_id, sku)
);
create index on public.stock_items (org_id) where deleted_at is null;

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid not null references public.stock_items(id) on delete cascade,
  type public.stock_movement_type not null,
  quantity numeric(14,3) not null check (quantity > 0),
  balance_after numeric(14,3) not null,
  reason text,
  unit_id uuid references public.units(id) on delete set null,
  performed_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index on public.stock_movements (item_id, created_at desc);
create index on public.stock_movements (org_id, created_at desc);

create table public.stock_rentals (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  item_id uuid not null references public.stock_items(id) on delete restrict,
  tenant_id uuid not null references public.tenants(id) on delete restrict,
  quantity numeric(14,3) not null check (quantity > 0),
  daily_rate numeric(14,2) not null default 0,
  start_date date not null default current_date,
  due_date date not null,
  returned_at timestamptz,
  status text not null default 'out' check (status in ('out','returned','overdue','lost')),
  created_at timestamptz not null default now()
);
create index on public.stock_rentals (item_id);
create index on public.stock_rentals (tenant_id);
create index on public.stock_rentals (org_id, status);

create table public.maintenance_requests (       -- optional module, behind feature flag
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  unit_id uuid not null references public.units(id) on delete cascade,
  tenant_id uuid references public.tenants(id) on delete set null,
  title text not null, description text,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','done','cancelled')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index on public.maintenance_requests (org_id, status);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,     -- recipient (staff or tenant with an account)
  tenant_id uuid references public.tenants(id) on delete cascade,
  channel public.notification_channel not null default 'in_app',
  title text not null, body text,
  data jsonb not null default '{}',
  status text not null default 'queued' check (status in ('queued','sent','failed','read')),
  scheduled_at timestamptz not null default now(),
  sent_at timestamptz, read_at timestamptz,
  created_at timestamptz not null default now()
);
create index on public.notifications (user_id, status, created_at desc);
create index on public.notifications (status, scheduled_at);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios','android','web')),
  created_at timestamptz not null default now()
);
create index on public.device_tokens (user_id);

-- LOGS
create table public.audit_logs (
  id bigint generated always as identity primary key,
  org_id uuid,
  actor_id uuid,
  action text not null,                  -- INSERT | UPDATE | DELETE | custom (e.g. 'payment.void')
  table_name text,
  record_id uuid,
  old_data jsonb, new_data jsonb,
  ip inet, user_agent text,
  created_at timestamptz not null default now()
);
create index on public.audit_logs (org_id, created_at desc);
create index on public.audit_logs (table_name, record_id);

create table public.app_event_logs (
  id bigint generated always as identity primary key,
  level text not null check (level in ('debug','info','warn','error','fatal')),
  source text not null check (source in ('mobile','admin','edge','db')),
  message text not null,
  context jsonb not null default '{}',
  user_id uuid, org_id uuid,
  app_version text, platform text, request_id text,
  created_at timestamptz not null default now()
);
create index on public.app_event_logs (created_at desc);
create index on public.app_event_logs (level, created_at desc);

-- VERSIONING AND FLAGS
create table public.app_versions (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('ios','android','web')),
  version text not null check (version ~ '^\d+\.\d+\.\d+$'),
  min_supported_version text not null check (min_supported_version ~ '^\d+\.\d+\.\d+$'),
  force_update boolean not null default false,
  store_url text,
  release_notes text,
  released_at timestamptz not null default now(),
  is_active boolean not null default true,
  unique (platform, version)
);
create index on public.app_versions (platform, is_active);

create table public.feature_flags (
  key text not null,
  org_id uuid references public.organizations(id) on delete cascade,   -- null = global
  enabled boolean not null default false,
  description text,
  updated_at timestamptz not null default now(),
  unique nulls not distinct (key, org_id)
);

insert into public.feature_flags(key, enabled, description) values
 ('online_payments', false, 'Chapa/Telebirr online payments'),
 ('maintenance_requests', false, 'Maintenance module'),
 ('tenant_portal', true, 'Tenant self-service view');
