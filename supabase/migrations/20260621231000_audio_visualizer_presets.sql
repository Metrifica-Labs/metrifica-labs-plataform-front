-- ============================================================
-- Audio Visualizer: presets de configuracao persistidos por org
-- (antes eram salvos so em localStorage do navegador)
-- ============================================================

CREATE TABLE IF NOT EXISTS audio_visualizer_presets (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT        NOT NULL,
  config          JSONB       NOT NULL DEFAULT '{}'::jsonb,
  created_by      UUID        REFERENCES auth.users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (organization_id, name)
);

ALTER TABLE audio_visualizer_presets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "org members can manage audio visualizer presets"
    ON audio_visualizer_presets FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
