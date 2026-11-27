create or replace function private.notify_feed_like()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_author uuid;
begin
  select p.author_user_id into v_author from public.feed_posts p where p.id = new.post_id;
  if v_author is not null and v_author <> new.user_id then
    insert into public.notifications(user_id,title,body)
    values (v_author,'Yeni beğeni','Paylaşımın beğenildi.');
  end if;
  return new;
end;
$function$;

create or replace function private.notify_feed_comment()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_author uuid;
begin
  select p.author_user_id into v_author from public.feed_posts p where p.id = new.post_id;
  if v_author is not null and v_author <> new.user_id then
    insert into public.notifications(user_id,title,body)
    values (v_author,'Yeni yorum','Paylaşımına yeni bir yorum yapıldı.');
  end if;
  return new;
end;
$function$;

create or replace function private.notify_feed_follow()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_target uuid;
begin
  if new.followed_user_id is not null then
    v_target := new.followed_user_id;
  elsif new.followed_business_id is not null then
    select b.owner_id into v_target from public.businesses b where b.id = new.followed_business_id;
  end if;
  if v_target is not null and v_target <> new.follower_user_id then
    insert into public.notifications(user_id,title,body)
    values (v_target,'Yeni takipçi','Yeni bir kullanıcı seni veya işletmeni takip etmeye başladı.');
  end if;
  return new;
end;
$function$;

create or replace function private.notify_new_message()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare
  v_customer uuid;
  v_employee uuid;
  v_business uuid;
  v_target uuid;
begin
  select c.customer_id,c.employee_id,c.business_id
    into v_customer,v_employee,v_business
  from public.conversations c where c.id = new.conversation_id;

  if v_customer = new.sender_id then
    if v_employee is not null then
      select e.user_id into v_target from public.employees e where e.id = v_employee;
    else
      select b.owner_id into v_target from public.businesses b where b.id = v_business;
    end if;
  else
    v_target := v_customer;
  end if;

  if v_target is not null and v_target <> new.sender_id then
    insert into public.notifications(user_id,title,body)
    values (v_target,'Yeni mesaj','Yeni bir mesajın var.');
  end if;
  return new;
end;
$function$;

create or replace function private.notify_new_feed_post()
returns trigger language plpgsql security definer set search_path to ''
as $function$
declare v_follower uuid;
begin
  for v_follower in
    select distinct f.follower_user_id
    from public.feed_follows f
    where (f.followed_business_id = new.business_id
       or f.followed_user_id = new.author_user_id)
      and f.follower_user_id <> new.author_user_id
  loop
    insert into public.notifications(user_id,title,body)
    values (v_follower,'Yeni paylaşım','Takip ettiğin işletme veya çalışan yeni bir paylaşım yaptı.');
  end loop;
  return new;
end;
$function$;

drop trigger if exists feed_likes_notify on public.feed_likes;
create trigger feed_likes_notify after insert on public.feed_likes
for each row execute function private.notify_feed_like();

drop trigger if exists feed_comments_notify on public.feed_comments;
create trigger feed_comments_notify after insert on public.feed_comments
for each row execute function private.notify_feed_comment();

drop trigger if exists feed_follows_notify on public.feed_follows;
create trigger feed_follows_notify after insert on public.feed_follows
for each row execute function private.notify_feed_follow();

drop trigger if exists messages_notify on public.messages;
create trigger messages_notify after insert on public.messages
for each row execute function private.notify_new_message();

drop trigger if exists feed_posts_notify_followers on public.feed_posts;
create trigger feed_posts_notify_followers after insert on public.feed_posts
for each row execute function private.notify_new_feed_post();
