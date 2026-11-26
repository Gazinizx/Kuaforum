REVOKE ALL PRIVILEGES ON TABLE public.businesses FROM anon;

DROP POLICY IF EXISTS "owners create own businesses" ON public.businesses;
CREATE POLICY "owners create own businesses"
ON public.businesses FOR INSERT
TO authenticated
WITH CHECK (
  owner_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1 FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.account_type = 'business_owner'
  )
);

CREATE OR REPLACE FUNCTION private.can_read_business_feed(p_business_id uuid, p_author_user_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.businesses AS b
    WHERE b.id = p_business_id
      AND b.status = 'active'
      AND (
        (b.discover_paid AND b.discover_enabled)
        OR b.owner_id = (SELECT auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.business_memberships AS bm
          WHERE bm.business_id = b.id AND bm.customer_id = (SELECT auth.uid())
        )
        OR EXISTS (
          SELECT 1 FROM public.employees AS e
          WHERE e.business_id = b.id AND e.user_id = (SELECT auth.uid()) AND e.is_active = true
        )
        OR EXISTS (
          SELECT 1 FROM public.feed_follows AS f
          WHERE f.follower_user_id = (SELECT auth.uid())
            AND (f.followed_business_id = b.id OR f.followed_user_id = p_author_user_id)
        )
        OR (SELECT private.is_admin())
      )
  );
$function$;

REVOKE ALL ON FUNCTION private.can_read_business_feed(uuid, uuid) FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated;
GRANT EXECUTE ON FUNCTION private.can_read_business_feed(uuid, uuid) TO authenticated;

DROP POLICY IF EXISTS feed_posts_read ON public.feed_posts;
CREATE POLICY feed_posts_read
ON public.feed_posts FOR SELECT
TO authenticated
USING (
  public.is_current_user_active()
  AND private.can_read_business_feed(business_id, author_user_id)
);

DROP POLICY IF EXISTS salon_feed_visible_read ON storage.objects;
CREATE POLICY salon_feed_visible_read
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'salon-feed'
  AND public.is_current_user_active()
  AND EXISTS (
    SELECT 1 FROM public.feed_posts AS p
    WHERE p.media_url = objects.name
      AND private.can_read_business_feed(p.business_id, p.author_user_id)
  )
);
