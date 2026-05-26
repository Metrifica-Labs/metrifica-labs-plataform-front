-- ============================================================
-- Invite codes por empresa
-- ============================================================

-- 1. Coluna invite_code na tabela organizations
ALTER TABLE organizations
  ADD COLUMN IF NOT EXISTS invite_code TEXT UNIQUE;

-- 2. Seed dos códigos (idempotente)
UPDATE organizations SET invite_code = 'METRIFICA-2025' WHERE slug = 'metrifica';
UPDATE organizations SET invite_code = 'SPEAKE-2025'    WHERE slug = 'speake';

-- 3. Função SECURITY DEFINER: valida o código e insere o membro
--    Roda como dono da função (bypassa RLS), nunca expõe o código ao cliente.
CREATE OR REPLACE FUNCTION public.join_org_by_code(p_invite_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_org_id   UUID;
  v_org_name TEXT;
BEGIN
  SELECT id, name
    INTO v_org_id, v_org_name
    FROM organizations
   WHERE invite_code = p_invite_code;

  IF v_org_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Código de convite inválido.');
  END IF;

  INSERT INTO organization_members (user_id, organization_id, role)
  VALUES (auth.uid(), v_org_id, 'member')
  ON CONFLICT (user_id, organization_id) DO NOTHING;

  RETURN jsonb_build_object('ok', true, 'org_name', v_org_name);
END;
$$;

-- 4. Remove policies que não são mais necessárias
--    (orgs não precisam mais ser públicas, join é via função)
DROP POLICY IF EXISTS "public can read org names" ON organizations;
DROP POLICY IF EXISTS "users can join orgs" ON organization_members;
