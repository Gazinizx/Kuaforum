create or replace function private.notify_support_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_creator uuid;
  v_recipient uuid;
begin
  if tg_table_name = 'support_tickets' then
    for v_recipient in
      select p.id from public.profiles p
      where p.is_admin=true and p.is_blocked=false
      union
      select s.user_id from private.sub_admin_permissions s
      join public.profiles p on p.id=s.user_id
      where p.account_type='customer' and p.is_blocked=false
        and 'support'=any(s.permissions)
    loop
      insert into public.notifications(user_id,title,body)
      values(v_recipient,'Yeni destek talebi','Yeni bir destek talebi oluşturuldu.');
    end loop;
  else
    select t.created_by into v_creator
    from public.support_tickets t where t.id=new.ticket_id;
    if new.sender_id=v_creator then
      for v_recipient in
        select p.id from public.profiles p
        where p.is_admin=true and p.is_blocked=false
        union
        select s.user_id from private.sub_admin_permissions s
        join public.profiles p on p.id=s.user_id
        where p.account_type='customer' and p.is_blocked=false
          and 'support'=any(s.permissions)
      loop
        insert into public.notifications(user_id,title,body)
        values(v_recipient,'Destek talebine yeni mesaj','Bir kullanıcı destek talebine yanıt gönderdi.');
      end loop;
    elsif v_creator is not null then
      insert into public.notifications(user_id,title,body)
      values(v_creator,'Destek talebine yanıt geldi','Destek ekibinden yeni yanıt geldi.');
    end if;
  end if;
  return new;
end;
$function$;