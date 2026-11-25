-- Return bookable time slots for a member of an active salon.
create or replace function public.get_available_appointment_slots(
  p_business_id uuid,
  p_employee_id uuid,
  p_service_id uuid,
  p_date date
)
returns table(slot_start timestamptz, slot_end timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_duration integer;
  v_interval integer;
  v_weekday integer;
  v_open time;
  v_close time;
  v_open_local timestamp;
  v_close_local timestamp;
  v_candidate timestamp;
  v_candidate_end timestamp;
  v_start timestamptz;
  v_end timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception 'Giriş yapmalısınız';
  end if;
  if not public.is_current_user_active() then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;
  if p_date < (now() at time zone 'Europe/Istanbul')::date then
    return;
  end if;
  if not exists (
    select 1 from public.business_memberships m
    where m.business_id = p_business_id
      and m.customer_id = (select auth.uid())
  ) then
    raise exception 'Önce işletmeye katılmalısınız';
  end if;
  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'active'
  ) then
    raise exception 'İşletme aktif değil';
  end if;
  if not exists (
    select 1 from public.employees e
    where e.id = p_employee_id
      and e.business_id = p_business_id
      and e.is_active = true
  ) then
    raise exception 'Çalışan bulunamadı veya aktif değil';
  end if;

  select s.duration_minutes into v_duration
  from public.services s
  where s.id = p_service_id
    and s.business_id = p_business_id
    and s.is_active = true;
  if v_duration is null then
    raise exception 'Hizmet bulunamadı veya aktif değil';
  end if;

  select coalesce(b.appointment_interval_minutes, 30)
  into v_interval
  from public.businesses b
  where b.id = p_business_id;

  v_weekday := extract(dow from p_date)::integer;
  select h.opens_at, h.closes_at
  into v_open, v_close
  from public.business_hours h
  where h.business_id = p_business_id
    and h.weekday = v_weekday
    and h.is_closed = false;

  if v_open is null or v_close is null then
    return;
  end if;

  v_open_local := p_date + v_open;
  v_close_local := p_date + v_close;

  for v_candidate in
    select gs
    from generate_series(
      v_open_local,
      v_close_local - make_interval(mins => v_duration),
      make_interval(mins => v_interval)
    ) as gs
  loop
    v_candidate_end := v_candidate + make_interval(mins => v_duration);
    v_start := v_candidate at time zone 'Europe/Istanbul';
    v_end := v_candidate_end at time zone 'Europe/Istanbul';

    if v_start <= now() then
      continue;
    end if;

    if exists (
      select 1 from public.business_breaks br
      where br.business_id = p_business_id
        and br.weekday = v_weekday
        and v_candidate::time < br.ends_at
        and v_candidate_end::time > br.starts_at
    ) then
      continue;
    end if;

    if exists (
      select 1 from public.appointments a
      where a.business_id = p_business_id
        and a.employee_id = p_employee_id
        and a.status in ('pending', 'confirmed')
        and a.starts_at < v_end
        and a.ends_at > v_start
    ) then
      continue;
    end if;

    slot_start := v_start;
    slot_end := v_end;
    return next;
  end loop;
end;
$$;

revoke all on function public.get_available_appointment_slots(uuid, uuid, uuid, date) from public, anon;
grant execute on function public.get_available_appointment_slots(uuid, uuid, uuid, date) to authenticated;
