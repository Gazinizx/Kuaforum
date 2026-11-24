# Kuaförüm Supabase backend

Project ref: `zhvfudtdnvgsqywojjrz` (Frankfurt, eu-central-1).

The schema is isolated from Berberim. It includes the appointment baseline plus salon feed, paid Discover eligibility, conversations, messages, Storage and Realtime. Every exposed table uses RLS. The mobile client only uses the publishable key; never expose service-role credentials.

The first administrator must be promoted after creating the admin Auth account by setting `profiles.is_admin = true` for that user's Auth ID in the Supabase SQL editor.

## Discover access
- `discover_paid`: admin-managed flag indicating the business has paid for Discover placement.
- `discover_enabled`: admin-managed publication switch.
- A post enters Discover only when both flags are true and the business is active.
- The Followed feed remains restricted to customers belonging to the business.
