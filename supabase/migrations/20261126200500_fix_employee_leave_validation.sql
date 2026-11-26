create or replace function private.leave_employee_business()
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_removed integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Giriş yapmalısınız';
  end if;

  with removed as (
    update public.employees
    set user_id = null, is_active = false
    where user_id = (select auth.uid()) and is_active = true
    returning business_id
  ),
  owner_notifications as (
    insert into public.notifications(user_id, title, body)
    select b.owner_id, 'Çalışan işletmeden ayrıldı',
           'Bir çalışan işletme bağlantısını kaldırdı.'
    from removed r
    join public.businesses b on b.id = r.business_id
    where b.owner_id is not null
    returning 1
  )
  select count(*)::integer into v_removed from removed;

  if v_removed = 0 then
    raise exception 'Aktif çalışan işletme bağlantısı bulunamadı';
  end if;

  update public.profiles
  set account_type = 'customer'
  where id = (select auth.uid()) and account_type = 'employee';

  if not found then
    raise exception 'Çalışan hesabı müşteri hesabına dönüştürülemedi';
  end if;
end;
$function$;
