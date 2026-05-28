-- ============================================================
-- 1. Promover tekboxs e joaovitor a admin na org metrifica
-- ============================================================

UPDATE organization_members
SET role = 'admin'
WHERE organization_id = (SELECT id FROM organizations WHERE slug = 'metrifica')
  AND user_id IN (
    SELECT id FROM auth.users
    WHERE email IN ('tekboxs@gmail.com', 'joaovitorocs@gmail.com')
  );

-- ============================================================
-- 2. RLS generation_history: somente admin/owner pode deletar
-- ============================================================

-- Helper: verifica se o user atual é admin/owner na org do registro
CREATE OR REPLACE FUNCTION public.user_is_org_admin(org_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM organization_members
    WHERE user_id = auth.uid()
      AND organization_id = org_id
      AND role IN ('admin', 'owner')
  );
$$;

-- Remove a policy FOR ALL existente
DROP POLICY IF EXISTS "org members can manage generation history" ON generation_history;

-- SELECT + INSERT: qualquer membro
DO $$ BEGIN
  CREATE POLICY "org members can read history"
    ON generation_history FOR SELECT
    USING (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "org members can insert history"
    ON generation_history FOR INSERT
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- DELETE: somente admin/owner
DO $$ BEGIN
  CREATE POLICY "org admins can delete history"
    ON generation_history FOR DELETE
    USING (
      organization_id IN (SELECT public.user_organization_ids())
      AND public.user_is_org_admin(organization_id)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
