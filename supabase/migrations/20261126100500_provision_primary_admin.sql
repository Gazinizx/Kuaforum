-- Bootstrap the confirmed primary Kuaförüm administrator.
-- This targets only the exact verified Auth email; it never trusts user metadata.
update public.profiles p
set is_admin = true
from auth.users u
where p.id = u.id
  and lower(u.email) = lower('gazitasdemir56@gmail.com')
  and u.email_confirmed_at is not null;
