drop policy if exists business_reviews_insert_completed_customer on public.business_reviews;
create policy business_reviews_insert_completed_customer on public.business_reviews
for insert to authenticated with check (
  customer_id = (select auth.uid())
  and private.is_current_user_active()
  and exists (
    select 1 from public.appointments a
    where a.id = business_reviews.appointment_id
      and a.business_id = business_reviews.business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
);

drop policy if exists feed_posts_delete on public.feed_posts;
create policy feed_posts_delete on public.feed_posts
for delete to authenticated
using (
  private.is_current_user_active()
  and (
    author_user_id = (select auth.uid())
    or (select private.is_admin())
  )
);
