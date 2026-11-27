create table if not exists public.feed_saves (
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
alter table public.feed_saves enable row level security;

drop policy if exists feed_saves_read_own on public.feed_saves;
create policy feed_saves_read_own on public.feed_saves
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists feed_saves_insert_own on public.feed_saves;
create policy feed_saves_insert_own on public.feed_saves
for insert to authenticated with check (
  user_id = (select auth.uid())
  and private.is_current_user_active()
  and exists (select 1 from public.feed_posts p where p.id = feed_saves.post_id)
);

drop policy if exists feed_saves_delete_own on public.feed_saves;
create policy feed_saves_delete_own on public.feed_saves
for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, delete on public.feed_saves to authenticated;

drop policy if exists feed_posts_delete on public.feed_posts;
create policy feed_posts_delete on public.feed_posts
for delete to authenticated
using (
  private.is_current_user_active()
  and author_user_id = (select auth.uid())
);
