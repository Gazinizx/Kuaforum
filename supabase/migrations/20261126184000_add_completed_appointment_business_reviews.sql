create table if not exists public.business_reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  appointment_id uuid not null unique references public.appointments(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 1000),
  created_at timestamptz not null default now()
);
alter table public.business_reviews enable row level security;

drop policy if exists business_reviews_read on public.business_reviews;
create policy business_reviews_read on public.business_reviews
for select to authenticated using (
  exists (select 1 from public.businesses b
    where b.id = business_id and b.status = 'active')
  or customer_id = (select auth.uid())
  or (select private.is_admin())
);

drop policy if exists business_reviews_insert_completed_customer on public.business_reviews;
create policy business_reviews_insert_completed_customer on public.business_reviews
for insert to authenticated with check (
  customer_id = (select auth.uid())
  and exists (
    select 1 from public.appointments a
    where a.id = appointment_id
      and a.business_id = business_id
      and a.customer_id = (select auth.uid())
      and a.status = 'completed'
  )
);

drop policy if exists business_reviews_delete_admin on public.business_reviews;
create policy business_reviews_delete_admin on public.business_reviews
for delete to authenticated using ((select private.is_admin()));

grant select, insert, delete on public.business_reviews to authenticated;
create index if not exists business_reviews_business_rating_idx
  on public.business_reviews(business_id, rating);
