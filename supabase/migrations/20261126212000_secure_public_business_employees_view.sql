-- Keep the public employee directory under caller RLS instead of view-owner privileges.
ALTER VIEW public.public_business_employees SET (security_invoker = true);

DROP POLICY IF EXISTS employees_public_active_directory_read ON public.employees;
CREATE POLICY employees_public_active_directory_read
ON public.employees
FOR SELECT
TO authenticated
USING (
  is_active = true
  AND user_id IS NOT NULL
  AND private.is_current_user_active()
  AND EXISTS (
    SELECT 1
    FROM public.businesses b
    WHERE b.id = employees.business_id
      AND b.status = 'active'
  )
);
