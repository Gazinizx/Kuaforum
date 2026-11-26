create or replace function public.admin_has_any_permission()
returns boolean language sql stable security definer set search_path=''
as $$ select private.is_admin() or exists (
 select 1 from private.sub_admin_permissions p join public.profiles u on u.id=p.user_id
 where p.user_id=auth.uid() and u.is_blocked=false and cardinality(p.permissions)>0
); $$;
revoke all on function public.admin_has_any_permission() from public,anon;
grant execute on function public.admin_has_any_permission() to authenticated;
create or replace function public.has_admin_permission(p_permission text)
returns boolean language sql stable security definer set search_path=''
as $$ select private.has_admin_permission(p_permission); $$;
revoke all on function public.has_admin_permission(text) from public,anon;
grant execute on function public.has_admin_permission(text) to authenticated;
do $$
declare r record; v text; perm text;
begin
 for r in select p.proname,pg_get_functiondef(p.oid) def from pg_proc p
 join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'
 and p.proname in ('admin_dashboard_stats','admin_list_businesses','admin_list_users',
 'admin_set_business_status','admin_set_discover_visibility','set_user_blocked')
 loop
  perm:=case r.proname when 'admin_dashboard_stats' then 'dashboard'
   when 'admin_list_businesses' then 'businesses' when 'admin_list_users' then 'users'
   when 'admin_set_business_status' then 'businesses'
   when 'admin_set_discover_visibility' then 'discover' when 'set_user_blocked' then 'users' end;
  v:=replace(r.def,'private.is_admin()','private.has_admin_permission('''||perm||''')');
  v:=replace(v,'(select private.is_admin())','(select private.has_admin_permission('''||perm||'''))');
  execute v;
 end loop;
end $$;
drop policy if exists support_tickets_read_participants on public.support_tickets;
create policy support_tickets_read_participants on public.support_tickets for select to authenticated
using(created_by=(select auth.uid()) or (select private.has_admin_permission('support')));
drop policy if exists support_tickets_update_owner_or_admin on public.support_tickets;
create policy support_tickets_update_owner_or_admin on public.support_tickets for update to authenticated
using(created_by=(select auth.uid()) or (select private.has_admin_permission('support')))
with check((select private.has_admin_permission('support')) or
(created_by=(select auth.uid()) and status='closed'));
drop policy if exists support_messages_read_participants on public.support_ticket_messages;
create policy support_messages_read_participants on public.support_ticket_messages for select to authenticated
using(exists(select 1 from public.support_tickets t where t.id=ticket_id and
(t.created_by=(select auth.uid()) or (select private.has_admin_permission('support')))));
drop policy if exists support_messages_insert_participants on public.support_ticket_messages;
create policy support_messages_insert_participants on public.support_ticket_messages for insert to authenticated
with check(sender_id=(select auth.uid()) and private.is_current_user_active() and
exists(select 1 from public.support_tickets t where t.id=ticket_id and t.status<>'closed'
and (t.created_by=(select auth.uid()) or (select private.has_admin_permission('support')))));
