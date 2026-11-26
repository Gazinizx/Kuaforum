CREATE OR REPLACE FUNCTION private.admin_dashboard_stats()
RETURNS TABLE (business_count bigint, user_count bigint, post_count bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Yönetici yetkisi gerekli' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.businesses),
    (SELECT count(*) FROM public.profiles),
    (SELECT count(*) FROM public.feed_posts);
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_dashboard_stats()
RETURNS TABLE (business_count bigint, user_count bigint, post_count bigint)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.admin_dashboard_stats();
$function$;

REVOKE ALL ON FUNCTION private.admin_dashboard_stats() FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.admin_dashboard_stats() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_dashboard_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_stats() TO authenticated;
