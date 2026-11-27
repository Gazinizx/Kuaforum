create or replace function public.admin_has_any_permission()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.is_admin() or exists (
    select 1
    from private.sub_admin_permissions p
    join public.profiles u on u.id = p.user_id
    where p.user_id = auth.uid()
      and u.is_blocked = false
      and cardinality(p.permissions) > 0
  );
$$;
revoke all on function public.admin_has_any_permission() from public, anon;
grant execute on function public.admin_has_any_permission() to authenticated;

create or replace function public.has_admin_permission(p_permission text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select private.has_admin_permission(p_permission);
$$;
revoke all on function public.has_admin_permission(text) from public, anon;
grant execute on function public.has_admin_permission(text) to authenticated;
