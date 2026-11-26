create index if not exists appointments_cancelled_by_idx
  on public.appointments(cancelled_by);
create index if not exists business_customer_restrictions_created_by_idx
  on public.business_customer_restrictions(created_by);
create index if not exists business_customer_restrictions_customer_id_idx
  on public.business_customer_restrictions(customer_id);
create index if not exists business_customer_restrictions_removed_by_idx
  on public.business_customer_restrictions(removed_by);
create index if not exists business_reviews_customer_id_idx
  on public.business_reviews(customer_id);
create index if not exists employee_time_off_reviewed_by_idx
  on public.employee_time_off(reviewed_by);
create index if not exists feed_follows_followed_business_id_idx
  on public.feed_follows(followed_business_id);
create index if not exists feed_follows_followed_user_id_idx
  on public.feed_follows(followed_user_id);
create index if not exists feed_reports_reporter_user_id_idx
  on public.feed_reports(reporter_user_id);
create index if not exists feed_saves_user_id_idx
  on public.feed_saves(user_id);
create index if not exists message_hidden_for_me_user_id_idx
  on public.message_hidden_for_me(user_id);
create index if not exists support_ticket_messages_sender_id_idx
  on public.support_ticket_messages(sender_id);
