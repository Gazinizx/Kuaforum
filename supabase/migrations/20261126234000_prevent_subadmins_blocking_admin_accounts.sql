create or replace function private.set_user_blocked(p_user_id uuid,p_blocked boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.has_admin_permission('users') then
    raise exception 'Kullanıcı yönetimi yetkisi gerekli' using errcode='42501';
  end if;
  if p_user_id=auth.uid() then
    raise exception 'Yönetici kendi hesabını engelleyemez';
  end if;
  if not private.is_admin() and exists (
    select 1 from public.profiles p where p.id=p_user_id and p.is_admin=true
  ) then
    raise exception 'Alt yöneticiler ana yönetici hesabını engelleyemez';
  end if;
  if not private.is_admin() and exists (
    select 1 from private.sub_admin_permissions s where s.user_id=p_user_id
  ) then
    raise exception 'Alt yöneticiler başka bir alt yöneticiyi engelleyemez';
  end if;
  update public.profiles set is_blocked=p_blocked where id=p_user_id;
  if not found then raise exception 'Kullanıcı bulunamadı'; end if;
end;
$$;
revoke all on function private.set_user_blocked(uuid,boolean) from public,anon;
grant execute on function private.set_user_blocked(uuid,boolean) to authenticated;