CREATE TABLE IF NOT EXISTS private.trusted_devices (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,
  device_name text NOT NULL DEFAULT 'Mobil cihaz',
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id),
  CONSTRAINT trusted_devices_device_id_length CHECK (char_length(device_id) BETWEEN 24 AND 128),
  CONSTRAINT trusted_devices_device_name_length CHECK (char_length(device_name) BETWEEN 1 AND 120)
);

REVOKE ALL ON TABLE private.trusted_devices FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_trusted_device(p_device_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL OR p_device_id IS NULL OR char_length(p_device_id) NOT BETWEEN 24 AND 128 THEN
    RETURN false;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM private.trusted_devices td
    WHERE td.user_id = v_user_id AND td.device_id = p_device_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.trust_current_device(p_device_id text, p_device_name text DEFAULT 'Mobil cihaz')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Oturum bulunamadı.';
  END IF;
  IF p_device_id IS NULL OR char_length(p_device_id) NOT BETWEEN 24 AND 128 THEN
    RAISE EXCEPTION 'Cihaz kimliği geçersiz.';
  END IF;
  IF p_device_name IS NULL OR char_length(btrim(p_device_name)) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'Cihaz adı geçersiz.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = v_user_id AND p.is_blocked = true) THEN
    RAISE EXCEPTION 'Bu hesabın erişimi kısıtlanmış.';
  END IF;

  INSERT INTO private.trusted_devices(user_id, device_id, device_name)
  VALUES (v_user_id, p_device_id, btrim(p_device_name))
  ON CONFLICT (user_id, device_id)
  DO UPDATE SET device_name = EXCLUDED.device_name, last_seen_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.is_trusted_device(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.trust_current_device(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_trusted_device(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.trust_current_device(text, text) TO authenticated;
