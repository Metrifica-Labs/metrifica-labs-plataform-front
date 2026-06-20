export interface OrgAssetModel {
  id: string;
  organizationId: string;
  name: string;
  storagePath: string;
  publicUrl: string | null;
  assetType: string;
  alias: string | null;
  createdAt: string;
}

export function orgAssetFromRow(row: {
  id: string;
  organization_id: string;
  name: string;
  storage_path: string;
  public_url: string | null;
  asset_type: string;
  alias: string | null;
  created_at: string;
}): OrgAssetModel {
  return {
    id: row.id,
    organizationId: row.organization_id,
    name: row.name,
    storagePath: row.storage_path,
    publicUrl: row.public_url,
    assetType: row.asset_type,
    alias: row.alias,
    createdAt: row.created_at,
  };
}
