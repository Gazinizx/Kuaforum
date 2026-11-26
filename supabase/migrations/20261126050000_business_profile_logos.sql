-- Business profile logos use the same public avatar bucket.
alter table public.businesses
  add column if not exists logo_url text;

create or replace function public.set_my_business_logo(
  p_business_id uuid,
  p_logo_path text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_active() then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;

  if p_logo_path is null
     or p_logo_path not like ('businesses/' || p_business_id::text || '/%') then
    raise exception 'Invalid business logo path';
  end if;

  update public.businesses
  set logo_url = p_logo_path
  where id = p_business_id
    and owner_id = (select auth.uid())
    and status = 'active';

  if not found then
    raise exception 'Business not found or not owned by current user';
  end if;
end;
$$;

revoke all on function public.set_my_business_logo(uuid, text) from public, anon;
grant execute on function public.set_my_business_logo(uuid, text) to authenticated;

drop policy if exists salon_business_logo_upload_own on storage.objects;
create policy salon_business_logo_upload_own
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'salon-avatars'
  and public.is_current_user_active()
  and (storage.foldername(objects.name))[1] = 'businesses'
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(objects.name))[2]
      and b.owner_id = (select auth.uid())
      and b.status = 'active'
  )
);

drop policy if exists salon_business_logo_delete_own on storage.objects;
create policy salon_business_logo_delete_own
on storage.objects for delete
to authenticated
using (
  bucket_id = 'salon-avatars'
  and public.is_current_user_active()
  and (storage.foldername(objects.name))[1] = 'businesses'
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(objects.name))[2]
      and b.owner_id = (select auth.uid())
      and b.status = 'active'
  )
);
