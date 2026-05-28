-- ============================================================
-- Org Assets: Storage bucket + tabela de metadados
-- ============================================================

-- 1. Bucket privado para assets das orgs
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'org-assets',
  'org-assets',
  false,
  10485760, -- 10 MB
  ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS no storage: caminho = org-assets/{organization_id}/{filename}
CREATE POLICY "org members can upload assets"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'org-assets'
    AND (storage.foldername(name))[1] IN (
      SELECT organization_id::text
        FROM organization_members
       WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "org members can read assets"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'org-assets'
    AND (storage.foldername(name))[1] IN (
      SELECT organization_id::text
        FROM organization_members
       WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "org members can delete assets"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'org-assets'
    AND (storage.foldername(name))[1] IN (
      SELECT organization_id::text
        FROM organization_members
       WHERE user_id = auth.uid()
    )
  );

-- 3. Tabela de metadados dos assets
CREATE TABLE IF NOT EXISTS org_assets (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID        NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name            TEXT        NOT NULL,
  storage_path    TEXT        NOT NULL,  -- caminho no bucket: {org_id}/{filename}
  public_url      TEXT,                  -- URL pública gerada após upload
  asset_type      TEXT        NOT NULL DEFAULT 'image',  -- 'logo', 'brand', 'reference', 'image'
  created_by      UUID        REFERENCES auth.users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE org_assets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "org members can manage assets"
    ON org_assets FOR ALL
    USING (organization_id IN (SELECT public.user_organization_ids()))
    WITH CHECK (organization_id IN (SELECT public.user_organization_ids()));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
