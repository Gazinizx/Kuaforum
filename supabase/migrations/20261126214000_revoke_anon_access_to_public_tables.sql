-- Kuaförüm requires authentication before reading or writing application data.
-- Keep the anon role away from all public-schema tables and views; authenticated
-- access remains governed by the existing per-table RLS policies.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon;