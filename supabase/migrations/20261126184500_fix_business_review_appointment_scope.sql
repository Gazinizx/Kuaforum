drop policy if exists business_reviews_insert_completed_customer on public.business_reviews;
create policy business_reviews_insert_completed_customer on public.business_reviews
for insert to authenticated with check (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.appointments a
    where a.id = business_reviews.appointment_id
      and a.business_id = business_reviews.business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
);
