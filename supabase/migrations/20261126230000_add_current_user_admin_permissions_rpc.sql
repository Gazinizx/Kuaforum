create or replace function public.get_my_admin_permissions()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when private.is_admin() then array['dashboard','businesses','users','discover','support']::text[]
    else coalesce((
      select p.permissions
      from private.sub_admin_permissions p
      join public.profiles u on u.id=p.user_id
      where p.user_id=auth.uid() and u.is_blocked=false
    ), '{}'::text[])
  end;
$$;
revoke all on function public.get_my_admin_permissions() from public, anon;
grant execute on function public.get_my_admin_permissions() to authenticated;