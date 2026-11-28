-- Allow a conversation participant to mark only messages sent by the other
-- participant as read. Column-level grants prevent editing message content.
drop policy if exists messages_mark_received_read on public.messages;
create policy messages_mark_received_read
on public.messages
for update
to authenticated
using (
  sender_id <> (select auth.uid())
  and exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id = (select auth.uid())
  )
)
with check (
  sender_id <> (select auth.uid())
  and exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = messages.conversation_id
      and cp.user_id = (select auth.uid())
  )
);

revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;
