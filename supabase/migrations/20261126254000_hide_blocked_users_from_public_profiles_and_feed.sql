create or replace view public.public_profiles
with (security_invoker = false)
as
select p.id,p.full_name,p.account_type,p.avatar_url
from public.profiles p
where p.is_blocked=false;

create or replace function private.can_read_business_feed(
  p_business_id uuid,
  p_author_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.businesses b
    join public.profiles author on author.id=p_author_user_id
    where b.id=p_business_id
      and b.status='active'
      and author.is_blocked=false
  );
$$;
revoke all on function private.can_read_business_feed(uuid,uuid) from public,anon,authenticated;
grant execute on function private.can_read_business_feed(uuid,uuid) to authenticated;