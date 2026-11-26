alter table public.profiles
  drop constraint if exists profiles_only_designated_main_admin;
alter table public.profiles
  add constraint profiles_only_designated_main_admin
  check (is_admin = false or lower(email) = 'gazitasdemir56@gmail.com');

create unique index if not exists profiles_single_main_admin_idx
  on public.profiles (is_admin)
  where is_admin = true;

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_is_main_admin boolean := lower(coalesce(new.email,'')) = 'gazitasdemir56@gmail.com';
begin
  insert into public.profiles (
    id,full_name,email,phone,account_type,is_admin,is_blocked
  )
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'),''),split_part(coalesce(new.email,''),'@',1)),
    new.email,
    nullif(btrim(new.raw_user_meta_data ->> 'phone'),''),
    case when v_is_main_admin then 'admin' else 'customer' end,
    v_is_main_admin,
    false
  )
  on conflict(id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_auth_user() from public,anon,authenticated;