-- Discover search and post categories.
alter table public.feed_posts
  add column if not exists category text not null default 'Genel';

alter table public.feed_posts
  drop constraint if exists feed_posts_category_check;

alter table public.feed_posts
  add constraint feed_posts_category_check
  check (category in ('Genel', 'Saç Kesimi', 'Boyama', 'Ombre', 'Topuz', 'Bakım'));

create index if not exists feed_posts_category_created_idx
  on public.feed_posts (category, created_at desc);

create or replace view public.public_employee_profiles
with (security_barrier = true, security_invoker = false)
as
select e.user_id, e.business_id, e.display_name, e.id, p.avatar_url
from public.employees e
join public.businesses b on b.id = e.business_id
left join public.profiles p on p.id = e.user_id
where e.is_active = true
  and e.user_id is not null
  and b.status = 'active';

grant select on public.public_employee_profiles to authenticated;
