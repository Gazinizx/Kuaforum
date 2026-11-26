create policy deny_direct_access_to_sub_admin_permissions
on private.sub_admin_permissions
for all to authenticated
using (false)
with check (false);

create policy deny_direct_access_to_business_customer_restrictions
on public.business_customer_restrictions
for all to authenticated
using (false)
with check (false);