drop policy if exists messages_send_participants on public.messages;
create policy messages_send_participants
on public.messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and private.is_current_user_active()
  and exists (
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
