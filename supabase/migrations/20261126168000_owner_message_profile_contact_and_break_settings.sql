-- Allow the business owner to manage conversations for their own salon.
drop policy if exists messages_read_participants on public.messages;
create policy messages_read_participants
on public.messages for select
to authenticated
using (
  exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.customer_id = (select auth.uid())
        or exists (select 1 from public.employees e where e.id = c.employee_id and e.user_id = (select auth.uid()))
        or exists (select 1 from public.businesses b where b.id = c.business_id and b.owner_id = (select auth.uid()))
      )
  )
);

drop policy if exists messages_send_participants on public.messages;
create policy messages_send_participants
on public.messages for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and private.is_current_user_active()
  and exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (
        c.customer_id = (select auth.uid())
        or exists (select 1 from public.employees e where e.id = c.employee_id and e.user_id = (select auth.uid()))
        or exists (select 1 from public.businesses b where b.id = c.business_id and b.owner_id = (select auth.uid()))
      )
  )
);

-- Return only the signed-in user's private contact fields.
create or replace function private.get_my_profile_contact()
returns table(full_name text, phone text)
language sql stable security definer set search_path = ''
as $function$
  select p.full_name, p.phone
  from public.profiles p
  where p.id = (select auth.uid()) and (select auth.uid()) is not null;
$function$;

create or replace function public.get_my_profile_contact()
returns table(full_name text, phone text)
language sql stable security invoker set search_path = ''
as $function$
  select * from private.get_my_profile_contact();
$function$;

grant usage on schema private to authenticated;
revoke all on function private.get_my_profile_contact() from public, anon;
grant execute on function private.get_my_profile_contact() to authenticated;
revoke all on function public.get_my_profile_contact() from public, anon;
grant execute on function public.get_my_profile_contact() to authenticated;

-- Business owners can configure their own recurring break windows.
grant select, insert, update, delete on public.business_breaks to authenticated;

drop policy if exists business_breaks_owner_select on public.business_breaks;
create policy business_breaks_owner_select on public.business_breaks for select to authenticated
using (exists (select 1 from public.businesses b where b.id = business_breaks.business_id and b.owner_id = (select auth.uid())));

drop policy if exists business_breaks_owner_insert on public.business_breaks;
create policy business_breaks_owner_insert on public.business_breaks for insert to authenticated
with check (exists (select 1 from public.businesses b where b.id = business_breaks.business_id and b.owner_id = (select auth.uid())));

drop policy if exists business_breaks_owner_update on public.business_breaks;
create policy business_breaks_owner_update on public.business_breaks for update to authenticated
using (exists (select 1 from public.businesses b where b.id = business_breaks.business_id and b.owner_id = (select auth.uid())))
with check (exists (select 1 from public.businesses b where b.id = business_breaks.business_id and b.owner_id = (select auth.uid())));

drop policy if exists business_breaks_owner_delete on public.business_breaks;
create policy business_breaks_owner_delete on public.business_breaks for delete to authenticated
using (exists (select 1 from public.businesses b where b.id = business_breaks.business_id and b.owner_id = (select auth.uid())));
