CREATE OR REPLACE FUNCTION private.get_my_business_join_code(p_business_id uuid)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
DECLARE v_code text;
BEGIN
  IF NOT public.is_current_user_active() THEN
    RAISE EXCEPTION 'Hesabınız geçici olarak kısıtlandı';
  END IF;
  SELECT b.join_code INTO v_code
  FROM public.businesses AS b
  WHERE b.id = p_business_id
    AND b.owner_id = (SELECT auth.uid())
    AND b.status = 'active';
  IF v_code IS NULL THEN
    RAISE EXCEPTION 'Aktif işletme bulunamadı veya bu işletme size ait değil';
  END IF;
  RETURN v_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_business_join_code(p_business_id uuid)
RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT private.get_my_business_join_code(p_business_id);
$function$;

REVOKE ALL ON FUNCTION private.get_my_business_join_code(uuid) FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_business_join_code(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_business_join_code(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_business_join_code(uuid) TO authenticated;
