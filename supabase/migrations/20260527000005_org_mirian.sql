-- ============================================================
-- Nova org: Mirian + todos os users em todas as orgs
-- ============================================================

DO $$
DECLARE
  mirian_id UUID;
  org       RECORD;
  u         RECORD;
BEGIN

  -- 1. Cria a org Mirian
  INSERT INTO organizations (slug, name, invite_code, config)
  VALUES (
    'mirian',
    'Mirian',
    'MIRIAN-2025',
    '{"enabled_features": ["squad", "generation", "flows", "career"]}'::jsonb
  )
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO mirian_id;

  IF mirian_id IS NULL THEN
    SELECT id INTO mirian_id FROM organizations WHERE slug = 'mirian';
  END IF;

  -- Habilita todos os módulos para a nova org
  INSERT INTO organization_modules (organization_id, module_slug)
  SELECT mirian_id, slug FROM modules
  ON CONFLICT DO NOTHING;

  -- Habilita todos os flows para a nova org
  INSERT INTO organization_flows (organization_id, flow_slug)
  SELECT mirian_id, slug FROM flows
  ON CONFLICT DO NOTHING;

  -- 2. Adiciona todos os users em todas as orgs
  FOR org IN SELECT id FROM organizations LOOP
    FOR u IN SELECT id FROM auth.users LOOP
      INSERT INTO organization_members (user_id, organization_id, role)
      VALUES (u.id, org.id, 'member')
      ON CONFLICT (user_id, organization_id) DO NOTHING;
    END LOOP;
  END LOOP;

END $$;
