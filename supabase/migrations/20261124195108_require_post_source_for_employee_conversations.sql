drop policy if exists "conversations_customer_create" on public.conversations;
create policy "conversations_customer_create" on public.conversations
for insert to authenticated with check (
 customer_id=(select auth.uid())
 and source_post_id is not null
 and exists(
  select 1 from public.employees e
  join public.businesses b on b.id=e.business_id
  join public.feed_posts p on p.employee_id=e.id and p.business_id=b.id
  where e.id=conversations.employee_id
   and e.business_id=conversations.business_id
   and e.is_active
   and b.status='active'
   and p.id=conversations.source_post_id
   and ((b.discover_paid and b.discover_enabled)
     or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid())))
 )
);
