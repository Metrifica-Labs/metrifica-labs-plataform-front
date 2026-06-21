import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { Layers } from "lucide-react";
import { fetchFlowBySlug } from "@/core/repositories/flows.repository";
import { fetchModulesBySlugs } from "@/core/repositories/modules.repository";
import { GenerationPanel } from "@/features/generation/GenerationPanel";
import { PageHeader } from "@/shared/components/ui/Card";

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
    <div className="mx-auto max-w-3xl p-6">
      <PageHeader eyebrow="Flow" title={flow.name} subtitle={flow.description} />

      <div className="mb-6 flex items-center gap-1.5 font-mono text-[11px] uppercase tracking-wide text-light-onSurface/35 dark:text-white/30">
        <Layers size={12} />
        Contexto · {modules?.length ?? 0} módulo(s)
      </div>
      {modules && modules.length > 0 && (
        <ul className="mb-6 flex flex-wrap gap-1.5">
          {modules.map((mod) => (
            <li
              key={mod.id}
              className="rounded-full border border-light-border px-2.5 py-1 text-[12px] text-light-onSurface/65 dark:border-dark-border dark:text-white/60"
            >
              {mod.name}
            </li>
          ))}
        </ul>
      )}

      <GenerationPanel
        flowSlug={flow.slug}
        flowName={flow.name}
        extraContext={modules?.map((m) => m.content).filter(Boolean).join("\n\n")}
      />
    </div>
  );
}
