UPDATE organizations
SET config = jsonb_set(
  COALESCE(config, '{}'::jsonb),
  '{enabled_features}',
  '["squad", "generation", "flows", "career", "editorial"]'::jsonb
)
WHERE slug = 'metrifica';
