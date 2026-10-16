-- 0007_realtime.sql
-- Add tables to the realtime publication. RLS still applies to subscribers;
-- clients subscribe with an org_id=eq.<id> filter.

alter publication supabase_realtime add table public.rent_charges;
alter publication supabase_realtime add table public.payments;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.stock_items;
