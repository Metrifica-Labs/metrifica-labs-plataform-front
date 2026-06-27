-- ============================================================
-- Nova org: Oliveira (cópia completa do perfil Metrifica Labs)
-- Copia config, módulos e flows diretamente da org 'metrifica'.
-- ============================================================

DO $$
DECLARE
  metrifica_id UUID;
  oliveira_id  UUID;
  metrifica_config JSONB;
  org RECORD;
  u   RECORD;
BEGIN

  -- 0. Pega a org de referência (Metrifica Labs)
  SELECT id, config INTO metrifica_id, metrifica_config
    FROM organizations
   WHERE slug = 'metrifica';

  IF metrifica_id IS NULL THEN
    RAISE EXCEPTION 'Org metrifica não encontrada — nada para copiar.';
  END IF;

  -- 1. Cria a org Oliveira com a MESMA config da metrifica
  INSERT INTO organizations (slug, name, invite_code, config)
  VALUES (
    'oliveira',
    'Oliveira',
    'OLIVEIRA-2025',
    metrifica_config
  )
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO oliveira_id;

  IF oliveira_id IS NULL THEN
    SELECT id INTO oliveira_id FROM organizations WHERE slug = 'oliveira';
  END IF;

  -- 2. Copia os módulos habilitados da metrifica
  INSERT INTO organization_modules (organization_id, module_slug, enabled)
  SELECT oliveira_id, module_slug, enabled
    FROM organization_modules
   WHERE organization_id = metrifica_id
  ON CONFLICT DO NOTHING;

  -- 3. Copia os flows habilitados da metrifica
  INSERT INTO organization_flows (organization_id, flow_slug, enabled)
  SELECT oliveira_id, flow_slug, enabled
    FROM organization_flows
   WHERE organization_id = metrifica_id
  ON CONFLICT DO NOTHING;

  -- 4. Adiciona todos os users existentes na nova org (para rodar localmente)
  FOR u IN SELECT id FROM auth.users LOOP
    INSERT INTO organization_members (user_id, organization_id, role)
    VALUES (u.id, oliveira_id, 'member')
    ON CONFLICT (user_id, organization_id) DO NOTHING;
  END LOOP;

END $$;
