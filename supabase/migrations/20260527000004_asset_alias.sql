-- Alias único por org para referenciar assets no markdown como {{asset:logo}}
ALTER TABLE org_assets
  ADD COLUMN IF NOT EXISTS alias TEXT;

-- Garante que o alias é único dentro da mesma org
CREATE UNIQUE INDEX IF NOT EXISTS org_assets_org_alias_idx
  ON org_assets (organization_id, alias)
  WHERE alias IS NOT NULL;
