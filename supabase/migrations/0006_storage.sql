-- 0006_storage.sql
-- Private storage buckets, path convention {org_id}/{entity_id}/{filename}.
-- Limit size and MIME types. Use signed URLs for display (handled client-side).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('property-images',  'property-images',  false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('tenant-documents', 'tenant-documents', false, 10485760, array['image/jpeg','image/png','application/pdf']),
  ('lease-documents',  'lease-documents',  false, 10485760, array['image/jpeg','image/png','application/pdf']),
  ('receipts',         'receipts',         false, 10485760, array['application/pdf','image/png','image/jpeg']),
  ('avatars',          'avatars',          false, 5242880,  array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- enable RLS on storage.objects is already on by default in Supabase; add policies.

-- ---- property-images ----
create policy "org members read property images" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'property-images'
    and public.is_org_member(((storage.foldername(name))[1])::uuid)
  );
create policy "managers write property images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'property-images'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager']::public.org_role[])
  );
create policy "managers update property images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'property-images'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager']::public.org_role[])
  );
create policy "managers delete property images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'property-images'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager']::public.org_role[])
  );

-- ---- tenant-documents (owner/manager/staff can write) ----
create policy "org members read tenant docs" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'tenant-documents'
    and public.is_org_member(((storage.foldername(name))[1])::uuid)
  );
create policy "staff write tenant docs" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'tenant-documents'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager','staff']::public.org_role[])
  );
create policy "staff delete tenant docs" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'tenant-documents'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager','staff']::public.org_role[])
  );

-- ---- lease-documents ----
create policy "org members read lease docs" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'lease-documents'
    and public.is_org_member(((storage.foldername(name))[1])::uuid)
  );
create policy "managers write lease docs" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'lease-documents'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager']::public.org_role[])
  );

-- ---- receipts (read for org members; written by generate-receipt under the
--      caller's JWT, so the {org_id} path segment is checked against their role) ----
create policy "org members read receipts" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'receipts'
    and public.is_org_member(((storage.foldername(name))[1])::uuid)
  );
create policy "managers write receipts" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'receipts'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager','staff']::public.org_role[])
  );
create policy "managers update receipts" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'receipts'
    and public.has_org_role(((storage.foldername(name))[1])::uuid, array['owner','manager','staff']::public.org_role[])
  );

-- ---- avatars ----
create policy "read avatars" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars');
create policy "own write avatars" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars');
create policy "own update avatars" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars');
