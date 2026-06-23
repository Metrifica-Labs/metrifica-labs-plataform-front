-- ============================================================
-- Instagram Connections: bucket de mídia + tabela de conexões
-- ============================================================

-- 1. Bucket privado para imagens de publicação
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'instagram-publish-media',
  'instagram-publish-media',
  false,
  52428800, -- 50 MB
  ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. RLS do bucket: caminho = {user_id}/{timestamp}/slide-N.png
CREATE POLICY "user can upload instagram media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'instagram-publish-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "user can read instagram media"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'instagram-publish-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "user can delete instagram media"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'instagram-publish-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. Tabela de conexões Instagram por usuário
CREATE TABLE IF NOT EXISTS instagram_connections (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status              TEXT        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'active', 'error')),
  composio_entity_id  TEXT,
  instagram_handle    TEXT,
  error_message       TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id)
);

ALTER TABLE instagram_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user can manage own connection"
  ON instagram_connections FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4. Tabela de posts agendados
CREATE TABLE IF NOT EXISTS instagram_scheduled_posts (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  storage_paths       TEXT[]      NOT NULL,
  scheduled_at        TIMESTAMPTZ NOT NULL,
  status              TEXT        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending', 'published', 'failed', 'cancelled')),
  error_message       TEXT,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE instagram_scheduled_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user can manage own scheduled posts"
  ON instagram_scheduled_posts FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
