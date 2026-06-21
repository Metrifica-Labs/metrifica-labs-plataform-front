-- ============================================================
-- Disparo do agendamento de posts do Instagram via pg_cron + pg_net
-- ============================================================
-- A cada minuto, chama a edge function `publish-instagram-post-due`, que
-- internamente usa o SUPABASE_SERVICE_ROLE_KEY (já injetado pelo runtime de
-- edge functions) para varrer `posts` com status='scheduled' e publicar os
-- que já venceram. Não há identidade de usuário na chamada do cron — a
-- função nunca aceita parâmetros do chamador, só lê o que já está no banco,
-- então expor o endpoint com a anon key (pública, já embutida no app web)
-- é seguro: o pior que um chamador externo conseguiria é antecipar em
-- minutos uma publicação que já estava agendada para acontecer.

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- project_url e anon_key não são segredos (o anon_key já vai embutido no
-- bundle do Flutter web); guardamos no Vault só para não hardcodear em
-- texto puro dentro do cron.schedule.
SELECT vault.create_secret(
  'https://dlhgictfgyhmkobzyrua.supabase.co',
  'instagram_publish_project_url'
) WHERE NOT EXISTS (
  SELECT 1 FROM vault.secrets WHERE name = 'instagram_publish_project_url'
);

SELECT vault.create_secret(
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRsaGdpY3RmZ3lobWtvYnp5cnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk0MTAwODAsImV4cCI6MjA5NDk4NjA4MH0.vDFAdnZ0ftBe3y6-wxE9JtEZGmzT19rlS5S9pCQ2QCs',
  'instagram_publish_anon_key'
) WHERE NOT EXISTS (
  SELECT 1 FROM vault.secrets WHERE name = 'instagram_publish_anon_key'
);

SELECT cron.schedule(
  'publish-instagram-post-due',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'instagram_publish_project_url')
           || '/functions/v1/publish-instagram-post-due',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'instagram_publish_anon_key'),
      'Authorization', 'Bearer ' || (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'instagram_publish_anon_key')
    ),
    body := '{}'::jsonb
  );
  $$
);
