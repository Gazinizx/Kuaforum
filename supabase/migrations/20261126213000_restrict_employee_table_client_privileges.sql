-- Client roles only need read access to employee rows. All writes are performed
-- through ownership-checked SECURITY DEFINER RPCs or the service-role edge function.
REVOKE ALL PRIVILEGES ON TABLE public.employees FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.employees FROM authenticated;
GRANT SELECT ON TABLE public.employees TO authenticated;

-- Invite codes are consumed/created only through private RPCs; never expose the table
-- directly through the Data API.
REVOKE ALL PRIVILEGES ON TABLE public.employee_invites FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.employee_invites FROM authenticated;