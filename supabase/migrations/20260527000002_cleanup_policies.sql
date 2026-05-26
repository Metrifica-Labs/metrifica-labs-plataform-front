-- Remove policies substituídas pelo sistema de invite codes
DROP POLICY IF EXISTS "public can read org names" ON organizations;
DROP POLICY IF EXISTS "users can join orgs" ON organization_members;
