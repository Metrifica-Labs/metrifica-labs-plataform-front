-- ============================================================
-- Multi-tenancy: Organizations + RLS
-- ============================================================

-- 1. Organizations

CREATE TABLE IF NOT EXISTS organizations (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug       TEXT        UNIQUE NOT NULL,
  name       TEXT        NOT NULL,
  -- enabled_features: lista de features ativas p/ essa empresa
  -- ex: ["squad", "generation", "flows", "career"]
  config     JSONB       NOT NULL DEFAULT '{"enabled_features": []}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Members: quem tem acesso a qual empresa

CREATE TABLE IF NOT EXISTS organization_members (
  user_id         UUID REFERENCES auth.users(id)  ON DELETE CASCADE,
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  role            TEXT NOT NULL DEFAULT 'member',  -- 'owner' | 'admin' | 'member'
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, organization_id)
);

-- 3. Controle de modules por org (qual module_slug está habilitado)

CREATE TABLE IF NOT EXISTS organization_modules (
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  module_slug     TEXT        NOT NULL,
  enabled         BOOLEAN     NOT NULL DEFAULT true,
  PRIMARY KEY (organization_id, module_slug)
);

-- 4. Controle de flows por org

CREATE TABLE IF NOT EXISTS organization_flows (
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  flow_slug       TEXT        NOT NULL,
  enabled         BOOLEAN     NOT NULL DEFAULT true,
  PRIMARY KEY (organization_id, flow_slug)
);

-- 5. Add organization_id to generation_history

ALTER TABLE generation_history
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);

-- 6. Add organization_id to squad_runs

ALTER TABLE squad_runs
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);

-- ============================================================
-- RLS
-- ============================================================

-- Helper: retorna os org IDs do usuário atual (public schema)
CREATE OR REPLACE FUNCTION public.user_organization_ids()
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT organization_id FROM organization_members WHERE user_id = auth.uid();
$$;

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_flows ENABLE ROW LEVEL SECURITY;
ALTER TABLE generation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE squad_runs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "members can read own orgs"
    ON organizations FOR SELECT
    USING (id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "members can read org membership"
    ON organization_members FOR SELECT
    USING (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "members can read org modules"
    ON organization_modules FOR SELECT
    USING (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "members can read org flows"
    ON organization_flows FOR SELECT
    USING (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "org members can manage generation history"
    ON generation_history FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "org members can manage squad runs"
    ON squad_runs FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- Seed: Empresas + Membro
-- ============================================================

DO $$
DECLARE
  metrifica_id UUID;
  speake_id    UUID;
  owner_id     UUID;
BEGIN

  -- Orgs
  INSERT INTO organizations (slug, name, config)
  VALUES (
    'metrifica',
    'Metrifica Labs',
    '{"enabled_features": ["squad", "generation", "flows", "career"]}'::jsonb
  )
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO metrifica_id;

  IF metrifica_id IS NULL THEN
    SELECT id INTO metrifica_id FROM organizations WHERE slug = 'metrifica';
  END IF;

  INSERT INTO organizations (slug, name, config)
  VALUES (
    'speake',
    'Speake Brasil',
    '{"enabled_features": ["generation", "flows", "career"]}'::jsonb
  )
  ON CONFLICT (slug) DO NOTHING
  RETURNING id INTO speake_id;

  IF speake_id IS NULL THEN
    SELECT id INTO speake_id FROM organizations WHERE slug = 'speake';
  END IF;

  -- Owner
  SELECT id INTO owner_id FROM auth.users WHERE email = 'speakebrasil@gmail.com';

  IF owner_id IS NOT NULL THEN
    INSERT INTO organization_members (user_id, organization_id, role)
    VALUES (owner_id, metrifica_id, 'owner')
    ON CONFLICT (user_id, organization_id) DO NOTHING;

    INSERT INTO organization_members (user_id, organization_id, role)
    VALUES (owner_id, speake_id, 'owner')
    ON CONFLICT (user_id, organization_id) DO NOTHING;
  END IF;

  -- Módulos habilitados: metrifica → todos
  INSERT INTO organization_modules (organization_id, module_slug)
  SELECT metrifica_id, slug FROM modules
  ON CONFLICT DO NOTHING;

  -- Módulos habilitados: speake → todos (squad é feature, não module)
  INSERT INTO organization_modules (organization_id, module_slug)
  SELECT speake_id, slug FROM modules
  ON CONFLICT DO NOTHING;

  -- Flows habilitados: metrifica → todos
  INSERT INTO organization_flows (organization_id, flow_slug)
  SELECT metrifica_id, slug FROM flows
  ON CONFLICT DO NOTHING;

  -- Flows habilitados: speake → todos os flows existentes
  INSERT INTO organization_flows (organization_id, flow_slug)
  SELECT speake_id, slug FROM flows
  ON CONFLICT DO NOTHING;

END $$;
