-- Social post moderation and owner-controlled content management.

create table if not exists public.feed_reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  reporter_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (
    reason in ('Spam', 'Uygunsuz içerik', 'Taciz veya hakaret', 'Sahte hesap / yanıltıcı', 'Diğer')
  ),
  details text,
  status text not null default 'pending' check (
    status in ('pending', 'reviewed', 'dismissed', 'actioned')
  ),
  created_at timestamptz not null default now(),
  unique (post_id, reporter_user_id)
);

create index if not exists feed_reports_status_created_idx
  on public.feed_reports (status, created_at desc);

alter table public.feed_reports enable row level security;

drop policy if exists feed_reports_insert_own on public.feed_reports;
create policy feed_reports_insert_own
on public.feed_reports for insert
to authenticated
with check (
  reporter_user_id = (select auth.uid())
  and public.is_current_user_active()
  and exists (
    select 1 from public.feed_posts p
    where p.id = feed_reports.post_id
      and p.author_user_id <> (select auth.uid())
  )
);

drop policy if exists feed_reports_admin_read on public.feed_reports;
create policy feed_reports_admin_read
on public.feed_reports for select
to authenticated
using ((select private.is_admin()));

grant insert, select on public.feed_reports to authenticated;

drop policy if exists salon_feed_owner_delete on storage.objects;
drop policy if exists salon_feed_post_author_delete on storage.objects;
create policy salon_feed_post_author_delete
on storage.objects for delete
to authenticated
using (
  bucket_id = 'salon-feed'
  and exists (
    select 1
    from public.feed_posts p
    join public.businesses b on b.id = p.business_id
    where p.media_url = objects.name
      and (
        p.author_user_id = (select auth.uid())
        or b.owner_id = (select auth.uid())
        or (select private.is_admin())
      )
  )
);
