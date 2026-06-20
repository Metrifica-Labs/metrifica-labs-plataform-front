import { supabase } from "@/core/supabase/client";
import { orgAssetFromRow, type OrgAssetModel } from "@/core/models/org-asset";

export async function fetchOrgAssets(orgId: string): Promise<OrgAssetModel[]> {
  const { data, error } = await supabase
    .from("org_assets")
    .select("*")
    .eq("organization_id", orgId)
    .order("created_at");
  if (error) throw error;
  return data.map(orgAssetFromRow);
}
