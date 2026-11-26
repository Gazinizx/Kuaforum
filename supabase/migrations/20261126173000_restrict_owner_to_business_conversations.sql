drop policy if exists conversations_read_participants on public.conversations;
create policy conversations_read_participants
on public.conversations
for select
to authenticated
using (
  customer_id = (select auth.uid())
  or exists (
    select 1 from public.employees e
    where e.id = conversations.employee_id
      and e.user_id = (select auth.uid())
  )
  or (
    employee_id is null
    and exists (
      select 1 from public.businesses b
      where b.id = conversations.business_id
        and b.owner_id = (select auth.uid())
    )
  )
);

drop policy if exists messages_read_participants on public.messages;
create policy messages_read_participants
on public.messages
for select
to authenticated
using (
  exists (
    select 1
    from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.customer_id = (select auth.uid())
        or exists (
          select 1 from public.employees e
          where e.id = c.employee_id
            and e.user_id = (select auth.uid())
        )
        or (
          c.employee_id is null
          and exists (
            select 1 from public.businesses b
            where b.id = c.business_id
              and b.owner_id = (select auth.uid())
          )
        )
      )
  )
);
