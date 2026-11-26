create table if not exists public.message_hidden_for_me (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

alter table public.message_hidden_for_me enable row level security;

drop policy if exists message_hidden_select_own on public.message_hidden_for_me;
create policy message_hidden_select_own
on public.message_hidden_for_me for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists message_hidden_insert_participant on public.message_hidden_for_me;
create policy message_hidden_insert_participant
on public.message_hidden_for_me for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.messages m
    join public.conversations c on c.id = m.conversation_id
    where m.id = message_hidden_for_me.message_id
      and (
        c.customer_id = (select auth.uid())
        or exists (
          select 1 from public.employees e
          where e.id = c.employee_id and e.user_id = (select auth.uid())
        )
        or (
          c.employee_id is null
          and exists (
            select 1 from public.businesses b
            where b.id = c.business_id and b.owner_id = (select auth.uid())
          )
        )
      )
  )
);

drop policy if exists message_hidden_delete_own on public.message_hidden_for_me;
create policy message_hidden_delete_own
on public.message_hidden_for_me for delete to authenticated
using (user_id = (select auth.uid()));

grant select, insert, delete on public.message_hidden_for_me to authenticated;
