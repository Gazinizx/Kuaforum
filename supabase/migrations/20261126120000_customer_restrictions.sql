-- Business customer list and a removable three-no-show approval restriction.
create table if not exists public.business_customer_restrictions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  reason text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  removed_by uuid references public.profiles(id) on delete set null,
  removed_at timestamptz,
  constraint business_customer_restrictions_business_customer_unique
    unique (business_id, customer_id)
);

create index if not exists business_customer_restrictions_active_idx
  on public.business_customer_restrictions (business_id, is_active);

alter table public.business_customer_restrictions enable row level security;
revoke all on public.business_customer_restrictions from anon, authenticated;

create or replace function public.get_business_customers(p_business_id uuid)
returns table(
  customer_id uuid,
  full_name text,
  phone text,
  appointment_count integer,
  no_show_count integer,
  last_appointment_at timestamptz,
  is_blacklisted boolean,
  blacklist_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_current_user_active() then
    raise exception 'Hesabınız geçici olarak kısıtlandı';
  end if;

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id
      and b.owner_id = (select auth.uid())
      and b.status = 'active'
  ) then
    raise exception 'Bu işletmenin müşteri listesini görme yetkiniz yok';
  end if;

  return query
  select
    m.customer_id,
    coalesce(nullif(btrim(p.full_name), ''), 'Kuaförüm kullanıcısı'),
    p.phone,
    count(a.id)::integer,
    count(a.id) filter (where a.status = 'no_show')::integer,
    max(a.starts_at),
    coalesce(r.is_active, false),
    r.reason
  from public.business_memberships m
  join public.profiles p on p.id = m.customer_id
  left join public.appointments a
    on a.business_id = m.business_id
   and a.customer_id = m.customer_id
  left join public.business_customer_restrictions r
    on r.business_id = m.business_id
   and r.customer_id = m.customer_id
  where m.business_id = p_business_id
  group by m.customer_id, p.full_name, p.phone, r.is_active, r.reason
  order by max(a.starts_at) desc nulls last, p.full_name;
end;
$$;

create or replace function public.set_customer_blacklist(
  p_business_id uuid,
  p_customer_id uuid,
  p_blocked boolean,
  p_reason text default null
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

  if not exists (
    select 1 from public.businesses b
    where b.id = p_business_id
      and b.owner_id = (select auth.uid())
      and b.status = 'active'
  ) then
    raise exception 'Bu işletme üzerinde yetkiniz yok';
  end if;

  if not exists (
    select 1 from public.business_memberships m
    where m.business_id = p_business_id
      and m.customer_id = p_customer_id
  ) then
    raise exception 'Müşteri bu işletmeye bağlı değil';
  end if;

  if p_blocked then
    insert into public.business_customer_restrictions(
      business_id, customer_id, is_active, reason, created_by, created_at, removed_by, removed_at
    )
    values (
      p_business_id, p_customer_id, true, nullif(btrim(p_reason), ''),
      (select auth.uid()), now(), null, null
    )
    on conflict (business_id, customer_id)
    do update set
      is_active = true,
      reason = coalesce(nullif(btrim(excluded.reason), ''), business_customer_restrictions.reason),
      created_by = (select auth.uid()),
      created_at = now(),
      removed_by = null,
      removed_at = null;
  else
    update public.business_customer_restrictions
    set is_active = false,
        removed_by = (select auth.uid()),
        removed_at = now()
    where business_id = p_business_id
      and customer_id = p_customer_id
      and is_active = true;
  end if;
end;
$$;

create or replace function private.auto_restrict_three_no_shows()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_no_show_count integer;
begin
  if new.status = 'no_show'
     and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    select count(*)::integer into v_no_show_count
    from public.appointments a
    where a.business_id = new.business_id
      and a.customer_id = new.customer_id
      and a.status = 'no_show';

    if v_no_show_count >= 3 then
      insert into public.business_customer_restrictions(
        business_id, customer_id, is_active, reason, created_by
      )
      values (
        new.business_id, new.customer_id, true,
        'Üç veya daha fazla randevuya gelinmedi',
        (select owner_id from public.businesses where id = new.business_id)
      )
      on conflict (business_id, customer_id)
      do update set
        is_active = true,
        reason = 'Üç veya daha fazla randevuya gelinmedi',
        created_at = now(),
        removed_by = null,
        removed_at = null;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists appointments_auto_restrict_three_no_shows on public.appointments;
create trigger appointments_auto_restrict_three_no_shows
after insert or update of status on public.appointments
for each row execute function private.auto_restrict_three_no_shows();

insert into public.business_customer_restrictions(
  business_id, customer_id, is_active, reason, created_by
)
select
  a.business_id,
  a.customer_id,
  true,
  'Üç veya daha fazla randevuya gelinmedi',
  b.owner_id
from public.appointments a
join public.businesses b on b.id = a.business_id
where a.status = 'no_show'
group by a.business_id, a.customer_id, b.owner_id
having count(*) >= 3
on conflict (business_id, customer_id)
do update set
  is_active = true,
  reason = excluded.reason,
  removed_by = null,
  removed_at = null;

revoke all on function public.get_business_customers(uuid) from public, anon;
grant execute on function public.get_business_customers(uuid) to authenticated;
revoke all on function public.set_customer_blacklist(uuid, uuid, boolean, text) from public, anon;
grant execute on function public.set_customer_blacklist(uuid, uuid, boolean, text) to authenticated;
