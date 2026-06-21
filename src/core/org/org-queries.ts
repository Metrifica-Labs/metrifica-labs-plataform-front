import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/core/supabase/client";
import { organizationFromRow, type OrganizationModel } from "@/core/models/organization";
import { useAuthStore } from "@/core/auth/auth-store";

async function fetchUserOrgs(): Promise<OrganizationModel[]> {
  const { data, error } = await supabase
    .from("organization_members")
    .select("organizations(id, slug, name, config)")
    .order("created_at", { referencedTable: "organizations" });
  if (error) throw error;
  return (data ?? [])
    .map((row) => row.organizations)
    .filter((org): org is NonNullable<typeof org> => org != null)
    .map((org) => organizationFromRow(org as never));
}

export function useUserOrgs() {
  const userId = useAuthStore((s) => s.user?.id);
  return useQuery({
    queryKey: ["user-orgs", userId],
    queryFn: fetchUserOrgs,
    enabled: !!userId,
  });
}

export function useOrgEnabledFlowSlugs(orgId: string | null) {
  return useQuery({
    queryKey: ["org-enabled-flow-slugs", orgId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("organization_flows")
        .select("flow_slug")
        .eq("organization_id", orgId);
      if (error) throw error;
      return data.map((row) => row.flow_slug as string);
    },
    enabled: !!orgId,
  });
}

export function useOrgEnabledModuleSlugs(orgId: string | null) {
  return useQuery({
    queryKey: ["org-enabled-module-slugs", orgId],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("organization_modules")
        .select("module_slug")
        .eq("organization_id", orgId);
      if (error) throw error;
      return data.map((row) => row.module_slug as string);
    },
    enabled: !!orgId,
  });
}
