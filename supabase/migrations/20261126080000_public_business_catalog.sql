-- Active salons expose their public service menu and working hours to signed-in customers.
drop policy if exists services_public_active_read on public.services;
create policy services_public_active_read
on public.services for select
to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = services.business_id
      and b.status = 'active'
  )
);

drop policy if exists business_hours_public_active_read on public.business_hours;
create policy business_hours_public_active_read
on public.business_hours for select
to authenticated
using (
  exists (
    select 1 from public.businesses b
    where b.id = business_hours.business_id
      and b.status = 'active'
  )
);
