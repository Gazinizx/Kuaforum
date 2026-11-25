-- Restrict profile table access to safe public fields.
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon, authenticated;
GRANT SELECT (id, full_name, account_type, avatar_url)
  ON TABLE public.profiles TO authenticated;
GRANT UPDATE (full_name, phone, avatar_url)
  ON TABLE public.profiles TO authenticated;

-- Public profile views must respect caller RLS.
ALTER VIEW public.public_profiles SET (security_invoker = true);
ALTER VIEW public.public_employee_profiles SET (security_invoker = true);
REVOKE ALL PRIVILEGES ON TABLE public.public_profiles FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.public_employee_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO authenticated;
GRANT SELECT ON TABLE public.public_employee_profiles TO authenticated;

-- Expose contact and moderation fields only to a verified administrator.
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE (
  id uuid,
  full_name text,
  email text,
  phone text,
  account_type text,
  is_admin boolean,
  is_blocked boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT private.is_admin() THEN
    RAISE EXCEPTION 'Yönetici yetkisi gerekli'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT p.id, p.full_name, p.email, p.phone, p.account_type,
         p.is_admin, p.is_blocked, p.created_at
  FROM public.profiles AS p
  ORDER BY p.created_at DESC
  LIMIT 200;
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_list_users() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated;
