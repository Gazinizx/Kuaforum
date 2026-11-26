create or replace function private.get_my_sessions()
returns table(
  session_id uuid,
  created_at timestamptz,
  last_active_at timestamptz,
  user_agent text,
  ip_address text,
  is_current boolean
)
language sql
stable
security definer
set search_path to ''
as $function$
  select s.id, s.created_at, coalesce(s.updated_at, s.refreshed_at)::timestamptz,
         s.user_agent, host(s.ip),
         s.id::text = (auth.jwt() ->> 'session_id')
  from auth.sessions s
  where s.user_id = (select auth.uid())
  order by coalesce(s.updated_at, s.refreshed_at, s.created_at) desc;
$function$;

revoke all on function private.get_my_sessions() from public, anon;
grant execute on function private.get_my_sessions() to authenticated;

create or replace function public.get_my_sessions()
returns table(
  session_id uuid,
  created_at timestamptz,
  last_active_at timestamptz,
  user_agent text,
  ip_address text,
  is_current boolean
)
language sql
stable
set search_path to ''
as $function$
  select * from private.get_my_sessions();
$function$;

revoke all on function public.get_my_sessions() from public, anon;
grant execute on function public.get_my_sessions() to authenticated;

create or replace function private.revoke_my_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if (select auth.uid()) is null then raise exception 'Giriş yapmalısınız'; end if;
  if p_session_id::text = (auth.jwt() ->> 'session_id') then
    raise exception 'Mevcut oturumu bu ekrandan kapatamazsınız. Çıkış yap seçeneğini kullanın.';
  end if;
  delete from auth.sessions
  where id = p_session_id and user_id = (select auth.uid());
  if not found then raise exception 'Oturum bulunamadı veya zaten kapatılmış'; end if;
end;
$function$;

revoke all on function private.revoke_my_session(uuid) from public, anon;
grant execute on function private.revoke_my_session(uuid) to authenticated;

create or replace function public.revoke_my_session(p_session_id uuid)
returns void
language sql
set search_path to ''
as $function$
  select private.revoke_my_session(p_session_id);
$function$;

revoke all on function public.revoke_my_session(uuid) from public, anon;
grant execute on function public.revoke_my_session(uuid) to authenticated;
