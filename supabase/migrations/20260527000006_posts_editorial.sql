CREATE TABLE IF NOT EXISTS posts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  flow_slug       TEXT        NOT NULL,
  content         TEXT        NOT NULL,
  image_url       TEXT,
  status          TEXT        NOT NULL DEFAULT 'draft'
                               CHECK (status IN ('draft','approved','scheduled','published')),
  pillar          TEXT,
  scheduled_at    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "org members can manage posts"
    ON posts FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER posts_updated_at
  BEFORE UPDATE ON posts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE INDEX IF NOT EXISTS posts_org_status_created
  ON posts (organization_id, status, created_at DESC);
