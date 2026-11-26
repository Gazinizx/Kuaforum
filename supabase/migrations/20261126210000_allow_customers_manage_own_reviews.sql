drop policy if exists business_reviews_update_own_completed on public.business_reviews;
drop policy if exists business_reviews_delete_own on public.business_reviews;

create policy business_reviews_update_own_completed
on public.business_reviews
for update
to authenticated
using (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.appointments a
    where a.id = business_reviews.appointment_id
      and a.business_id = business_reviews.business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
)
with check (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.appointments a
    where a.id = business_reviews.appointment_id
      and a.business_id = business_reviews.business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
);

create policy business_reviews_delete_own
on public.business_reviews
for delete
to authenticated
using (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.appointments a
    where a.id = business_reviews.appointment_id
      and a.business_id = business_reviews.business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
);