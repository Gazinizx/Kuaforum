create or replace function private.touch_conversation_updated_at()
returns trigger language plpgsql security definer set search_path=''
as $$
begin
 if pg_trigger_depth()<1 then raise exception 'Trigger context required'; end if;
 update public.conversations set updated_at=now() where id=new.conversation_id;
 return new;
end;
$$;
revoke all on function private.touch_conversation_updated_at() from public,anon,authenticated;
