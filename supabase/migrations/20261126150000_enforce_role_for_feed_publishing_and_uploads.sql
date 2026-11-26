DROP POLICY IF EXISTS feed_posts_insert ON public.feed_posts;
CREATE POLICY feed_posts_insert
ON public.feed_posts FOR INSERT
TO authenticated
WITH CHECK (
  public.is_current_user_active()
  AND author_user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.businesses AS b
    JOIN public.profiles AS me ON me.id = (SELECT auth.uid())
    WHERE b.id = feed_posts.business_id
      AND b.status = 'active'
      AND (
        (
          b.owner_id = (SELECT auth.uid())
          AND feed_posts.employee_id IS NULL
          AND me.account_type = 'business_owner'
        )
        OR
        (
          feed_posts.employee_id IS NOT NULL
          AND me.account_type = 'employee'
          AND EXISTS (
            SELECT 1
            FROM public.employees AS e
            WHERE e.id = feed_posts.employee_id
              AND e.business_id = b.id
              AND e.user_id = (SELECT auth.uid())
              AND e.is_active = true
          )
        )
      )
  )
);

DROP POLICY IF EXISTS feed_posts_update ON public.feed_posts;
CREATE POLICY feed_posts_update
ON public.feed_posts FOR UPDATE
TO authenticated
USING (
  public.is_current_user_active()
  AND author_user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.businesses AS b
    JOIN public.profiles AS me ON me.id = (SELECT auth.uid())
    WHERE b.id = feed_posts.business_id
      AND b.status = 'active'
      AND (
        (
          b.owner_id = (SELECT auth.uid())
          AND feed_posts.employee_id IS NULL
          AND me.account_type = 'business_owner'
        )
        OR
        (
          feed_posts.employee_id IS NOT NULL
          AND me.account_type = 'employee'
          AND EXISTS (
            SELECT 1
            FROM public.employees AS e
            WHERE e.id = feed_posts.employee_id
              AND e.business_id = b.id
              AND e.user_id = (SELECT auth.uid())
              AND e.is_active = true
          )
        )
      )
  )
)
WITH CHECK (
  public.is_current_user_active()
  AND author_user_id = (SELECT auth.uid())
  AND EXISTS (
    SELECT 1
    FROM public.businesses AS b
    JOIN public.profiles AS me ON me.id = (SELECT auth.uid())
    WHERE b.id = feed_posts.business_id
      AND b.status = 'active'
      AND (
        (
          b.owner_id = (SELECT auth.uid())
          AND feed_posts.employee_id IS NULL
          AND me.account_type = 'business_owner'
        )
        OR
        (
          feed_posts.employee_id IS NOT NULL
          AND me.account_type = 'employee'
          AND EXISTS (
            SELECT 1
            FROM public.employees AS e
            WHERE e.id = feed_posts.employee_id
              AND e.business_id = b.id
              AND e.user_id = (SELECT auth.uid())
              AND e.is_active = true
          )
        )
      )
  )
);

DROP POLICY IF EXISTS salon_feed_staff_upload ON storage.objects;
CREATE POLICY salon_feed_staff_upload
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'salon-feed'
  AND public.is_current_user_active()
  AND EXISTS (
    SELECT 1
    FROM public.businesses AS b
    JOIN public.profiles AS me ON me.id = (SELECT auth.uid())
    WHERE b.id::text = (storage.foldername(objects.name))[1]
      AND b.status = 'active'
      AND (
        (b.owner_id = (SELECT auth.uid()) AND me.account_type = 'business_owner')
        OR EXISTS (
          SELECT 1
          FROM public.employees AS e
          WHERE e.business_id = b.id
            AND e.user_id = (SELECT auth.uid())
            AND e.is_active = true
            AND me.account_type = 'employee'
        )
      )
  )
);
