-- Restrict profile table access to non-sensitive public fields only.
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon, authenticated;
GRANT SELECT (id, full_name, account_type, avatar_url)
  ON TABLE public.profiles TO authenticated;
GRANT UPDATE (full_name, phone, avatar_url)
  ON TABLE public.profiles TO authenticated;

-- Public profile views expose only safe columns and respect caller RLS.
CREATE OR REPLACE VIEW public.public_profiles
WITH (security_invoker = true, security_barrier = true)
AS
SELECT p.id, p.full_name, p.account_type, p.avatar_url
FROM public.profiles AS p;

CREATE OR REPLACE VIEW public.public_employee_profiles
WITH (security_invoker = true, security_barrier = true)
AS
SELECT e.user_id, e.business_id, e.display_name, e.id, p.avatar_url
FROM public.employees AS e
JOIN public.businesses AS b ON b.id = e.business_id
JOIN public.profiles AS p ON p.id = e.user_id
WHERE e.is_active = true
  AND e.user_id IS NOT NULL
  AND b.status = 'active'::text;

REVOKE ALL PRIVILEGES ON TABLE public.public_profiles FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON TABLE public.public_employee_profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.public_profiles TO authenticated;
GRANT SELECT ON TABLE public.public_employee_profiles TO authenticated;

-- Keep private contact and moderation fields behind a non-exposed admin function.
CREATE OR REPLACE FUNCTION private.admin_list_users()
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

REVOKE ALL ON FUNCTION private.admin_list_users() FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.admin_list_users() TO authenticated;

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
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $function$
  SELECT * FROM private.admin_list_users();
$function$;

REVOKE ALL ON FUNCTION public.admin_list_users() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_users() TO authenticated;
