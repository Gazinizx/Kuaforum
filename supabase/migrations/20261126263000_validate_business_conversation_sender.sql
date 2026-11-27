create or replace function private.validate_conversation_sender_business()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if new.sender_business_id is not null then
    if new.customer_id <> auth.uid() then
      raise exception 'Gönderen kullanıcı oturum açmış kullanıcı olmalı';
    end if;
    if not exists (
      select 1 from public.businesses b
      where b.id = new.sender_business_id
        and b.owner_id = auth.uid()
        and b.status = 'active'
    ) then
      raise exception 'Gönderen işletme bu hesaba ait değil veya aktif değil';
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists validate_conversation_sender_business on public.conversations;
create trigger validate_conversation_sender_business
before insert or update of sender_business_id, customer_id
on public.conversations
for each row execute function private.validate_conversation_sender_business();

revoke all on function private.validate_conversation_sender_business() from public, anon, authenticated;
