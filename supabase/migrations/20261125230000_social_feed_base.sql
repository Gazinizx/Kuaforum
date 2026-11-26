-- Feed follow graph base tables and nullable business-post author support.
alter table public.feed_posts
  alter column employee_id drop not null;

create table if not exists public.feed_follows (
  id uuid primary key default gen_random_uuid(),
  follower_user_id uuid not null references public.profiles(id) on delete cascade,
  followed_user_id uuid references public.profiles(id) on delete cascade,
  followed_business_id uuid references public.businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint feed_follows_one_target check (
    (followed_user_id is not null and followed_business_id is null)
    or
    (followed_user_id is null and followed_business_id is not null)
  ),
  constraint feed_follows_no_self check (
    followed_user_id is null or follower_user_id <> followed_user_id
  )
);

create unique index if not exists feed_follows_user_target_unique
  on public.feed_follows (follower_user_id, followed_user_id);

create unique index if not exists feed_follows_business_target_unique
  on public.feed_follows (follower_user_id, followed_business_id);

create index if not exists feed_follows_follower_idx
  on public.feed_follows (follower_user_id, created_at desc);

alter table public.feed_follows enable row level security;
grant select, insert, delete on public.feed_follows to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'salon-feed',
  'salon-feed',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
