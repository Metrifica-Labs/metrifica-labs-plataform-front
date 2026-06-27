import { useQuery } from "@tanstack/react-query";
import { listMotionRunsByOrg } from "./motion-run.repository";

export const motionRunsQueryKey = (orgId: string | null) =>
  ["motion-runs", orgId] as const;

/**
 * Histórico de runs de motion da organização ativa (Fase 4). Espelha o padrão
 * de `useUserOrgs`/`useOrgEnabledFlowSlugs`: só dispara com `orgId` definido.
 */
export function useMotionRuns(orgId: string | null) {
  return useQuery({
    queryKey: motionRunsQueryKey(orgId),
    queryFn: () => listMotionRunsByOrg(orgId as string),
    enabled: !!orgId,
  });
}
