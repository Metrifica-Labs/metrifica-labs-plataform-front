import { useQuery } from "@tanstack/react-query";
import { fetchFlows } from "@/core/repositories/flows.repository";
import { fetchModules } from "@/core/repositories/modules.repository";
import { fetchSquads } from "@/core/repositories/squads.repository";
import { useOrgStore } from "@/core/org/org-store";
import {
  useOrgEnabledFlowSlugs,
  useOrgEnabledModuleSlugs,
} from "@/core/org/org-queries";

export function useSidebarNav() {
  const activeOrgId = useOrgStore((s) => s.activeOrgId);

  const flowsQuery = useQuery({ queryKey: ["flows"], queryFn: fetchFlows });
  const modulesQuery = useQuery({ queryKey: ["modules"], queryFn: fetchModules });
  const squadsQuery = useQuery({ queryKey: ["squads"], queryFn: fetchSquads });
  const enabledFlowSlugs = useOrgEnabledFlowSlugs(activeOrgId);
  const enabledModuleSlugs = useOrgEnabledModuleSlugs(activeOrgId);

  const flows = (flowsQuery.data ?? []).filter(
    (f) => !enabledFlowSlugs.data || enabledFlowSlugs.data.includes(f.slug)
  );
  const modules = (modulesQuery.data ?? []).filter(
    (m) => !enabledModuleSlugs.data || enabledModuleSlugs.data.includes(m.slug)
  );
  const squads = squadsQuery.data ?? [];

  return { flows, modules, squads };
}
