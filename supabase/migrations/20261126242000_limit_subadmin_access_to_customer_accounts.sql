create or replace function private.has_admin_permission(p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.is_admin(),false) or exists (
    select 1
    from private.sub_admin_permissions p
    join public.profiles u on u.id=p.user_id
    where p.user_id=auth.uid()
      and u.account_type='customer'
      and u.is_blocked=false
      and p_permission=any(p.permissions)
  );
$$;
revoke all on function private.has_admin_permission(text) from public,anon;
grant execute on function private.has_admin_permission(text) to authenticated;

create or replace function private.get_my_admin_permissions()
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
      where p.user_id=auth.uid()
        and u.account_type='customer'
        and u.is_blocked=false
    ), '{}'::text[])
  end;
$$;
revoke all on function private.get_my_admin_permissions() from public,anon;
grant execute on function private.get_my_admin_permissions() to authenticated;