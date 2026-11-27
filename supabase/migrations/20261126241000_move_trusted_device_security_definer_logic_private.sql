create or replace function private.is_trusted_device(p_device_id text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null or p_device_id is null
     or char_length(p_device_id) not between 24 and 128 then
    return false;
  end if;
  return exists (
    select 1 from private.trusted_devices td
    where td.user_id=v_user_id and td.device_id=p_device_id
  );
end;
$$;
revoke all on function private.is_trusted_device(text) from public,anon;
grant execute on function private.is_trusted_device(text) to authenticated;

create or replace function public.is_trusted_device(p_device_id text)
returns boolean
language sql
set search_path = ''
as $$ select private.is_trusted_device(p_device_id); $$;
revoke all on function public.is_trusted_device(text) from public,anon;
grant execute on function public.is_trusted_device(text) to authenticated;

create or replace function private.trust_current_device(
  p_device_id text,
  p_device_name text default 'Mobil cihaz'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Oturum bulunamadı.';
  end if;
  if p_device_id is null or char_length(p_device_id) not between 24 and 128 then
    raise exception 'Cihaz kimliği geçersiz.';
  end if;
  if p_device_name is null or char_length(btrim(p_device_name)) not between 1 and 120 then
    raise exception 'Cihaz adı geçersiz.';
  end if;
  if exists(select 1 from public.profiles p where p.id=v_user_id and p.is_blocked=true) then
    raise exception 'Bu hesabın erişimi kısıtlanmış.';
  end if;
  insert into private.trusted_devices(user_id,device_id,device_name)
  values(v_user_id,p_device_id,btrim(p_device_name))
  on conflict(user_id,device_id)
  do update set device_name=excluded.device_name,last_seen_at=now();
end;
$$;
revoke all on function private.trust_current_device(text,text) from public,anon;
grant execute on function private.trust_current_device(text,text) to authenticated;

create or replace function public.trust_current_device(
  p_device_id text,
  p_device_name text default 'Mobil cihaz'
)
returns void
language sql
set search_path = ''
as $$ select private.trust_current_device(p_device_id,p_device_name); $$;
revoke all on function public.trust_current_device(text,text) from public,anon;
grant execute on function public.trust_current_device(text,text) to authenticated;