-- Authorize feed posts, likes, and private media using the same visibility rules.
alter table public.feed_posts enable row level security;
grant select, insert, update, delete on public.feed_posts to authenticated;

drop policy if exists feed_posts_read on public.feed_posts;
create policy feed_posts_read
on public.feed_posts for select
to authenticated
using (
  public.is_current_user_active()
  and exists (
    select 1
    from public.businesses b
    where b.id = feed_posts.business_id
      and b.status = 'active'
      and (
        (b.discover_paid and b.discover_enabled)
        or b.owner_id = (select auth.uid())
        or exists (
          select 1 from public.business_memberships bm
          where bm.business_id = b.id
            and bm.customer_id = (select auth.uid())
        )
        or exists (
          select 1 from public.employees e
          where e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
        or exists (
          select 1 from public.feed_follows f
          where f.follower_user_id = (select auth.uid())
            and (
              f.followed_business_id = b.id
              or f.followed_user_id = feed_posts.author_user_id
            )
        )
        or (select private.is_admin())
      )
  )
);

drop policy if exists feed_posts_insert on public.feed_posts;
create policy feed_posts_insert
on public.feed_posts for insert
to authenticated
with check (
  public.is_current_user_active()
  and author_user_id = (select auth.uid())
  and exists (
    select 1 from public.businesses b
    where b.id = feed_posts.business_id
      and b.status = 'active'
      and (
        (b.owner_id = (select auth.uid()) and feed_posts.employee_id is null)
        or exists (
          select 1 from public.employees e
          where e.id = feed_posts.employee_id
            and e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
      )
  )
);

drop policy if exists feed_posts_update on public.feed_posts;
create policy feed_posts_update
on public.feed_posts for update
to authenticated
using (
  public.is_current_user_active()
  and author_user_id = (select auth.uid())
  and exists (
    select 1 from public.businesses b
    where b.id = feed_posts.business_id
      and b.status = 'active'
      and (
        (b.owner_id = (select auth.uid()) and feed_posts.employee_id is null)
        or exists (
          select 1 from public.employees e
          where e.id = feed_posts.employee_id
            and e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
      )
  )
)
with check (
  public.is_current_user_active()
  and author_user_id = (select auth.uid())
  and exists (
    select 1 from public.businesses b
    where b.id = feed_posts.business_id
      and b.status = 'active'
      and (
        (b.owner_id = (select auth.uid()) and feed_posts.employee_id is null)
        or exists (
          select 1 from public.employees e
          where e.id = feed_posts.employee_id
            and e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
      )
  )
);

drop policy if exists feed_posts_delete on public.feed_posts;
create policy feed_posts_delete
on public.feed_posts for delete
to authenticated
using (
  (
    public.is_current_user_active()
    and (
      author_user_id = (select auth.uid())
      or exists (
        select 1 from public.businesses b
        where b.id = feed_posts.business_id
          and b.owner_id = (select auth.uid())
      )
    )
  )
  or (select private.is_admin())
);

alter table public.feed_likes enable row level security;
grant select, insert, delete on public.feed_likes to authenticated;

drop policy if exists feed_likes_read on public.feed_likes;
create policy feed_likes_read
on public.feed_likes for select
to authenticated
using (
  exists (select 1 from public.feed_posts p where p.id = feed_likes.post_id)
);

drop policy if exists feed_likes_insert on public.feed_likes;
create policy feed_likes_insert
on public.feed_likes for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and public.is_current_user_active()
  and exists (select 1 from public.feed_posts p where p.id = feed_likes.post_id)
);

drop policy if exists feed_likes_delete on public.feed_likes;
create policy feed_likes_delete
on public.feed_likes for delete
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists salon_feed_staff_upload on storage.objects;
create policy salon_feed_staff_upload
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'salon-feed'
  and public.is_current_user_active()
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(name))[1]
      and b.status = 'active'
      and (
        b.owner_id = (select auth.uid())
        or exists (
          select 1 from public.employees e
          where e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
      )
  )
);

drop policy if exists salon_feed_visible_read on storage.objects;
create policy salon_feed_visible_read
on storage.objects for select
to authenticated
using (
  bucket_id = 'salon-feed'
  and public.is_current_user_active()
  and exists (
    select 1
    from public.feed_posts p
    join public.businesses b on b.id = p.business_id
    where p.media_url = objects.name
      and b.status = 'active'
      and (
        (b.discover_paid and b.discover_enabled)
        or b.owner_id = (select auth.uid())
        or exists (
          select 1 from public.business_memberships bm
          where bm.business_id = b.id
            and bm.customer_id = (select auth.uid())
        )
        or exists (
          select 1 from public.employees e
          where e.business_id = b.id
            and e.user_id = (select auth.uid())
            and e.is_active
        )
        or exists (
          select 1 from public.feed_follows f
          where f.follower_user_id = (select auth.uid())
            and (
              f.followed_business_id = b.id
              or f.followed_user_id = p.author_user_id
            )
        )
        or (select private.is_admin())
      )
  )
);

drop policy if exists salon_feed_post_author_delete on storage.objects;
create policy salon_feed_post_author_delete
on storage.objects for delete
to authenticated
using (
  bucket_id = 'salon-feed'
  and (
    (
      public.is_current_user_active()
      and exists (
        select 1
        from public.feed_posts p
        join public.businesses b on b.id = p.business_id
        where p.media_url = objects.name
          and (
            p.author_user_id = (select auth.uid())
            or b.owner_id = (select auth.uid())
          )
      )
    )
    or (select private.is_admin())
  )
);
