create or replace function private.notify_support_activity()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_creator uuid;
  v_admin uuid;
begin
  if tg_table_name = 'support_tickets' then
    for v_admin in select p.id from public.profiles p where p.is_admin = true loop
      insert into public.notifications(user_id,title,body)
      values (v_admin,'Yeni destek talebi','Yeni bir destek talebi oluşturuldu.');
    end loop;
  else
    select t.created_by into v_creator from public.support_tickets t where t.id = new.ticket_id;
    if new.sender_id = v_creator then
      for v_admin in select p.id from public.profiles p where p.is_admin = true loop
        insert into public.notifications(user_id,title,body)
        values (v_admin,'Destek talebine yeni mesaj','Bir kullanıcı destek talebine yanıt gönderdi.');
      end loop;
    elsif v_creator is not null then
      insert into public.notifications(user_id,title,body)
      values (v_creator,'Destek talebine yanıt geldi','Ana yönetici destek talebine yanıt verdi.');
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists support_ticket_notify_admins on public.support_tickets;
create trigger support_ticket_notify_admins after insert on public.support_tickets
for each row execute function private.notify_support_activity();

drop trigger if exists support_ticket_message_notify on public.support_ticket_messages;
create trigger support_ticket_message_notify after insert on public.support_ticket_messages
for each row execute function private.notify_support_activity();
