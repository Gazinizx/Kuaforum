-- Create a safe profile row for every Supabase Auth user.
-- Account type is always customer at signup; role escalation happens only through guarded server functions.
create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, email, phone, account_type, is_admin, is_blocked)
  values (
    new.id,
    coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(coalesce(new.email, ''), '@', 1)),
    new.email,
    nullif(btrim(new.raw_user_meta_data ->> 'phone'), ''),
    'customer',
    false,
    false
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

-- Prevent a signed-in user from changing their own role or moderation flags.
create or replace function private.protect_profile_security_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated')
     and (select auth.uid()) = old.id
     and not (select private.is_admin()) then
    if new.account_type is distinct from old.account_type
       or new.is_admin is distinct from old.is_admin
       or new.is_blocked is distinct from old.is_blocked then
      raise exception 'Hesap yetkileri kullanıcı tarafından değiştirilemez.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_security_fields on public.profiles;
create trigger protect_profile_security_fields
before update on public.profiles
for each row execute function private.protect_profile_security_fields();

-- Business registration is atomic and always creates a pending, unpaid business.
create or replace function private.register_business(p_name text, p_address text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_account_type text;
  v_business_id uuid;
begin
  if v_user_id is null then
    raise exception 'İşletme kaydı için giriş yapmalısınız.';
  end if;
  if p_name is null or length(btrim(p_name)) < 2 or length(btrim(p_name)) > 80 then
    raise exception 'İşletme adı 2-80 karakter arasında olmalıdır.';
  end if;
  if p_address is null or length(btrim(p_address)) < 3 or length(btrim(p_address)) > 180 then
    raise exception 'İşletme adresi 3-180 karakter arasında olmalıdır.';
  end if;

  select account_type into v_account_type
  from public.profiles
  where id = v_user_id
  for update;

  if not found or v_account_type <> 'customer' then
    raise exception 'Bu hesap için yeni işletme kaydı açılamaz.';
  end if;

  if exists (select 1 from public.businesses where owner_id = v_user_id) then
    raise exception 'Bu hesabın zaten bir işletmesi bulunuyor.';
  end if;

  update public.profiles
  set account_type = 'business_owner'
  where id = v_user_id;

  insert into public.businesses (owner_id, name, address, status, discover_enabled, discover_paid)
  values (v_user_id, btrim(p_name), btrim(p_address), 'pending', false, false)
  returning id into v_business_id;

  return v_business_id;
end;
$$;

create or replace function public.register_business(p_name text, p_address text)
returns uuid
language sql
security invoker
set search_path = ''
as $$
  select private.register_business(p_name, p_address);
$$;

revoke all on function private.register_business(text, text) from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.register_business(text, text) to authenticated;
revoke all on function public.register_business(text, text) from public, anon;
grant execute on function public.register_business(text, text) to authenticated;
