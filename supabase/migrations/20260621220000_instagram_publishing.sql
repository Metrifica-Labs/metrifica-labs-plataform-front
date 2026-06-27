-- ============================================================
-- Instagram Publishing via Composio: conexão por usuário + posts
-- ============================================================
-- IMPORTANTE: a conta Instagram conectada é pessoal, não da organização.
-- instagram_connections é chaveada por user_id (auth.uid()) e a RLS aqui
-- propositalmente NÃO segue o padrão "org members" usado em outras tabelas
-- deste arquivo (org_assets, posts) — um usuário nunca pode ler, atualizar
-- ou usar a conexão Instagram de outro usuário, mesmo na mesma organização.

CREATE TABLE IF NOT EXISTS instagram_connections (
  id                          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                     UUID        NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  composio_connected_account_id TEXT,
  ig_user_id                 TEXT,
  ig_username                 TEXT,
  status                      TEXT        NOT NULL DEFAULT 'pending'
                                           CHECK (status IN ('pending','active','disabled','error')),
  status_reason               TEXT,
  created_at                  TIMESTAMPTZ DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE instagram_connections ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "user manages own instagram connection"
    ON instagram_connections FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TRIGGER instagram_connections_updated_at
  BEFORE UPDATE ON instagram_connections
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── Colunas extras em posts para publicação no Instagram ──────────────────
ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS ig_user_id            TEXT,
  ADD COLUMN IF NOT EXISTS composio_connection_id TEXT,
  ADD COLUMN IF NOT EXISTS composio_container_id  TEXT,
  ADD COLUMN IF NOT EXISTS publish_error          TEXT,
  ADD COLUMN IF NOT EXISTS created_by             UUID REFERENCES auth.users(id);

-- ── Bucket público para a imagem que o Instagram precisa buscar sem auth ──
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'instagram-publish-media',
  'instagram-publish-media',
  true,
  8388608, -- 8 MB (limite do Instagram para imagens)
  ARRAY['image/png', 'image/jpeg']
)
ON CONFLICT (id) DO NOTHING;

-- Caminho dos objetos: instagram-publish-media/{user_id}/{filename}
-- Só o próprio usuário pode subir/remover na sua pasta; leitura é pública
-- (o bucket inteiro já é público, mas mantemos policies explícitas por clareza).
CREATE POLICY "user uploads own instagram media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'instagram-publish-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "user deletes own instagram media"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'instagram-publish-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "public can read instagram media"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'instagram-publish-media');
