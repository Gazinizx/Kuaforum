create or replace function private.set_business_temporarily_closed(
  p_business_id uuid,
  p_closed boolean
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if (select auth.uid()) is null then
    raise exception 'Giriş yapmalısınız';
  end if;
  if not public.is_current_user_active() then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;
  update public.businesses
  set is_temporarily_closed = p_closed
  where id = p_business_id
    and owner_id = (select auth.uid());
  if not found then
    raise exception 'Bu işletme üzerinde yetkiniz yok';
  end if;
end;
$function$;

revoke all on function private.set_business_temporarily_closed(uuid,boolean) from public, anon;
grant execute on function private.set_business_temporarily_closed(uuid,boolean) to authenticated;

create or replace function public.set_business_temporarily_closed(
  p_business_id uuid,
  p_closed boolean
)
returns void
language sql
set search_path to ''
as $function$
  select private.set_business_temporarily_closed(p_business_id, p_closed);
$function$;

revoke all on function public.set_business_temporarily_closed(uuid,boolean) from public, anon;
grant execute on function public.set_business_temporarily_closed(uuid,boolean) to authenticated;
