-- ============================================================
-- Ativa o módulo "Audio Visualizer" para a org Metrifica Labs
-- ============================================================

UPDATE organizations
SET config = jsonb_set(
  COALESCE(config, '{}'::jsonb),
  '{enabled_features}',
  (
    SELECT to_jsonb(array(
      SELECT DISTINCT e
      FROM unnest(
        COALESCE(
          ARRAY(SELECT jsonb_array_elements_text(config->'enabled_features')),
          ARRAY[]::text[]
        ) || ARRAY['audio_visualizer']
      ) AS e
    ))
  )
)
WHERE slug = 'metrifica';
