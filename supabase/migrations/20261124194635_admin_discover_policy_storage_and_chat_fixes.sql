drop policy if exists "businesses_admin_update" on public.businesses;
create policy "businesses_admin_update" on public.businesses for update to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));

drop policy if exists "salon_feed_staff_upload" on storage.objects;
create policy "salon_feed_staff_upload" on storage.objects for insert to authenticated with check (
 bucket_id='salon-feed' and exists(select 1 from public.businesses b
 where b.id::text=(storage.foldername(storage.objects.name))[1]
 and (b.owner_id=(select auth.uid()) or exists(select 1 from public.employees e where e.business_id=b.id and e.user_id=(select auth.uid()) and e.is_active)))
);

drop policy if exists "salon_feed_owner_delete" on storage.objects;
create policy "salon_feed_owner_delete" on storage.objects for delete to authenticated using (
 bucket_id='salon-feed' and exists(select 1 from public.businesses b
 where b.id::text=(storage.foldername(storage.objects.name))[1]
 and (b.owner_id=(select auth.uid()) or (select private.is_admin())))
);

create or replace function private.touch_conversation_updated_at()
returns trigger language plpgsql set search_path='' as $$
begin
 update public.conversations set updated_at=now() where id=new.conversation_id;
 return new;
end;
$$;
drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation after insert on public.messages
for each row execute function private.touch_conversation_updated_at();
