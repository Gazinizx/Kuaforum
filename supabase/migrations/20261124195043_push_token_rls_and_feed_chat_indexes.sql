create index if not exists conversations_business_id_idx on public.conversations(business_id);
create index if not exists conversations_source_post_id_idx on public.conversations(source_post_id);
create index if not exists feed_comments_user_id_idx on public.feed_comments(user_id);
create index if not exists feed_likes_user_id_idx on public.feed_likes(user_id);
create index if not exists feed_posts_author_user_id_idx on public.feed_posts(author_user_id);
create index if not exists messages_sender_id_idx on public.messages(sender_id);

drop policy if exists "push_tokens_owner_select" on public.push_tokens;
drop policy if exists "push_tokens_owner_insert" on public.push_tokens;
drop policy if exists "push_tokens_owner_update" on public.push_tokens;
drop policy if exists "push_tokens_owner_delete" on public.push_tokens;
create policy "push_tokens_owner_select" on public.push_tokens for select to authenticated using(user_id=(select auth.uid()));
create policy "push_tokens_owner_insert" on public.push_tokens for insert to authenticated with check(user_id=(select auth.uid()));
create policy "push_tokens_owner_update" on public.push_tokens for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy "push_tokens_owner_delete" on public.push_tokens for delete to authenticated using(user_id=(select auth.uid()));
grant select,insert,update,delete on public.push_tokens to authenticated;

create or replace function public.register_push_fid(p_fid text,p_platform text)
returns void language plpgsql security invoker set search_path=''
as $$
declare v_user_id uuid := auth.uid();
begin
 if v_user_id is null then raise exception 'Authentication required'; end if;
 if p_fid is null or length(p_fid)<10 or length(p_fid)>256 then raise exception 'Invalid Firebase installation ID'; end if;
 if p_platform not in ('android','ios') then raise exception 'Unsupported push platform'; end if;
 insert into public.push_tokens(user_id,fid,platform,updated_at)
 values(v_user_id,p_fid,p_platform,now())
 on conflict(fid) do update set platform=excluded.platform,updated_at=now()
 where public.push_tokens.user_id=v_user_id;
 if not found then raise exception 'Firebase installation ID is already registered to another account'; end if;
end;
$$;
create or replace function public.unregister_push_fid(p_fid text)
returns void language plpgsql security invoker set search_path=''
as $$
declare v_user_id uuid := auth.uid();
begin
 if v_user_id is null then raise exception 'Authentication required'; end if;
 delete from public.push_tokens where user_id=v_user_id and fid=p_fid;
end;
$$;
revoke all on function public.register_push_fid(text,text) from public,anon;
revoke all on function public.unregister_push_fid(text) from public,anon;
grant execute on function public.register_push_fid(text,text) to authenticated;
grant execute on function public.unregister_push_fid(text) to authenticated;
