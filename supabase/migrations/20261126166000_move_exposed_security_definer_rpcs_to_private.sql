ALTER FUNCTION public.can_message_employee(uuid) SET SCHEMA private;
ALTER FUNCTION public.get_available_appointment_slots(uuid, uuid, uuid, date) SET SCHEMA private;
ALTER FUNCTION public.get_business_customers(uuid) SET SCHEMA private;
ALTER FUNCTION public.get_my_account_status() SET SCHEMA private;
ALTER FUNCTION public.get_social_profile_stats(uuid, uuid) SET SCHEMA private;
ALTER FUNCTION public.is_current_user_active() SET SCHEMA private;
ALTER FUNCTION public.set_customer_blacklist(uuid, uuid, boolean, text) SET SCHEMA private;
ALTER FUNCTION public.set_employee_active(uuid, boolean) SET SCHEMA private;
ALTER FUNCTION public.set_my_business_logo(uuid, text) SET SCHEMA private;
ALTER FUNCTION public.start_employee_conversation(uuid) SET SCHEMA private;

CREATE OR REPLACE FUNCTION public.can_message_employee(p_employee_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.can_message_employee(p_employee_user_id); $function$;

CREATE OR REPLACE FUNCTION public.get_available_appointment_slots(
  p_business_id uuid, p_employee_id uuid, p_service_id uuid, p_date date
)
RETURNS TABLE(slot_start timestamptz, slot_end timestamptz)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$
  SELECT * FROM private.get_available_appointment_slots(p_business_id, p_employee_id, p_service_id, p_date);
$function$;

CREATE OR REPLACE FUNCTION public.get_business_customers(p_business_id uuid)
RETURNS TABLE(
  customer_id uuid, full_name text, phone text, appointment_count integer,
  no_show_count integer, last_appointment_at timestamptz,
  is_blacklisted boolean, blacklist_reason text
)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_business_customers(p_business_id); $function$;

CREATE OR REPLACE FUNCTION public.get_my_account_status()
RETURNS TABLE(account_type text, is_admin boolean, is_blocked boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_my_account_status(); $function$;

CREATE OR REPLACE FUNCTION public.get_social_profile_stats(
  p_user_id uuid DEFAULT NULL, p_business_id uuid DEFAULT NULL
)
RETURNS TABLE(follower_count bigint, following_count bigint, post_count bigint)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT * FROM private.get_social_profile_stats(p_user_id, p_business_id); $function$;

CREATE OR REPLACE FUNCTION public.is_current_user_active()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.is_current_user_active(); $function$;

CREATE OR REPLACE FUNCTION public.set_customer_blacklist(
  p_business_id uuid, p_customer_id uuid, p_blocked boolean, p_reason text
)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.set_customer_blacklist(p_business_id, p_customer_id, p_blocked, p_reason); $function$;

CREATE OR REPLACE FUNCTION public.set_employee_active(p_employee_id uuid, p_is_active boolean)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.set_employee_active(p_employee_id, p_is_active); $function$;

CREATE OR REPLACE FUNCTION public.set_my_business_logo(p_business_id uuid, p_logo_path text)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.set_my_business_logo(p_business_id, p_logo_path); $function$;

CREATE OR REPLACE FUNCTION public.start_employee_conversation(p_employee_user_id uuid)
RETURNS uuid LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $function$ SELECT private.start_employee_conversation(p_employee_user_id); $function$;

GRANT USAGE ON SCHEMA private TO authenticated;

REVOKE ALL ON FUNCTION private.can_message_employee(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.get_available_appointment_slots(uuid, uuid, uuid, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.get_business_customers(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.get_my_account_status() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.get_social_profile_stats(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.is_current_user_active() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.set_customer_blacklist(uuid, uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.set_employee_active(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.set_my_business_logo(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION private.start_employee_conversation(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION private.can_message_employee(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_available_appointment_slots(uuid, uuid, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_business_customers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_my_account_status() TO authenticated;
GRANT EXECUTE ON FUNCTION private.get_social_profile_stats(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_current_user_active() TO authenticated;
GRANT EXECUTE ON FUNCTION private.set_customer_blacklist(uuid, uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.set_employee_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION private.set_my_business_logo(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION private.start_employee_conversation(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.can_message_employee(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_available_appointment_slots(uuid, uuid, uuid, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_business_customers(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_account_status() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_social_profile_stats(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_current_user_active() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_customer_blacklist(uuid, uuid, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_employee_active(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_my_business_logo(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.start_employee_conversation(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.can_message_employee(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_appointment_slots(uuid, uuid, uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_business_customers(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_account_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_social_profile_stats(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_active() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_customer_blacklist(uuid, uuid, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_employee_active(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_business_logo(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_employee_conversation(uuid) TO authenticated;
