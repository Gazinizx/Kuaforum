do $migration$
declare
  v_slots text;
  v_slots_check text := '  if not exists(select 1 from public.business_memberships m where m.business_id=p_business_id and m.customer_id=(select auth.uid())) then raise exception ''Önce işletmeye katılmalısınız''; end if;';
begin
  v_slots := pg_get_functiondef('private.get_available_appointment_slots(uuid,uuid,uuid,date)'::regprocedure);
  if position('Önce işletmeye katılmalısınız' in v_slots) = 0 then
    raise exception 'get_available_appointment_slots membership guard not found; migration stopped';
  end if;
  v_slots := replace(v_slots, v_slots_check, '');
  if position('Önce işletmeye katılmalısınız' in v_slots) > 0 then
    raise exception 'Could not remove availability membership guard safely';
  end if;
  execute v_slots;
end
$migration$;

create or replace function private.book_appointment(p_business_id uuid, p_employee_id uuid, p_service_id uuid, p_starts_at timestamp with time zone, p_customer_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_duration integer;
  v_interval integer;
  v_end timestamptz;
  v_weekday integer;
  v_open time;
  v_close time;
  v_start_local timestamp;
  v_end_local timestamp;
  v_requires_approval boolean := false;
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapmalısınız'; end if;
  if not private.is_current_user_active() then raise exception 'Hesabınız randevu oluşturmak için aktif değil'; end if;
  if p_starts_at <= now() then raise exception 'Geçmiş bir saate randevu alınamaz'; end if;
  if exists(select 1 from public.profiles where id = auth.uid() and is_blocked) then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;
  if not exists(select 1 from public.businesses where id = p_business_id and status = 'active' and not is_temporarily_closed) then
    raise exception 'İşletme aktif değil veya geçici olarak kapalı';
  end if;
  if not exists(
    select 1 from public.employees e
    join public.profiles employee_profile on employee_profile.id = e.user_id and employee_profile.is_blocked = false
    where e.id = p_employee_id and e.business_id = p_business_id and e.user_id is not null and e.is_active
  ) then raise exception 'Çalışan bulunamadı veya aktif değil'; end if;
  select duration_minutes into v_duration from public.services
  where id = p_service_id and business_id = p_business_id and is_active;
  if v_duration is null then raise exception 'Hizmet bulunamadı veya aktif değil'; end if;
  select appointment_interval_minutes into v_interval from public.businesses where id = p_business_id;
  v_interval := coalesce(v_interval, 30);
  select exists(
    select 1 from public.business_customer_restrictions r
    where r.business_id = p_business_id and r.customer_id = auth.uid() and r.is_active = true
  ) into v_requires_approval;
  v_end := p_starts_at + make_interval(mins => v_duration);
  v_start_local := p_starts_at at time zone 'Europe/Istanbul';
  v_end_local := v_end at time zone 'Europe/Istanbul';
  v_weekday := extract(dow from v_start_local)::integer;
  select opens_at, closes_at into v_open, v_close
  from public.business_hours
  where business_id = p_business_id and weekday = v_weekday and not is_closed;
  if v_open is null or v_close is null or v_start_local::time < v_open or v_end_local::time > v_close then
    raise exception 'Randevu çalışma saatleri dışında';
  end if;
  if mod(extract(epoch from (v_start_local::time - v_open))::integer, v_interval * 60) <> 0 then
    raise exception 'Seçilen saat işletmenin belirlediği randevu aralığına uygun değil';
  end if;
  if exists(
    select 1 from public.business_breaks
    where business_id = p_business_id and weekday = v_weekday
      and v_start_local::time < ends_at and v_end_local::time > starts_at
  ) then raise exception 'Seçilen saat mola aralığına denk geliyor'; end if;
  insert into public.appointments(
    business_id, customer_id, employee_id, service_id, starts_at, ends_at, status, customer_note, requires_business_approval
  ) values (
    p_business_id, auth.uid(), p_employee_id, p_service_id, p_starts_at, v_end,
    case when v_requires_approval then 'pending' else 'confirmed' end, p_customer_note, v_requires_approval
  ) returning id into v_id;
  return v_id;
exception when exclusion_violation then
  raise exception 'Bu saat dolu; lütfen başka saat seçin';
end;
$function$;

revoke all on function private.book_appointment(uuid,uuid,uuid,timestamp with time zone,text) from public, anon;
grant execute on function private.book_appointment(uuid,uuid,uuid,timestamp with time zone,text) to authenticated;
