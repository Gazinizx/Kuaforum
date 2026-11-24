alter table public.businesses add column if not exists discover_paid boolean not null default false;

drop policy if exists "feed_posts_read" on public.feed_posts;
create policy "feed_posts_read" on public.feed_posts for select to authenticated using (
 exists(select 1 from public.businesses b where b.id=feed_posts.business_id and b.status='active'
 and ((b.discover_paid and b.discover_enabled) or b.owner_id=(select auth.uid())
 or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid()))
 or exists(select 1 from public.employees e where e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)))
);

drop policy if exists "feed_posts_update" on public.feed_posts;
create policy "feed_posts_update" on public.feed_posts for update to authenticated
using(author_user_id=(select auth.uid()) and exists(select 1 from public.businesses b where b.id=feed_posts.business_id
 and (b.owner_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=feed_posts.employee_id and e.user_id=(select auth.uid()) and e.is_active))))
with check(author_user_id=(select auth.uid()) and exists(select 1 from public.businesses b where b.id=feed_posts.business_id
 and (b.owner_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=feed_posts.employee_id and e.user_id=(select auth.uid()) and e.is_active)))
 and exists(select 1 from public.employees e where e.id=feed_posts.employee_id and e.business_id=feed_posts.business_id and e.is_active));

drop policy if exists "conversations_customer_create" on public.conversations;
create policy "conversations_customer_create" on public.conversations for insert to authenticated with check (
 customer_id=(select auth.uid()) and exists(select 1 from public.employees e join public.businesses b on b.id=e.business_id
 where e.id=conversations.employee_id and e.business_id=conversations.business_id and e.is_active and b.status='active'
 and ((b.discover_paid and b.discover_enabled) or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid()))))
 and (source_post_id is null or exists(select 1 from public.feed_posts p where p.id=conversations.source_post_id and p.employee_id=conversations.employee_id and p.business_id=conversations.business_id))
);
