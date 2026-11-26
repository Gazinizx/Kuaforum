-- Public business data is limited to fields needed by the directory and profiles.
REVOKE ALL PRIVILEGES ON TABLE public.businesses FROM anon, authenticated;
GRANT SELECT (id, name, address, logo_url)
  ON TABLE public.businesses TO anon;
GRANT SELECT (id, name, address, owner_id, status, logo_url, appointment_interval_minutes)
  ON TABLE public.businesses TO authenticated;
GRANT INSERT (owner_id, name, address)
  ON TABLE public.businesses TO authenticated;

DROP POLICY IF EXISTS "owners create own businesses" ON public.businesses;
CREATE POLICY "owners create own businesses"
ON public.businesses FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = (SELECT auth.uid())
  AND status = 'pending'
  AND discover_paid = false
  AND discover_enabled = false
  AND EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.account_type = 'business_owner'
  )
);

CREATE OR REPLACE FUNCTION private.admin_list_businesses()
RETURNS TABLE (
  id uuid, name text, address text, status text,
  discover_paid boolean, discover_enabled boolean, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Yönetici yetkisi gerekli' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT b.id, b.name, b.address, b.status,
         b.discover_paid, b.discover_enabled, b.created_at
  FROM public.businesses AS b
  ORDER BY b.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_list_businesses()
RETURNS TABLE (
  id uuid, name text, address text, status text,
  discover_paid boolean, discover_enabled boolean, created_at timestamptz
)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.admin_list_businesses();
$function$;

CREATE OR REPLACE FUNCTION private.admin_set_business_status(p_business_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Yönetici yetkisi gerekli' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('active', 'inactive', 'rejected') THEN
    RAISE EXCEPTION 'Geçersiz işletme durumu';
  END IF;
  UPDATE public.businesses SET status = p_status WHERE id = p_business_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'İşletme bulunamadı'; END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_set_business_status(p_business_id uuid, p_status text)
RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT private.admin_set_business_status(p_business_id, p_status);
$function$;

CREATE OR REPLACE FUNCTION private.admin_set_discover_visibility(p_business_id uuid, p_enabled boolean)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Yönetici yetkisi gerekli' USING ERRCODE = '42501';
  END IF;
  UPDATE public.businesses
  SET discover_enabled = p_enabled
  WHERE id = p_business_id AND discover_paid = true AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'İşletme aktif değil veya Keşfet erişim hakkı bulunmuyor';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_set_discover_visibility(p_business_id uuid, p_enabled boolean)
RETURNS void
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT private.admin_set_discover_visibility(p_business_id, p_enabled);
$function$;

GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.admin_list_businesses() TO authenticated;
GRANT EXECUTE ON FUNCTION private.admin_set_business_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.admin_set_discover_visibility(uuid, boolean) TO authenticated;

REVOKE ALL ON FUNCTION private.admin_list_businesses() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.admin_set_business_status(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.admin_set_discover_visibility(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_businesses() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_business_status(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_discover_visibility(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_businesses() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_business_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_discover_visibility(uuid, boolean) TO authenticated;
