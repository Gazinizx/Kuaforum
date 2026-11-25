-- User and employee profile photos.
alter table public.profiles
  add column if not exists avatar_url text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'salon-avatars',
  'salon-avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists salon_avatar_upload_own on storage.objects;
create policy salon_avatar_upload_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'salon-avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists salon_avatar_update_own on storage.objects;
create policy salon_avatar_update_own
on storage.objects for update
to authenticated
using (
  bucket_id = 'salon-avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
)
with check (
  bucket_id = 'salon-avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

drop policy if exists salon_avatar_delete_own on storage.objects;
create policy salon_avatar_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'salon-avatars'
  and (storage.foldername(name))[1] = 'profiles'
  and (storage.foldername(name))[2] = (select auth.uid())::text
);

-- Public profile fields are readable, but contact details remain private.
revoke select on public.profiles from authenticated;
grant select (id, full_name, account_type, is_admin, is_blocked, avatar_url, created_at)
  on public.profiles to authenticated;

drop policy if exists profiles_read_own_row_or_admin on public.profiles;
drop policy if exists "profiles read own row or admin" on public.profiles;
create policy profiles_read_public_safe
on public.profiles for select
to authenticated
using (
  id = (select auth.uid())
  or is_blocked = false
  or (select private.is_admin())
);

-- Do not let users change privileged account fields through the client API.
revoke update on public.profiles from authenticated;
grant update (full_name, phone, avatar_url) on public.profiles to authenticated;

create or replace view public.public_profiles
with (security_barrier = true, security_invoker = false)
as
select id, full_name, account_type, avatar_url
from public.profiles
where is_blocked = false;

grant select on public.public_profiles to authenticated;
