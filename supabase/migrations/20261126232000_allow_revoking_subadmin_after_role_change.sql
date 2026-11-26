create or replace function public.admin_set_subadmin(p_email text,p_permissions text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_permissions text[] := coalesce(p_permissions,'{}'::text[]);
begin
  if not private.is_admin() then
    raise exception 'Ana yönetici yetkisi gerekli' using errcode='42501';
  end if;
  if p_email is null or length(trim(p_email)) < 5 then
    raise exception 'Geçerli e-posta gerekli';
  end if;
  if exists (
    select 1 from unnest(v_permissions) x
    where x not in ('dashboard','businesses','users','discover','support')
  ) then
    raise exception 'Geçersiz yönetim yetkisi';
  end if;

  if cardinality(v_permissions)=0 then
    select id into v_user_id from public.profiles
    where lower(email)=lower(trim(p_email)) and is_admin=false
    limit 1;
    if v_user_id is null then
      raise exception 'Alt yönetici hesabı bulunamadı';
    end if;
    delete from private.sub_admin_permissions where user_id=v_user_id;
  else
    select id into v_user_id from public.profiles
    where lower(email)=lower(trim(p_email))
      and account_type='customer' and is_admin=false and is_blocked=false
    limit 1;
    if v_user_id is null then
      raise exception 'Yetki yalnızca aktif müşteri hesaplarına verilebilir';
    end if;
    insert into private.sub_admin_permissions(user_id,permissions,updated_at)
    values(v_user_id,v_permissions,now())
    on conflict(user_id) do update
      set permissions=excluded.permissions,updated_at=now();
  end if;
end;
$$;
revoke all on function public.admin_set_subadmin(text,text[]) from public,anon;
grant execute on function public.admin_set_subadmin(text,text[]) to authenticated;