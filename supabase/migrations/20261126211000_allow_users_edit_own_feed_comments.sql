drop policy if exists feed_comments_update_own on public.feed_comments;
create policy feed_comments_update_own
on public.feed_comments
for update
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));