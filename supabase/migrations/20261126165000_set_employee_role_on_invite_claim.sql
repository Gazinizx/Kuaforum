ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_account_type_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_account_type_check
  CHECK (account_type = ANY (ARRAY['customer'::text, 'business_owner'::text, 'employee'::text]));

CREATE OR REPLACE FUNCTION private.claim_employee_invite(p_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_invite_id uuid;
  v_employee_id uuid;
  v_display_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Giriş yapmalısınız';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_blocked
  ) THEN
    RAISE EXCEPTION 'Hesabınız geçici olarak kısıtlandı';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND account_type = 'customer'
  ) THEN
    RAISE EXCEPTION 'Bu davet yalnızca müşteri hesabıyla kullanılabilir';
  END IF;

  SELECT i.id, e.id, e.display_name
  INTO v_invite_id, v_employee_id, v_display_name
  FROM public.employee_invites AS i
  JOIN public.employees AS e ON e.id = i.employee_id
  JOIN public.businesses AS b ON b.id = e.business_id
  WHERE upper(i.invite_code) = upper(trim(coalesce(p_code, '')))
    AND i.claimed_at IS NULL
    AND i.expires_at > now()
    AND e.is_active
    AND e.user_id IS NULL
    AND b.status = 'active'
  FOR UPDATE OF i, e;

  IF v_employee_id IS NULL THEN
    RAISE EXCEPTION 'Davet kodu geçersiz, süresi dolmuş veya daha önce kullanılmış';
  END IF;

  UPDATE public.employees
  SET user_id = auth.uid()
  WHERE id = v_employee_id AND user_id IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Davet kodu başka bir hesap tarafından kullanıldı';
  END IF;

  UPDATE public.employee_invites
  SET claimed_at = now()
  WHERE id = v_invite_id AND claimed_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Davet kodu artık kullanılamıyor';
  END IF;

  UPDATE public.profiles
  SET account_type = 'employee',
      full_name = CASE
        WHEN nullif(btrim(full_name), '') IS NULL THEN v_display_name
        ELSE full_name
      END
  WHERE id = auth.uid()
    AND account_type = 'customer';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Çalışan hesabı etkinleştirilemedi';
  END IF;

  RETURN v_employee_id;
END;
$function$;
