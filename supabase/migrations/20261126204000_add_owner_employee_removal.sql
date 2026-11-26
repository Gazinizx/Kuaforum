create or replace function private.remove_employee(p_employee_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_user_id uuid;
  v_business_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Giriş yapmalısınız'; end if;
  if not public.is_current_user_active() then raise exception 'Hesabınız geçici olarak kısıtlandı'; end if;

  select e.user_id, e.business_id
    into v_user_id, v_business_id
  from public.employees e
  join public.businesses b on b.id = e.business_id
  where e.id = p_employee_id and b.owner_id = (select auth.uid())
  for update of e;

  if not found then raise exception 'Çalışan bulunamadı veya yetkiniz yok'; end if;

  update public.employees
  set user_id = null, is_active = false
  where id = p_employee_id;

  if v_user_id is not null then
    update public.profiles
    set account_type = 'customer'
    where id = v_user_id and account_type = 'employee';

    insert into public.notifications(user_id, title, body)
    values (v_user_id, 'İşletme bağlantın kaldırıldı',
      'İşletme sahibi çalışan bağlantını kaldırdı. Hesabın müşteri hesabı olarak devam ediyor.');
  end if;
end;
$function$;

revoke all on function private.remove_employee(uuid) from public, anon;
grant execute on function private.remove_employee(uuid) to authenticated;

create or replace function public.remove_employee(p_employee_id uuid)
returns void
language sql
set search_path to ''
as $function$
  select private.remove_employee(p_employee_id);
$function$;

revoke all on function public.remove_employee(uuid) from public, anon;
grant execute on function public.remove_employee(uuid) to authenticated;
