-- Public-safe profile projection and readable social follow graph.
-- Email and phone remain private in public.profiles.

create or replace view public.public_profiles
with (security_barrier = true, security_invoker = false)
as
select id, full_name, account_type
from public.profiles
where is_blocked = false;

grant select on public.public_profiles to authenticated;

drop policy if exists feed_follows_read on public.feed_follows;
create policy feed_follows_read
on public.feed_follows for select
to authenticated
using (true);

create or replace function public.get_social_profile_stats(
  p_user_id uuid default null,
  p_business_id uuid default null
)
returns table(follower_count bigint, following_count bigint, post_count bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (p_user_id is null) = (p_business_id is null) then
    raise exception 'Exactly one profile target is required';
  end if;

  if p_user_id is not null then
    return query
    select
      (select count(*) from public.feed_follows f where f.followed_user_id = p_user_id),
      (select count(*) from public.feed_follows f where f.follower_user_id = p_user_id),
      (select count(*) from public.feed_posts p where p.author_user_id = p_user_id);
  else
    return query
    select
      (select count(*) from public.feed_follows f where f.followed_business_id = p_business_id),
      0::bigint,
      (select count(*) from public.feed_posts p where p.business_id = p_business_id);
  end if;
end;
$$;

grant execute on function public.get_social_profile_stats(uuid, uuid) to authenticated;
