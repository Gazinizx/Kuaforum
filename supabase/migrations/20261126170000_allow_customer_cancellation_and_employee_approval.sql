CREATE OR REPLACE FUNCTION private.cancel_appointment(p_appointment_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giriş yapmalısınız'; END IF;
  UPDATE public.appointments a SET status = 'cancelled'
  WHERE a.id = p_appointment_id AND a.status IN ('pending', 'confirmed')
    AND (a.customer_id = auth.uid()
      OR EXISTS (SELECT 1 FROM public.employees e WHERE e.id = a.employee_id AND e.user_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = a.business_id AND b.owner_id = auth.uid()));
  IF NOT FOUND THEN RAISE EXCEPTION 'Randevu bulunamadı veya iptal yetkiniz yok'; END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION private.review_appointment_request(p_appointment_id uuid, p_decision text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Giriş yapmalısınız'; END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN RAISE EXCEPTION 'Geçersiz onay kararı'; END IF;
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_blocked) THEN
    RAISE EXCEPTION 'Hesabınız geçici olarak kısıtlandı';
  END IF;
  UPDATE public.appointments a
  SET status = CASE WHEN p_decision = 'approve' THEN 'confirmed' ELSE 'cancelled' END,
      requires_business_approval = false
  WHERE a.id = p_appointment_id AND a.status = 'pending' AND a.requires_business_approval = true
    AND (EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = a.business_id AND b.owner_id = auth.uid())
      OR EXISTS (SELECT 1 FROM public.employees e WHERE e.id = a.employee_id
        AND e.business_id = a.business_id AND e.user_id = auth.uid() AND e.is_active = true));
  IF NOT FOUND THEN RAISE EXCEPTION 'Onay talebi bulunamadı veya bu işlem için yetkiniz yok'; END IF;
END;
$function$;