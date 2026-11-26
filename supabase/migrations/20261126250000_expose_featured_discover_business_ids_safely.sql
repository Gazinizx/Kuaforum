create or replace function private.get_discover_featured_businesses()
returns table(business_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select b.id
  from public.businesses b
  where b.status='active'
    and b.discover_paid=true
    and b.discover_enabled=true;
$$;
revoke all on function private.get_discover_featured_businesses() from public,anon;
grant execute on function private.get_discover_featured_businesses() to authenticated;

create or replace function public.get_discover_featured_businesses()
returns table(business_id uuid)
language sql
set search_path = ''
as $$ select * from private.get_discover_featured_businesses(); $$;
revoke all on function public.get_discover_featured_businesses() from public,anon;
grant execute on function public.get_discover_featured_businesses() to authenticated;