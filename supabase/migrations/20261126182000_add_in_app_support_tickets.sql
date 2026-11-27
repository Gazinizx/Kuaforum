create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references auth.users(id) on delete cascade,
  subject text not null check (char_length(btrim(subject)) between 3 and 120),
  status text not null default 'pending' check (status in ('pending','in_review','resolved','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 3000),
  created_at timestamptz not null default now()
);

alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;

drop policy if exists support_tickets_read_participants on public.support_tickets;
create policy support_tickets_read_participants on public.support_tickets
for select to authenticated
using (created_by = (select auth.uid()) or (select private.is_admin()));

drop policy if exists support_tickets_create_own on public.support_tickets;
create policy support_tickets_create_own on public.support_tickets
for insert to authenticated
with check (created_by = (select auth.uid()) and private.is_current_user_active());

drop policy if exists support_tickets_update_owner_or_admin on public.support_tickets;
create policy support_tickets_update_owner_or_admin on public.support_tickets
for update to authenticated
using (created_by = (select auth.uid()) or (select private.is_admin()))
with check (
  (select private.is_admin())
  or (created_by = (select auth.uid()) and status = 'closed')
);

drop policy if exists support_messages_read_participants on public.support_ticket_messages;
create policy support_messages_read_participants on public.support_ticket_messages
for select to authenticated
using (
  exists (select 1 from public.support_tickets t
    where t.id = ticket_id
      and (t.created_by = (select auth.uid()) or (select private.is_admin())))
);

drop policy if exists support_messages_insert_participants on public.support_ticket_messages;
create policy support_messages_insert_participants on public.support_ticket_messages
for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and private.is_current_user_active()
  and exists (select 1 from public.support_tickets t
    where t.id = ticket_id
      and t.status <> 'closed'
      and (t.created_by = (select auth.uid()) or (select private.is_admin())))
);

grant select, insert, update on public.support_tickets to authenticated;
grant select, insert on public.support_ticket_messages to authenticated;

create index if not exists support_tickets_created_by_updated_at_idx
  on public.support_tickets(created_by, updated_at desc);
create index if not exists support_ticket_messages_ticket_created_idx
  on public.support_ticket_messages(ticket_id, created_at);
