CREATE OR REPLACE FUNCTION public.set_user_blocked(p_user_id uuid, p_blocked boolean)
RETURNS void
LANGUAGE sql
SET search_path TO ''
AS $function$
  SELECT private.set_user_blocked(p_user_id, p_blocked);
$function$;

GRANT EXECUTE ON FUNCTION public.set_user_blocked(uuid, boolean) TO authenticated;