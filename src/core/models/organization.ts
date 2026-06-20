export interface OrganizationModel {
  id: string;
  slug: string;
  name: string;
  enabledFeatures: string[];
}

export function organizationFromRow(row: {
  id: string;
  slug: string;
  name: string;
  config: { enabled_features?: string[] } | null;
}): OrganizationModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    enabledFeatures: row.config?.enabled_features ?? [],
  };
}

export function hasFeature(org: OrganizationModel, feature: string): boolean {
  return org.enabledFeatures.includes(feature);
}
