create or replace function private.set_customer_blacklist(
  p_business_id uuid,
  p_customer_id uuid,
  p_blocked boolean,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if not public.is_current_user_active() then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;

  if not (
    exists (
      select 1 from public.businesses b
      where b.id = p_business_id and b.owner_id = (select auth.uid())
    )
    or exists (
      select 1 from public.employees e
      where e.business_id = p_business_id
        and e.user_id = (select auth.uid())
        and e.is_active
    )
    or (select private.is_admin())
  ) then
    raise exception 'Bu işletme üzerinde kara liste yetkiniz yok';
  end if;

  if not exists (
    select 1 from public.business_memberships m
    where m.business_id = p_business_id and m.customer_id = p_customer_id
  ) then
    raise exception 'Müşteri bu işletmeye bağlı değil';
  end if;

  if p_blocked then
    insert into public.business_customer_restrictions(
      business_id, customer_id, is_active, reason, created_by, created_at, removed_by, removed_at
    )
    values (
      p_business_id, p_customer_id, true, nullif(btrim(p_reason), ''),
      (select auth.uid()), now(), null, null
    )
    on conflict (business_id, customer_id) do update set
      is_active = true,
      reason = coalesce(nullif(btrim(excluded.reason), ''), public.business_customer_restrictions.reason),
      created_by = (select auth.uid()),
      created_at = now(),
      removed_by = null,
      removed_at = null;
  else
    update public.business_customer_restrictions
    set is_active = false,
        removed_by = (select auth.uid()),
        removed_at = now()
    where business_id = p_business_id
      and customer_id = p_customer_id
      and is_active = true;
  end if;
end;
$function$;
grant execute on function private.set_customer_blacklist(uuid,uuid,boolean,text) to authenticated;
