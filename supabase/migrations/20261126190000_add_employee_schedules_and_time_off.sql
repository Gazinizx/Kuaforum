create table if not exists public.employee_working_hours (
  employee_id uuid not null references public.employees(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time not null default '09:00',
  closes_at time not null default '18:00',
  is_closed boolean not null default false,
  primary key (employee_id, weekday),
  check (closes_at > opens_at)
);
alter table public.employee_working_hours enable row level security;

drop policy if exists employee_hours_read_available on public.employee_working_hours;
create policy employee_hours_read_available on public.employee_working_hours
for select to authenticated using (
  exists (
    select 1 from public.employees e
    join public.businesses b on b.id = e.business_id
    where e.id = employee_id and b.status = 'active'
  )
);

drop policy if exists employee_hours_write_self on public.employee_working_hours;
create policy employee_hours_write_self on public.employee_working_hours
for all to authenticated
using (exists (select 1 from public.employees e where e.id = employee_id and e.user_id = (select auth.uid()) and e.is_active))
with check (exists (select 1 from public.employees e where e.id = employee_id and e.user_id = (select auth.uid()) and e.is_active));

grant select, insert, update, delete on public.employee_working_hours to authenticated;

create table if not exists public.employee_time_off (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text not null default '',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
alter table public.employee_time_off enable row level security;

drop policy if exists employee_time_off_read_parties on public.employee_time_off;
create policy employee_time_off_read_parties on public.employee_time_off
for select to authenticated using (
  exists (select 1 from public.employees e where e.id = employee_id and e.user_id = (select auth.uid()))
  or exists (
    select 1 from public.employees e
    join public.businesses b on b.id = e.business_id
    where e.id = employee_id and b.owner_id = (select auth.uid())
  )
);

drop policy if exists employee_time_off_insert_self on public.employee_time_off;
create policy employee_time_off_insert_self on public.employee_time_off
for insert to authenticated with check (
  status = 'pending'
  and starts_at > now()
  and exists (select 1 from public.employees e
    where e.id = employee_id and e.user_id = (select auth.uid()) and e.is_active)
);

drop policy if exists employee_time_off_owner_review on public.employee_time_off;
create policy employee_time_off_owner_review on public.employee_time_off
for update to authenticated
using (exists (
  select 1 from public.employees e
  join public.businesses b on b.id = e.business_id
  where e.id = employee_id and b.owner_id = (select auth.uid())
))
with check (
  status in ('approved','rejected')
  and reviewed_by = (select auth.uid())
);

grant select, insert, update on public.employee_time_off to authenticated;
create index if not exists employee_time_off_employee_range_idx
  on public.employee_time_off(employee_id, starts_at, ends_at);

create or replace function private.prevent_employee_schedule_conflict()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_weekday integer;
  v_start_local timestamp;
  v_end_local timestamp;
  v_employee_open time;
  v_employee_close time;
  v_closed boolean;
begin
  if new.employee_id is null then return new; end if;
  v_start_local := new.starts_at at time zone 'Europe/Istanbul';
  v_end_local := new.ends_at at time zone 'Europe/Istanbul';
  v_weekday := extract(dow from v_start_local)::integer;

  select eh.opens_at,eh.closes_at,eh.is_closed
    into v_employee_open,v_employee_close,v_closed
  from public.employee_working_hours eh
  where eh.employee_id = new.employee_id and eh.weekday = v_weekday;

  if found and (v_closed or v_start_local::time < v_employee_open or v_end_local::time > v_employee_close) then
    raise exception 'Seçilen saat çalışanın çalışma saatleri dışında';
  end if;

  if exists (
    select 1 from public.employee_time_off t
    where t.employee_id = new.employee_id and t.status = 'approved'
      and t.starts_at < new.ends_at and t.ends_at > new.starts_at
  ) then
    raise exception 'Çalışan bu saatlerde izinli';
  end if;
  return new;
end;
$function$;

drop trigger if exists appointments_employee_schedule_guard on public.appointments;
create trigger appointments_employee_schedule_guard
before insert on public.appointments
for each row execute function private.prevent_employee_schedule_conflict();

create or replace function private.get_available_appointment_slots(
  p_business_id uuid,
  p_employee_id uuid,
  p_service_id uuid,
  p_date date
)
returns table(slot_start timestamptz, slot_end timestamptz)
language plpgsql stable security definer set search_path to ''
as $function$
declare
  v_duration integer;
  v_interval integer;
  v_weekday integer;
  v_open time;
  v_close time;
  v_employee_open time;
  v_employee_close time;
  v_employee_closed boolean;
  v_open_local timestamp;
  v_close_local timestamp;
  v_candidate timestamp;
  v_candidate_end timestamp;
  v_start timestamptz;
  v_end timestamptz;
begin
  if (select auth.uid()) is null then raise exception 'Giriş yapmalısınız'; end if;
  if not public.is_current_user_active() then raise exception 'Hesabınız geçici olarak kısıtlandı'; end if;
  if p_date < (now() at time zone 'Europe/Istanbul')::date then return; end if;
  if not exists(select 1 from public.business_memberships m where m.business_id=p_business_id and m.customer_id=(select auth.uid())) then raise exception 'Önce işletmeye katılmalısınız'; end if;
  if not exists(select 1 from public.businesses b where b.id=p_business_id and b.status='active' and not b.is_temporarily_closed) then raise exception 'İşletme aktif değil veya geçici olarak kapalı'; end if;
  if not exists(
    select 1 from public.employees e
    join public.profiles employee_profile on employee_profile.id=e.user_id and employee_profile.is_blocked=false
    where e.id=p_employee_id and e.business_id=p_business_id and e.user_id is not null and e.is_active=true
  ) then raise exception 'Çalışan bulunamadı veya aktif değil'; end if;

  select s.duration_minutes into v_duration from public.services s where s.id=p_service_id and s.business_id=p_business_id and s.is_active=true;
  if v_duration is null then raise exception 'Hizmet bulunamadı veya aktif değil'; end if;
  select coalesce(b.appointment_interval_minutes,30) into v_interval from public.businesses b where b.id=p_business_id;
  v_weekday:=extract(dow from p_date)::integer;

  select h.opens_at,h.closes_at into v_open,v_close
  from public.business_hours h where h.business_id=p_business_id and h.weekday=v_weekday and h.is_closed=false;
  if v_open is null or v_close is null then return; end if;

  select eh.opens_at,eh.closes_at,eh.is_closed
    into v_employee_open,v_employee_close,v_employee_closed
  from public.employee_working_hours eh
  where eh.employee_id=p_employee_id and eh.weekday=v_weekday;
  if found then
    if v_employee_closed then return; end if;
    v_open := greatest(v_open,v_employee_open);
    v_close := least(v_close,v_employee_close);
  end if;
  if v_close <= v_open then return; end if;

  v_open_local:=p_date+v_open;
  v_close_local:=p_date+v_close;
  for v_candidate in
    select gs from generate_series(v_open_local,v_close_local-make_interval(mins=>v_duration),make_interval(mins=>v_interval)) as gs
  loop
    v_candidate_end:=v_candidate+make_interval(mins=>v_duration);
    v_start:=v_candidate at time zone 'Europe/Istanbul';
    v_end:=v_candidate_end at time zone 'Europe/Istanbul';
    if v_start<=now() then continue; end if;
    if exists(select 1 from public.business_breaks br where br.business_id=p_business_id and br.weekday=v_weekday and v_candidate::time<br.ends_at and v_candidate_end::time>br.starts_at) then continue; end if;
    if exists(select 1 from public.employee_time_off t where t.employee_id=p_employee_id and t.status='approved' and t.starts_at<v_end and t.ends_at>v_start) then continue; end if;
    if exists(select 1 from public.appointments a where a.business_id=p_business_id and a.employee_id=p_employee_id and a.status in ('pending','confirmed') and a.starts_at<v_end and a.ends_at>v_start) then continue; end if;
    slot_start:=v_start; slot_end:=v_end; return next;
  end loop;
end;
$function$;
