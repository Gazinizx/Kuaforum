alter table public.notifications
  add column if not exists category text not null default 'general'
  check (category in ('appointment','messages','social','support','account','general'));

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  appointments boolean not null default true,
  messages boolean not null default true,
  social boolean not null default true,
  support boolean not null default true,
  account boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.notification_preferences enable row level security;

drop policy if exists notification_preferences_read_own on public.notification_preferences;
create policy notification_preferences_read_own on public.notification_preferences
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists notification_preferences_insert_own on public.notification_preferences;
create policy notification_preferences_insert_own on public.notification_preferences
for insert to authenticated with check (
  user_id = (select auth.uid()) and private.is_current_user_active()
);

drop policy if exists notification_preferences_update_own on public.notification_preferences;
create policy notification_preferences_update_own on public.notification_preferences
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and private.is_current_user_active());

grant select, insert, update on public.notification_preferences to authenticated;

create or replace function private.apply_notification_preferences()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_text text;
  v_enabled boolean := true;
begin
  v_text := lower(coalesce(new.title, '') || ' ' || coalesce(new.body, ''));

  if new.appointment_id is not null or v_text like '%randevu%' or v_text like '%kara liste%' then
    new.category := 'appointment';
  elsif v_text like '%mesaj%' or v_text like '%sohbet%' then
    new.category := 'messages';
  elsif v_text like '%takip%' or v_text like '%beğeni%' or v_text like '%yorum%' or
        v_text like '%paylaşım%' or v_text like '%paylasim%' then
    new.category := 'social';
  elsif v_text like '%destek%' then
    new.category := 'support';
  elsif v_text like '%hesap%' or v_text like '%çalışan%' or v_text like '%izin%' then
    new.category := 'account';
  else
    new.category := 'general';
  end if;

  select case new.category
    when 'appointment' then p.appointments
    when 'messages' then p.messages
    when 'social' then p.social
    when 'support' then p.support
    when 'account' then p.account
    else true
  end
  into v_enabled
  from public.notification_preferences p
  where p.user_id = new.user_id;

  if not found then v_enabled := true; end if;
  if not coalesce(v_enabled, true) then return null; end if;
  return new;
end;
$function$;

revoke all on function private.apply_notification_preferences() from public, anon, authenticated;

drop trigger if exists notifications_apply_preferences on public.notifications;
create trigger notifications_apply_preferences
before insert on public.notifications
for each row execute function private.apply_notification_preferences();
