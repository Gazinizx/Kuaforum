CREATE OR REPLACE FUNCTION private.update_my_business_profile(
  p_business_id uuid,
  p_name text,
  p_address text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NOT public.is_current_user_active() THEN
    RAISE EXCEPTION 'Hesabınız geçici olarak kısıtlandı';
  END IF;
  IF p_name IS NULL OR length(btrim(p_name)) < 2 OR length(btrim(p_name)) > 80 THEN
    RAISE EXCEPTION 'İşletme adı 2-80 karakter arasında olmalı';
  END IF;
  IF length(btrim(coalesce(p_address, ''))) > 180 THEN
    RAISE EXCEPTION 'Adres en fazla 180 karakter olabilir';
  END IF;
  UPDATE public.businesses
  SET name = btrim(p_name),
      address = nullif(btrim(coalesce(p_address, '')), '')
  WHERE id = p_business_id
    AND owner_id = (SELECT auth.uid());
  IF NOT FOUND THEN
    RAISE EXCEPTION 'İşletme bulunamadı veya bu işletme size ait değil';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_my_business_profile(
  p_business_id uuid,
  p_name text,
  p_address text
)
RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT private.update_my_business_profile(p_business_id, p_name, p_address);
$function$;

REVOKE ALL ON FUNCTION private.update_my_business_profile(uuid, text, text) FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.update_my_business_profile(uuid, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.update_my_business_profile(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_my_business_profile(uuid, text, text) TO authenticated;
