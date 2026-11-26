drop policy if exists salon_feed_post_author_delete on storage.objects;
create policy salon_feed_post_author_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'salon-feed'
  and private.is_current_user_active()
  and (
    exists (
      select 1 from public.feed_posts p
      where p.media_url = objects.name
        and p.author_user_id = (select auth.uid())
    )
    or (select private.is_admin())
  )
);
