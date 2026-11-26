-- Public-safe profile projection and readable social follow graph.
-- Email and phone remain private in public.profiles.

create or replace view public.public_profiles
with (security_barrier = true, security_invoker = false)
as
select id, full_name, account_type
from public.profiles
where is_blocked = false;

grant select on public.public_profiles to authenticated;

alter table public.feed_follows enable row level security;
grant select, insert, delete on public.feed_follows to authenticated;


drop policy if exists feed_follows_read on public.feed_follows;
create policy feed_follows_read
on public.feed_follows for select
to authenticated
using (public.is_current_user_active());

drop policy if exists feed_follows_insert on public.feed_follows;
create policy feed_follows_insert
on public.feed_follows for insert
to authenticated
with check (
  follower_user_id = (select auth.uid())
  and public.is_current_user_active()
  and (
    (
      followed_user_id is not null
      and followed_user_id <> (select auth.uid())
      and exists (
        select 1 from public.public_profiles target
        where target.id = followed_user_id
      )
    )
    or
    (
      followed_business_id is not null
      and exists (
        select 1 from public.businesses target
        where target.id = followed_business_id
          and target.status = 'active'
          and target.owner_id <> (select auth.uid())
      )
    )
  )
);


drop policy if exists feed_follows_delete on public.feed_follows;
create policy feed_follows_delete
on public.feed_follows for delete
to authenticated
using (follower_user_id = (select auth.uid()));

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
      (
        select count(*)
        from public.feed_follows f
        join public.public_profiles pp on pp.id = f.follower_user_id
        where f.followed_user_id = p_user_id
      ),
      (
        select count(*)
        from public.feed_follows f
        where f.follower_user_id = p_user_id
          and (
            (f.followed_user_id is not null and exists (
              select 1 from public.public_profiles pp where pp.id = f.followed_user_id
            ))
            or
            (f.followed_business_id is not null and exists (
              select 1 from public.businesses b
              where b.id = f.followed_business_id and b.status = 'active'
            ))
          )
      ),
      (
        select count(*)
        from public.feed_posts p
        join public.businesses b on b.id = p.business_id
        where p.author_user_id = p_user_id
          and b.status = 'active'
          and (
            (b.discover_paid and b.discover_enabled)
            or b.owner_id = (select auth.uid())
            or exists (
              select 1 from public.business_memberships bm
              where bm.business_id = b.id and bm.customer_id = (select auth.uid())
            )
            or exists (
              select 1 from public.employees e
              where e.business_id = b.id and e.user_id = (select auth.uid()) and e.is_active
            )
            or exists (
              select 1 from public.feed_follows f
              where f.follower_user_id = (select auth.uid())
                and (
                  f.followed_business_id = b.id
                  or f.followed_user_id = p.author_user_id
                )
            )
          )
      );
  else
    return query
    select
      (
        select count(*)
        from public.feed_follows f
        join public.public_profiles pp on pp.id = f.follower_user_id
        where f.followed_business_id = p_business_id
      ),
      0::bigint,
      (
        select count(*)
        from public.feed_posts p
        join public.businesses b on b.id = p.business_id
        where p.business_id = p_business_id
          and b.status = 'active'
          and (
            (b.discover_paid and b.discover_enabled)
            or b.owner_id = (select auth.uid())
            or exists (
              select 1 from public.business_memberships bm
              where bm.business_id = b.id and bm.customer_id = (select auth.uid())
            )
            or exists (
              select 1 from public.employees e
              where e.business_id = b.id and e.user_id = (select auth.uid()) and e.is_active
            )
            or exists (
              select 1 from public.feed_follows f
              where f.follower_user_id = (select auth.uid())
                and (
                  f.followed_business_id = b.id
                  or f.followed_user_id = p.author_user_id
                )
            )
          )
      );
  end if;
end;
$$;

revoke all on function public.get_social_profile_stats(uuid, uuid) from public, anon;
grant execute on function public.get_social_profile_stats(uuid, uuid) to authenticated;
