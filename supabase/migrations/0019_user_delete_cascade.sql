-- 0019_user_delete_cascade.sql
-- Deleting an account from the Supabase dashboard failed with
-- "Database error deleting user" for any user who had done real work.
--
-- The cause is a handful of *audit* columns that point at auth.users(id) with
-- the default NO ACTION: organizations.created_by, invitations.invited_by,
-- payments.received_by, payments.voided_by and stock_movements.performed_by.
-- auth.users -> public.profiles already cascades, but Postgres then hits one of
-- these and refuses the delete, because removing the referenced auth row would
-- orphan the audit trail rather than cascade it away.
--
-- The intent of these columns is "who did it", not ownership: the record itself
-- (the organization, the payment, the stock movement) must survive the actor's
-- account being removed. `on delete set null` is exactly that, and it is the
-- same treatment tenants.user_id already gets in 0002. Accounts a user *owns*
-- genuinely (profiles, organization_members, notifications) keep their cascade.
--
-- Every constraint is located by its catalog entry rather than by a guessed
-- name, so the migration works no matter what Postgres called them and is safe
-- to re-run.

do $$
declare
  -- (table, column) pairs whose FK to auth.users must become ON DELETE SET NULL
  targets text[][] := array[
    array['organizations', 'created_by'],
    array['invitations', 'invited_by'],
    array['payments', 'received_by'],
    array['payments', 'voided_by'],
    array['stock_movements', 'performed_by']
  ];
  t text[];
  v_table text;
  v_column text;
  v_constraint text;
begin
  foreach t slice 1 in array targets loop
    v_table := t[1];
    v_column := t[2];

    -- Find the foreign-key constraint on (v_table, v_column) that references
    -- auth.users, whatever it happens to be called.
    select c.conname
      into v_constraint
      from pg_constraint c
      join pg_class rel on rel.oid = c.conrelid
      join pg_namespace nsp on nsp.oid = rel.relnamespace
      join pg_attribute att
        on att.attrelid = c.conrelid
       and att.attnum = any (c.conkey)
      join pg_class frel on frel.oid = c.confrelid
      join pg_namespace fnsp on fnsp.oid = frel.relnamespace
     where c.contype = 'f'
       and nsp.nspname = 'public'
       and rel.relname = v_table
       and fnsp.nspname = 'auth'
       and frel.relname = 'users'
       and att.attname = v_column
     limit 1;

    if v_constraint is not null then
      execute format(
        'alter table public.%I drop constraint %I',
        v_table, v_constraint
      );

      execute format(
        'alter table public.%I add constraint %I '
        'foreign key (%I) references auth.users(id) on delete set null',
        v_table, v_constraint, v_column
      );

      raise notice '  % . % : % -> on delete set null',
        v_table, v_column, v_constraint;
    else
      raise notice '  % . % : no auth.users FK found (already fixed?)',
        v_table, v_column;
    end if;
  end loop;
end;
$$;
