-- ============================================================
-- Motion Video Runs: persistência dos roteiros gerados (MotionSpec)
-- Fase 4 do Motion Video Generator.
-- ============================================================

CREATE TABLE IF NOT EXISTS motion_video_runs (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  created_by      UUID        REFERENCES auth.users(id),
  status          TEXT        NOT NULL DEFAULT 'completed',  -- 'completed' | 'failed'
  input           TEXT        NOT NULL,
  format          TEXT        NOT NULL DEFAULT 'reel',
  motion_spec     JSONB,                                     -- MotionSpec validado (Zod no cliente)
  spec_version    INTEGER     NOT NULL DEFAULT 1,
  video_url       TEXT,                                      -- preenchido só no export de produção (Fase 8)
  error           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS motion_video_runs_org_created_idx
  ON motion_video_runs (organization_id, created_at DESC);

-- updated_at automático
CREATE OR REPLACE FUNCTION public.touch_motion_video_runs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS motion_video_runs_set_updated_at ON motion_video_runs;
CREATE TRIGGER motion_video_runs_set_updated_at
  BEFORE UPDATE ON motion_video_runs
  FOR EACH ROW EXECUTE FUNCTION public.touch_motion_video_runs_updated_at();

-- RLS: membros da org gerenciam os runs da própria org
ALTER TABLE motion_video_runs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "org members can manage motion runs"
    ON motion_video_runs FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
