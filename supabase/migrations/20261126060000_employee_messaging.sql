-- Customer-to-employee conversations. Customers can initiate only with active employees
-- who have at least one published post.
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_user_id uuid not null references public.profiles(id) on delete cascade,
  employee_user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  constraint conversations_customer_employee_unique
    unique (customer_user_id, employee_user_id),
  constraint conversations_no_self_chat
    check (customer_user_id <> employee_user_id)
);

create index if not exists conversations_customer_recent_idx
  on public.conversations (customer_user_id, last_message_at desc);
create index if not exists conversations_employee_recent_idx
  on public.conversations (employee_user_id, last_message_at desc);

create table if not exists public.conversation_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists conversation_messages_recent_idx
  on public.conversation_messages (conversation_id, created_at);

alter table public.conversations enable row level security;
alter table public.conversation_messages enable row level security;

drop policy if exists conversations_read_members on public.conversations;
create policy conversations_read_members
on public.conversations for select
to authenticated
using (
  customer_user_id = (select auth.uid())
  or employee_user_id = (select auth.uid())
);

drop policy if exists conversation_messages_read_members on public.conversation_messages;
create policy conversation_messages_read_members
on public.conversation_messages for select
to authenticated
using (
  exists (
    select 1 from public.conversations c
    where c.id = conversation_messages.conversation_id
      and (
        c.customer_user_id = (select auth.uid())
        or c.employee_user_id = (select auth.uid())
      )
  )
);

drop policy if exists conversation_messages_insert_members on public.conversation_messages;
create policy conversation_messages_insert_members
on public.conversation_messages for insert
to authenticated
with check (
  sender_user_id = (select auth.uid())
  and char_length(btrim(body)) between 1 and 2000
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.is_blocked = false
  )
  and exists (
    select 1 from public.conversations c
    where c.id = conversation_messages.conversation_id
      and (
        c.customer_user_id = (select auth.uid())
        or c.employee_user_id = (select auth.uid())
      )
  )
);

grant select on public.conversations to authenticated;
grant select, insert on public.conversation_messages to authenticated;

create or replace function public.can_message_employee(p_employee_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employees e
    join public.businesses b on b.id = e.business_id
    join public.feed_posts p on p.author_user_id = e.user_id
      and p.business_id = e.business_id
    where e.user_id = p_employee_user_id
      and e.is_active = true
      and b.status = 'active'
  );
$$;

create or replace function public.start_employee_conversation(p_employee_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_business_id uuid;
  v_conversation_id uuid;
  v_account_type text;
  v_is_blocked boolean;
begin
  if v_customer_id is null then
    raise exception 'Authentication required';
  end if;

  select p.account_type, p.is_blocked
  into v_account_type, v_is_blocked
  from public.profiles p
  where p.id = v_customer_id;

  if v_account_type <> 'customer' or v_is_blocked then
    raise exception 'Only active customer accounts can start employee conversations';
  end if;

  select e.business_id
  into v_business_id
  from public.employees e
  join public.businesses b on b.id = e.business_id
  where e.user_id = p_employee_user_id
    and e.is_active = true
    and b.status = 'active'
    and exists (
      select 1 from public.feed_posts fp
      where fp.author_user_id = e.user_id
        and fp.business_id = e.business_id
    )
  limit 1;

  if v_business_id is null then
    raise exception 'This employee is not available for messaging';
  end if;

  insert into public.conversations (
    business_id, customer_user_id, employee_user_id
  )
  values (v_business_id, v_customer_id, p_employee_user_id)
  on conflict (customer_user_id, employee_user_id) do nothing
  returning id into v_conversation_id;

  if v_conversation_id is null then
    select c.id into v_conversation_id
    from public.conversations c
    where c.customer_user_id = v_customer_id
      and c.employee_user_id = p_employee_user_id;
  end if;

  return v_conversation_id;
end;
$$;

create or replace function public.touch_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.conversations
  set last_message_at = new.created_at
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists conversation_messages_touch_conversation
  on public.conversation_messages;
create trigger conversation_messages_touch_conversation
after insert on public.conversation_messages
for each row execute function public.touch_conversation_last_message();

revoke all on function public.can_message_employee(uuid) from public, anon;
grant execute on function public.can_message_employee(uuid) to authenticated;
revoke all on function public.start_employee_conversation(uuid) from public, anon;
grant execute on function public.start_employee_conversation(uuid) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_messages'
  ) then
    alter publication supabase_realtime add table public.conversation_messages;
  end if;
end $$;
