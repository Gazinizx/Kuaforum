create or replace function private.start_business_conversation(p_business_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_conversation_id uuid;
  v_account_type text;
  v_own_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'Giriş yapmalısınız';
  end if;

  select p.account_type into v_account_type
  from public.profiles p
  where p.id = v_user_id and p.is_blocked = false;

  if v_account_type is null or v_account_type not in ('customer', 'business_owner') then
    raise exception 'Bu işlem müşteri veya işletme sahibi hesabıyla yapılabilir';
  end if;

  if not private.is_current_user_active() then
    raise exception 'Hesabınız mesajlaşma için aktif değil';
  end if;

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id and b.status = 'active'
  ) then
    raise exception 'Aktif işletme bulunamadı';
  end if;

  if v_account_type = 'business_owner' then
    select b.id into v_own_business_id
    from public.businesses b
    where b.owner_id = v_user_id
    limit 1;

    if v_own_business_id is null then
      raise exception 'İşletme hesabınız bulunamadı';
    end if;

    if v_own_business_id = p_business_id then
      raise exception 'Kendi işletmenize mesaj gönderemezsiniz';
    end if;
  end if;

  insert into public.conversations(business_id, employee_id, customer_id, source_post_id, updated_at)
  values (p_business_id, null, v_user_id, null, now())
  on conflict (business_id, customer_id) where employee_id is null
  do update set updated_at = now()
  returning id into v_conversation_id;

  return v_conversation_id;
end;
$function$;

revoke all on function private.start_business_conversation(uuid) from public, anon;
grant execute on function private.start_business_conversation(uuid) to authenticated;
