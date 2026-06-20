import { useQuery } from "@tanstack/react-query";
import { fetchOrgAssets } from "@/core/repositories/org-assets.repository";
import { useOrgStore } from "@/core/org/org-store";

const ASSET_REF_PATTERN = /\{\{asset:([a-zA-Z0-9_-]+)\}\}/g;

export function useAssetMap() {
  const orgId = useOrgStore((s) => s.activeOrgId);
  return useQuery({
    queryKey: ["org-assets", orgId],
    queryFn: async () => {
      const assets = await fetchOrgAssets(orgId!);
      const map = new Map<string, string>();
      for (const asset of assets) {
        if (asset.alias && asset.publicUrl) {
          map.set(asset.alias, asset.publicUrl);
        }
      }
      return map;
    },
    enabled: !!orgId,
  });
}

export function resolveAssetRefs(content: string, assetMap: Map<string, string>): string {
  return content.replace(ASSET_REF_PATTERN, (match, alias) => assetMap.get(alias) ?? match);
}
