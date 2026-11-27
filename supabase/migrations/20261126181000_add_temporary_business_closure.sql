alter table public.businesses
  add column if not exists is_temporarily_closed boolean not null default false;

create or replace function public.set_business_temporarily_closed(
  p_business_id uuid,
  p_closed boolean
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null then raise exception 'Giriş yapmalısınız'; end if;
  if not exists (
    select 1 from public.businesses
    where id = p_business_id and owner_id = auth.uid()
  ) then
    raise exception 'Bu işletme üzerinde yetkiniz yok';
  end if;
  update public.businesses
  set is_temporarily_closed = p_closed
  where id = p_business_id;
end;
$function$;
grant execute on function public.set_business_temporarily_closed(uuid, boolean) to authenticated;

create or replace function private.prevent_booking_when_business_closed()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if exists (
    select 1 from public.businesses b
    where b.id = new.business_id and b.is_temporarily_closed
  ) then
    raise exception 'İşletme geçici olarak kapalı; şu anda randevu alınamıyor';
  end if;
  return new;
end;
$function$;

drop trigger if exists appointments_prevent_closed_business_booking on public.appointments;
create trigger appointments_prevent_closed_business_booking
before insert on public.appointments
for each row execute function private.prevent_booking_when_business_closed();
