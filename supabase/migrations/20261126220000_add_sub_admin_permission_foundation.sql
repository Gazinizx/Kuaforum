create table if not exists private.sub_admin_permissions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  permissions text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sub_admin_permissions_allowed check (
    permissions <@ array['dashboard','businesses','users','discover','support']::text[]
  )
);
alter table private.sub_admin_permissions enable row level security;
revoke all on private.sub_admin_permissions from public, anon, authenticated;

create or replace function private.has_admin_permission(p_permission text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(private.is_admin(), false)
    or exists (
      select 1 from private.sub_admin_permissions p
      join public.profiles u on u.id = p.user_id
      where p.user_id = auth.uid()
        and u.is_blocked = false
        and p_permission = any(p.permissions)
    );
$$;
revoke all on function private.has_admin_permission(text) from public, anon;
grant execute on function private.has_admin_permission(text) to authenticated;

create or replace function public.admin_list_subadmins()
returns table(user_id uuid, full_name text, email text, permissions text[], created_at timestamptz)
language plpgsql security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Ana yönetici yetkisi gerekli' using errcode = '42501';
  end if;
  return query
    select p.user_id, u.full_name, u.email, p.permissions, p.created_at
    from private.sub_admin_permissions p
    join public.profiles u on u.id = p.user_id
    order by p.created_at desc;
end;
$$;

create or replace function public.admin_set_subadmin(p_email text, p_permissions text[])
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_permissions text[] := coalesce(p_permissions, '{}'::text[]);
begin
  if not private.is_admin() then
    raise exception 'Ana yönetici yetkisi gerekli' using errcode = '42501';
  end if;
  if p_email is null or length(trim(p_email)) < 5 then
    raise exception 'Geçerli e-posta gerekli';
  end if;
  if exists (
    select 1 from unnest(v_permissions) x
    where x not in ('dashboard','businesses','users','discover','support')
  ) then
    raise exception 'Geçersiz yönetim yetkisi';
  end if;
  select id into v_user_id
  from public.profiles
  where lower(email) = lower(trim(p_email))
    and is_admin = false
    and is_blocked = false
  limit 1;
  if v_user_id is null then
    raise exception 'Bu e-posta ile aktif müşteri hesabı bulunamadı';
  end if;
  if cardinality(v_permissions) = 0 then
    delete from private.sub_admin_permissions where user_id = v_user_id;
  else
    insert into private.sub_admin_permissions(user_id, permissions, updated_at)
    values (v_user_id, v_permissions, now())
    on conflict (user_id) do update
      set permissions = excluded.permissions, updated_at = now();
  end if;
end;
$$;
revoke all on function public.admin_list_subadmins() from public, anon;
revoke all on function public.admin_set_subadmin(text,text[]) from public, anon;
grant execute on function public.admin_list_subadmins() to authenticated;
grant execute on function public.admin_set_subadmin(text,text[]) to authenticated;
