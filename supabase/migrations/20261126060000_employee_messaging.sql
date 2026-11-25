-- Wire the existing conversations/messages schema to the approved employee-only messaging flow.
-- Existing tables, participant RLS, and Realtime publication are retained.

drop policy if exists conversations_customer_create on public.conversations;
create policy conversations_customer_create
on public.conversations for insert
to authenticated
with check (
  customer_id = (select auth.uid())
  and employee_id is not null
  and public.is_current_user_active()
  and source_post_id is not null
  and exists (
    select 1
    from public.employees e
    join public.businesses b on b.id = e.business_id
    join public.feed_posts p
      on p.employee_id = e.id
     and p.business_id = b.id
    where e.id = conversations.employee_id
      and e.business_id = conversations.business_id
      and e.is_active = true
      and exists (select 1 from public.public_profiles target where target.id = e.user_id)
      and b.status = 'active'
      and p.id = conversations.source_post_id
      and (
        (b.discover_paid and b.discover_enabled)
        or exists (
          select 1 from public.business_memberships bm
          where bm.business_id = b.id
            and bm.customer_id = (select auth.uid())
        )
        or exists (
          select 1 from public.feed_follows f
          where f.follower_user_id = (select auth.uid())
            and (
              f.followed_user_id = e.user_id
              or f.followed_business_id = b.id
            )
        )
      )
  )
);

create or replace function public.can_message_employee(p_employee_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles me
    join public.employees e on e.user_id = p_employee_user_id
    join public.profiles employee_profile on employee_profile.id = e.user_id and employee_profile.is_blocked = false
    join public.businesses b on b.id = e.business_id
    join public.feed_posts p
      on p.employee_id = e.id
     and p.business_id = b.id
    where me.id = (select auth.uid())
      and p_employee_user_id <> (select auth.uid())
      and me.account_type = 'customer'
      and me.is_blocked = false
      and e.is_active = true
      and b.status = 'active'
      and (
        (b.discover_paid and b.discover_enabled)
        or exists (
          select 1 from public.business_memberships bm
          where bm.business_id = b.id
            and bm.customer_id = (select auth.uid())
        )
        or exists (
          select 1 from public.feed_follows f
          where f.follower_user_id = (select auth.uid())
            and (
              f.followed_user_id = e.user_id
              or f.followed_business_id = b.id
            )
        )
      )
  );
$$;

create or replace function public.start_employee_conversation(
  p_employee_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_employee_id uuid;
  v_business_id uuid;
  v_source_post_id uuid;
  v_conversation_id uuid;
begin
  if v_customer_id is null then
    raise exception 'Authentication required';
  end if;
  if p_employee_user_id = v_customer_id then
    raise exception 'You cannot start a conversation with yourself';
  end if;

  select e.id, e.business_id, p.id
  into v_employee_id, v_business_id, v_source_post_id
  from public.profiles me
  join public.employees e on e.user_id = p_employee_user_id
  join public.profiles employee_profile on employee_profile.id = e.user_id and employee_profile.is_blocked = false
  join public.businesses b on b.id = e.business_id
  join public.feed_posts p
    on p.employee_id = e.id
   and p.business_id = b.id
  where me.id = v_customer_id
    and me.account_type = 'customer'
    and me.is_blocked = false
    and e.is_active = true
    and b.status = 'active'
    and (
      (b.discover_paid and b.discover_enabled)
      or exists (
        select 1 from public.business_memberships bm
        where bm.business_id = b.id
          and bm.customer_id = v_customer_id
      )
      or exists (
        select 1 from public.feed_follows f
        where f.follower_user_id = v_customer_id
          and (
            f.followed_user_id = e.user_id
            or f.followed_business_id = b.id
          )
      )
    )
  order by p.created_at desc
  limit 1;

  if v_employee_id is null or v_source_post_id is null then
    raise exception 'Bu çalışanla mesajlaşmak için önce herkese açık bir paylaşımını veya takip ilişkisini görmelisin.';
  end if;

  insert into public.conversations (
    business_id,
    employee_id,
    customer_id,
    source_post_id,
    updated_at
  )
  values (
    v_business_id,
    v_employee_id,
    v_customer_id,
    v_source_post_id,
    now()
  )
  on conflict (employee_id, customer_id)
  do update set
    source_post_id = excluded.source_post_id,
    updated_at = now()
  returning id into v_conversation_id;

  return v_conversation_id;
end;
$$;

revoke all on function public.can_message_employee(uuid) from public, anon;
grant execute on function public.can_message_employee(uuid) to authenticated;
revoke all on function public.start_employee_conversation(uuid) from public, anon;
grant execute on function public.start_employee_conversation(uuid) to authenticated;

drop policy if exists messages_send_participants on public.messages;
create policy messages_send_participants
on public.messages for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and public.is_current_user_active()
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
      )
  )
);
