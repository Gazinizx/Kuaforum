create or replace function private.can_read_business_feed(
  p_business_id uuid,
  p_author_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path to ''
as $function$
  select exists (
    select 1
    from public.businesses b
    where b.id = p_business_id
      and b.status = 'active'
  );
$function$;
