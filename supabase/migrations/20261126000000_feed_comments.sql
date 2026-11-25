-- Feed comments: public comment author labels and row-level access.
-- Safe to apply to projects where feed_comments already exists.

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.feed_comments
  add column if not exists author_name text not null default 'Kuaförüm kullanıcısı';

create index if not exists feed_comments_post_created_idx
  on public.feed_comments (post_id, created_at asc);

create or replace function public.set_feed_comment_author_name()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  select p.full_name into new.author_name
  from public.profiles p
  where p.id = (select auth.uid());

  if new.author_name is null or btrim(new.author_name) = '' then
    new.author_name := 'Kuaförüm kullanıcısı';
  end if;
  return new;
end;
$$;

drop trigger if exists feed_comments_set_author_name on public.feed_comments;
create trigger feed_comments_set_author_name
before insert on public.feed_comments
for each row execute function public.set_feed_comment_author_name();

alter table public.feed_comments enable row level security;

drop policy if exists feed_comments_read on public.feed_comments;
drop policy if exists feed_comments_read_visible_posts on public.feed_comments;
create policy feed_comments_read
on public.feed_comments for select
to authenticated
using (
  exists (
    select 1 from public.feed_posts p
    where p.id = feed_comments.post_id
  )
);

drop policy if exists feed_comments_insert on public.feed_comments;
drop policy if exists feed_comments_insert_visible_posts on public.feed_comments;
create policy feed_comments_insert
on public.feed_comments for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.profiles me
    where me.id = (select auth.uid()) and me.is_blocked = false
  )
  and exists (
    select 1 from public.feed_posts p
    where p.id = feed_comments.post_id
  )
);

drop policy if exists feed_comments_delete on public.feed_comments;
drop policy if exists feed_comments_delete_own_or_admin on public.feed_comments;
create policy feed_comments_delete
on public.feed_comments for delete
to authenticated
using (
  user_id = (select auth.uid())
  or exists (
    select 1
    from public.feed_posts p
    join public.businesses b on b.id = p.business_id
    where p.id = feed_comments.post_id
      and b.owner_id = (select auth.uid())
  )
  or (select private.is_admin())
);

grant select, insert, delete on public.feed_comments to authenticated;
