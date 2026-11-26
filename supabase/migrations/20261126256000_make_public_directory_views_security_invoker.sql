create or replace view public.public_profiles
with (security_invoker = true)
as
select p.id,p.full_name,p.account_type,p.avatar_url
from public.profiles p;

create or replace view public.public_business_employees
with (security_invoker = true)
as
select e.id,e.business_id,e.display_name,p.avatar_url
from public.employees e
join public.businesses b on b.id=e.business_id
join public.public_profiles p on p.id=e.user_id
where e.is_active=true
  and e.user_id is not null
  and b.status='active';