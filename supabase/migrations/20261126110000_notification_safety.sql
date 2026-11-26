-- Do not dispatch Kuaförüm notifications to the legacy app's Supabase project.
drop trigger if exists notifications_dispatch_push on public.notifications;
drop function if exists private.dispatch_push_notification();

-- Clients may only mark their own notifications as read.
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;
