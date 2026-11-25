create or replace function public.set_employee_active(
  p_employee_id uuid,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.employees e
  set is_active = p_is_active
  from public.businesses b
  where e.id = p_employee_id
    and e.business_id = b.id
    and b.owner_id = (select auth.uid())
    and b.status = 'active';

  if not found then
    raise exception 'Çalışan bulunamadı veya bu işletme üzerinde yetkiniz yok';
  end if;
end;
$$;

revoke all on function public.set_employee_active(uuid, boolean) from public, anon;
grant execute on function public.set_employee_active(uuid, boolean) to authenticated;
