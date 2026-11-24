update storage.buckets set public=false where id='salon-feed';
drop policy if exists "salon_feed_public_read" on storage.objects;
drop policy if exists "salon_feed_visible_read" on storage.objects;
create policy "salon_feed_visible_read" on storage.objects
for select to authenticated
using (
 bucket_id='salon-feed'
 and exists(
  select 1 from public.feed_posts p
  join public.businesses b on b.id=p.business_id
  where p.media_url=storage.objects.name
   and b.status='active'
   and (
    (b.discover_paid and b.discover_enabled)
    or b.owner_id=(select auth.uid())
    or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid()))
    or exists(select 1 from public.employees e where e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)
   )
 )
);
