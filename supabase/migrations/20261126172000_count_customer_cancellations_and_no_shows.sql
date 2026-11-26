alter table public.appointments
  add column if not exists cancelled_by uuid references auth.users(id) on delete set null;

create or replace function private.cancel_appointment(p_appointment_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız';
  end if;

  update public.appointments a
  set status = 'cancelled',
      cancelled_by = case when a.customer_id = auth.uid() then auth.uid() else null end
  where a.id = p_appointment_id
    and a.status in ('pending', 'confirmed')
    and (
      a.customer_id = auth.uid()
      or exists (
        select 1 from public.employees e
        where e.id = a.employee_id and e.user_id = auth.uid()
      )
      or exists (
        select 1 from public.businesses b
        where b.id = a.business_id and b.owner_id = auth.uid()
      )
    );

  if not found then
    raise exception 'Randevu bulunamadı veya iptal yetkiniz yok';
  end if;
end;
$function$;

create or replace function private.auto_restrict_three_no_shows()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_infraction_count integer;
  v_last_completed timestamptz;
  v_owner uuid;
  v_employee uuid;
  v_was_restricted boolean;
begin
  if new.status in ('cancelled', 'no_show')
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    select max(a.starts_at) into v_last_completed
    from public.appointments a
    where a.business_id = new.business_id
      and a.customer_id = new.customer_id
      and a.status = 'completed';

    select count(*)::integer into v_infraction_count
    from public.appointments a
    where a.business_id = new.business_id
      and a.customer_id = new.customer_id
      and a.starts_at > coalesce(v_last_completed, '-infinity'::timestamptz)
      and (
        a.status = 'no_show'
        or (a.status = 'cancelled' and a.cancelled_by = a.customer_id)
      );

    if v_infraction_count >= 3 then
      select b.owner_id into v_owner
      from public.businesses b where b.id = new.business_id;
      select e.user_id into v_employee
      from public.employees e where e.id = new.employee_id;

      select exists (
        select 1 from public.business_customer_restrictions r
        where r.business_id = new.business_id
          and r.customer_id = new.customer_id
          and r.is_active
      ) into v_was_restricted;

      insert into public.business_customer_restrictions(
        business_id, customer_id, is_active, reason, created_by
      )
      values (
        new.business_id, new.customer_id, true,
        'Üç iptal veya gelmeme ihlali', v_owner
      )
      on conflict (business_id, customer_id)
      do update set
        is_active = true,
        reason = 'Üç iptal veya gelmeme ihlali',
        created_at = now(),
        removed_by = null,
        removed_at = null;

      if not v_was_restricted then
        insert into public.notifications(user_id, appointment_id, title, body)
        values (
          new.customer_id, new.id, 'İşletme tarafından kara listeye alındın',
          'Bu işletmedeki üç randevu iptali veya gelmeme nedeniyle yeni randevu için işletme onayı gerekecek.'
        );
        if v_owner is not null then
          insert into public.notifications(user_id, appointment_id, title, body)
          values (
            v_owner, new.id, 'Müşteri kara listeye alındı',
            'Bir müşteri üç randevu iptali veya gelmeme nedeniyle otomatik olarak kara listeye alındı.'
          );
        end if;
        if v_employee is not null and v_employee <> v_owner then
          insert into public.notifications(user_id, appointment_id, title, body)
          values (
            v_employee, new.id, 'Müşteri kara listeye alındı',
            'Bir müşteri üç randevu iptali veya gelmeme nedeniyle işletme kara listesine alındı.'
          );
        end if;
      end if;
    end if;
  end if;
  return new;
end;
$function$;

grant execute on function private.cancel_appointment(uuid) to authenticated;
