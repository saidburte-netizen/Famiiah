-- 0011_rpcs_payments.sql
-- record_payment (with idempotency + oldest-charges-first allocation) and void_payment.

create or replace function public.record_payment(
  p_lease uuid, p_amount numeric, p_method public.payment_method,
  p_reference text default null, p_paid_at timestamptz default now(),
  p_notes text default null, p_idempotency_key text default null)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  v_lease public.leases; v_pay public.payments; v_ch public.rent_charges;
  v_left numeric := p_amount; v_apply numeric;
begin
  select * into v_lease from leases where id = p_lease for update;
  if not found then raise exception 'lease_not_found' using errcode = 'P0002'; end if;
  -- allow the service role (online-payment webhook) as well as org staff
  if not has_org_role(v_lease.org_id, array['owner','manager','staff']::public.org_role[])
     and coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'invalid_amount' using errcode = '22023';
  end if;

  if p_idempotency_key is not null then
    select * into v_pay from payments
      where org_id = v_lease.org_id and idempotency_key = p_idempotency_key;
    if found then return v_pay; end if;               -- safe retry
  end if;

  insert into payments(org_id, tenant_id, lease_id, amount, method, reference, paid_at,
                       notes, idempotency_key, received_by)
  values (v_lease.org_id, v_lease.tenant_id, p_lease, p_amount, p_method, p_reference, p_paid_at,
          p_notes, p_idempotency_key, (select auth.uid()))
  returning * into v_pay;

  for v_ch in select * from rent_charges
              where lease_id = p_lease and status in ('pending','partial','overdue')
              order by due_date for update loop
    exit when v_left <= 0;
    v_apply := least(v_left, v_ch.amount - v_ch.amount_paid);
    insert into payment_allocations(payment_id, charge_id, amount) values (v_pay.id, v_ch.id, v_apply);
    update rent_charges
       set amount_paid = amount_paid + v_apply,
           status = case when amount_paid + v_apply >= amount then 'paid'::public.charge_status
                         else 'partial'::public.charge_status end
     where id = v_ch.id;
    v_left := v_left - v_apply;
  end loop;

  update payments set unallocated_amount = v_left where id = v_pay.id returning * into v_pay;
  return v_pay;
end;
$$;

revoke all on function public.record_payment(uuid, numeric, public.payment_method, text, timestamptz, text, text) from public, anon;
grant execute on function public.record_payment(uuid, numeric, public.payment_method, text, timestamptz, text, text) to authenticated;

-- ==================== void_payment ====================
-- Reverses allocations, recomputes charge statuses, writes a custom audit row.
create or replace function public.void_payment(p_payment uuid, p_reason text default null)
returns public.payments
language plpgsql security definer set search_path = public as $$
declare
  v_pay public.payments;
  v_alloc record;
begin
  select * into v_pay from payments where id = p_payment for update;
  if not found then raise exception 'payment_not_found' using errcode = 'P0002'; end if;
  if not has_org_role(v_pay.org_id, array['owner','manager']::public.org_role[]) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_pay.voided_at is not null then
    return v_pay;  -- already voided, idempotent
  end if;

  -- reverse allocations and recompute charge status
  for v_alloc in select * from payment_allocations where payment_id = p_payment for update loop
    update rent_charges
       set amount_paid = greatest(amount_paid - v_alloc.amount, 0),
           status = case
             when amount_paid - v_alloc.amount <= 0 then 'pending'::public.charge_status
             when amount_paid - v_alloc.amount < amount then 'partial'::public.charge_status
             else 'paid'::public.charge_status
           end
     where id = v_alloc.charge_id;
  end loop;

  delete from payment_allocations where payment_id = p_payment;

  update payments
     set voided_at = now(), voided_by = (select auth.uid()), void_reason = p_reason, unallocated_amount = 0
   where id = p_payment
   returning * into v_pay;

  -- custom audit row
  insert into audit_logs(org_id, actor_id, action, table_name, record_id, new_data)
  values (v_pay.org_id, (select auth.uid()), 'payment.void', 'payments', p_payment,
          jsonb_build_object('reason', p_reason, 'amount', v_pay.amount));

  return v_pay;
end;
$$;

revoke all on function public.void_payment(uuid, text) from public, anon;
grant execute on function public.void_payment(uuid, text) to authenticated;
