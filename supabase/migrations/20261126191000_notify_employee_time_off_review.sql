create or replace function private.notify_employee_time_off_review()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare v_user_id uuid;
begin
  if old.status is distinct from new.status and new.status in ('approved','rejected') then
    select e.user_id into v_user_id from public.employees e where e.id = new.employee_id;
    if v_user_id is not null then
      insert into public.notifications(user_id,title,body)
      values (
        v_user_id,
        case when new.status = 'approved' then 'İzin talebin onaylandı' else 'İzin talebin reddedildi' end,
        coalesce(nullif(new.reason,''),'İzin talebin') ||
          case when new.status = 'approved' then ' işletme sahibi tarafından onaylandı.' else ' işletme sahibi tarafından reddedildi.' end
      );
    end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists employee_time_off_notify_review on public.employee_time_off;
create trigger employee_time_off_notify_review
after update on public.employee_time_off
for each row execute function private.notify_employee_time_off_review();
