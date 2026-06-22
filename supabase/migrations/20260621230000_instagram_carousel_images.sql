-- ============================================================
-- Suporte a carrossel (múltiplos slides) na publicação do Instagram
-- ============================================================
-- image_url continua sendo a capa/primeira imagem (usada pelo editorial
-- genérico). image_urls guarda a lista completa, na ordem dos slides, usada
-- pelo publish do Instagram para montar o carrossel quando houver mais de
-- uma imagem.

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS image_urls TEXT[];
