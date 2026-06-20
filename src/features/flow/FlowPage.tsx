import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchFlowBySlug } from "@/core/repositories/flows.repository";
import { fetchModulesBySlugs } from "@/core/repositories/modules.repository";
import { GenerationPanel } from "@/features/generation/GenerationPanel";

export function FlowPage() {
  const { slug } = useParams<{ slug: string }>();

  const { data: flow, isPending: flowPending } = useQuery({
    queryKey: ["flow", slug],
    queryFn: () => fetchFlowBySlug(slug!),
    enabled: !!slug,
  });

  const { data: modules } = useQuery({
    queryKey: ["flow-modules", flow?.moduleSlugs],
    queryFn: () => fetchModulesBySlugs(flow!.moduleSlugs),
    enabled: !!flow,
  });

  if (flowPending) {
    return <div className="p-6 text-sm text-light-onSurface/60">Carregando flow...</div>;
  }

  if (!flow) {
    return <div className="p-6 text-sm text-light-onSurface/60">Flow não encontrado.</div>;
  }

  return (
    <div className="p-6">
      <h1 className="mb-1 text-lg font-semibold text-light-onSurface dark:text-white">
        {flow.name}
      </h1>
      {flow.description && (
        <p className="mb-4 text-sm text-light-onSurface/60 dark:text-white/60">
          {flow.description}
        </p>
      )}

      <div className="mb-2 text-xs uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
        Contexto ({modules?.length ?? 0} módulos)
      </div>
      <ul className="mb-6 space-y-1">
        {modules?.map((mod) => (
          <li key={mod.id} className="text-sm text-light-onSurface/70 dark:text-white/70">
            {mod.name}
          </li>
        ))}
      </ul>

      <GenerationPanel
        flowSlug={flow.slug}
        flowName={flow.name}
        extraContext={modules?.map((m) => m.content).filter(Boolean).join("\n\n")}
      />
    </div>
  );
}
