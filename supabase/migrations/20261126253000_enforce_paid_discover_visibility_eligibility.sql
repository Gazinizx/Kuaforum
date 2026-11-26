create or replace function private.enforce_discover_eligibility()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.discover_paid is not true or new.status <> 'active' then
    new.discover_enabled := false;
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_discover_eligibility() from public,anon,authenticated;

drop trigger if exists enforce_discover_eligibility on public.businesses;
create trigger enforce_discover_eligibility
before insert or update of discover_paid,status,discover_enabled
on public.businesses
for each row
execute function private.enforce_discover_eligibility();

alter table public.businesses
  drop constraint if exists businesses_discover_enabled_requires_eligibility;
alter table public.businesses
  add constraint businesses_discover_enabled_requires_eligibility
  check (discover_enabled is not true or (discover_paid is true and status='active'));