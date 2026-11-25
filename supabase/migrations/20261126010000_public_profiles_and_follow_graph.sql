-- Public-safe profile projection and readable social follow graph.
-- Email and phone remain private in public.profiles.

create or replace view public.public_profiles
with (security_barrier = true, security_invoker = false)
as
select id, full_name, account_type
from public.profiles
where is_blocked = false;

grant select on public.public_profiles to authenticated;

drop policy if exists feed_follows_read on public.feed_follows;
create policy feed_follows_read
on public.feed_follows for select
to authenticated
using (true);
