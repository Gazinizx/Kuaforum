alter table public.businesses add column if not exists discover_enabled boolean not null default false;

create table if not exists public.feed_posts (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 employee_id uuid not null references public.employees(id) on delete cascade,
 author_user_id uuid not null references public.profiles(id) on delete cascade,
 caption text not null default '',
 media_url text not null,
 media_type text not null check(media_type in ('image','video')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists feed_posts_business_created_idx on public.feed_posts(business_id,created_at desc);
create index if not exists feed_posts_employee_created_idx on public.feed_posts(employee_id,created_at desc);

create table if not exists public.feed_likes (
 post_id uuid not null references public.feed_posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create table if not exists public.feed_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.feed_posts(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 1000),
 created_at timestamptz not null default now()
);
create index if not exists feed_comments_post_created_idx on public.feed_comments(post_id,created_at);

create table if not exists public.conversations (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id) on delete cascade,
 employee_id uuid not null references public.employees(id) on delete cascade,
 customer_id uuid not null references public.profiles(id) on delete cascade,
 source_post_id uuid references public.feed_posts(id) on delete set null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(employee_id,customer_id)
);
create index if not exists conversations_customer_updated_idx on public.conversations(customer_id,updated_at desc);
create index if not exists conversations_employee_updated_idx on public.conversations(employee_id,updated_at desc);

create table if not exists public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 body text not null check(length(btrim(body)) between 1 and 4000),
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id,created_at);

alter table public.feed_posts enable row level security;
alter table public.feed_likes enable row level security;
alter table public.feed_comments enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy "feed_posts_read" on public.feed_posts for select to authenticated using (
 exists(select 1 from public.businesses b where b.id=feed_posts.business_id and b.status='active'
 and (b.discover_enabled or b.owner_id=(select auth.uid())
 or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid()))
 or exists(select 1 from public.employees e where e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)))
);
create policy "feed_posts_insert" on public.feed_posts for insert to authenticated with check (
 author_user_id=(select auth.uid())
 and exists(select 1 from public.businesses b where b.id=feed_posts.business_id and b.status='active'
 and (b.owner_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=feed_posts.employee_id and e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)))
 and exists(select 1 from public.employees e where e.id=feed_posts.employee_id and e.business_id=feed_posts.business_id and e.is_active)
);
create policy "feed_posts_update" on public.feed_posts for update to authenticated using(author_user_id=(select auth.uid())) with check(author_user_id=(select auth.uid()));
create policy "feed_posts_delete" on public.feed_posts for delete to authenticated using (
 author_user_id=(select auth.uid()) or exists(select 1 from public.businesses b where b.id=feed_posts.business_id and b.owner_id=(select auth.uid())) or (select private.is_admin())
);

create policy "feed_likes_read" on public.feed_likes for select to authenticated using(exists(select 1 from public.feed_posts p where p.id=feed_likes.post_id));
create policy "feed_likes_insert" on public.feed_likes for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.feed_posts p where p.id=feed_likes.post_id));
create policy "feed_likes_delete" on public.feed_likes for delete to authenticated using(user_id=(select auth.uid()));

create policy "feed_comments_read" on public.feed_comments for select to authenticated using(exists(select 1 from public.feed_posts p where p.id=feed_comments.post_id));
create policy "feed_comments_insert" on public.feed_comments for insert to authenticated with check(user_id=(select auth.uid()) and exists(select 1 from public.feed_posts p where p.id=feed_comments.post_id));
create policy "feed_comments_delete" on public.feed_comments for delete to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.feed_posts p join public.businesses b on b.id=p.business_id where p.id=feed_comments.post_id and b.owner_id=(select auth.uid())) or (select private.is_admin()));

create policy "conversations_read_participants" on public.conversations for select to authenticated using (
 customer_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=conversations.employee_id and e.user_id=(select auth.uid()))
 or exists(select 1 from public.businesses b where b.id=conversations.business_id and b.owner_id=(select auth.uid()))
);
create policy "conversations_customer_create" on public.conversations for insert to authenticated with check (
 customer_id=(select auth.uid()) and exists(select 1 from public.employees e join public.businesses b on b.id=e.business_id
 where e.id=conversations.employee_id and e.business_id=conversations.business_id and e.is_active and b.status='active'
 and (b.discover_enabled or exists(select 1 from public.business_memberships bm where bm.business_id=b.id and bm.customer_id=(select auth.uid()))))
 and (source_post_id is null or exists(select 1 from public.feed_posts p where p.id=conversations.source_post_id and p.employee_id=conversations.employee_id and p.business_id=conversations.business_id))
);

create policy "messages_read_participants" on public.messages for select to authenticated using (
 exists(select 1 from public.conversations c where c.id=messages.conversation_id and
 (c.customer_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=c.employee_id and e.user_id=(select auth.uid()))))
);
create policy "messages_send_participants" on public.messages for insert to authenticated with check (
 sender_id=(select auth.uid()) and exists(select 1 from public.conversations c where c.id=messages.conversation_id and
 (c.customer_id=(select auth.uid()) or exists(select 1 from public.employees e where e.id=c.employee_id and e.user_id=(select auth.uid()))))
);
grant select,insert,update,delete on public.feed_posts,public.feed_likes,public.feed_comments,public.conversations,public.messages to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('salon-feed','salon-feed',true,52428800,array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime']) on conflict(id) do nothing;
create policy "salon_feed_public_read" on storage.objects for select to public using(bucket_id='salon-feed');
create policy "salon_feed_staff_upload" on storage.objects for insert to authenticated with check (
 bucket_id='salon-feed' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1]
 and (b.owner_id=(select auth.uid()) or exists(select 1 from public.employees e where e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)))
);
create policy "salon_feed_owner_delete" on storage.objects for delete to authenticated using (
 bucket_id='salon-feed' and exists(select 1 from public.businesses b where b.id::text=(storage.foldername(name))[1]
 and (b.owner_id=(select auth.uid()) or (select private.is_admin())))
);
do $$ begin alter publication supabase_realtime add table public.feed_posts; exception when duplicate_object then null; when undefined_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; when undefined_object then null; end $$;
