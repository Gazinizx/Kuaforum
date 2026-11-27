create or replace function private.admin_list_discover_businesses()
returns table(
  id uuid,
  name text,
  address text,
  status text,
  discover_paid boolean,
  discover_enabled boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_admin_permission('discover') then
    raise exception 'Keşfet yönetimi yetkisi gerekli' using errcode='42501';
  end if;
  return query
    select b.id,b.name,b.address,b.status,b.discover_paid,b.discover_enabled,b.created_at
    from public.businesses b
    where b.status='active' and b.discover_paid=true
    order by b.created_at desc;
end;
$$;
revoke all on function private.admin_list_discover_businesses() from public,anon;
grant execute on function private.admin_list_discover_businesses() to authenticated;