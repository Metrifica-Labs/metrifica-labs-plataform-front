import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { fetchModuleBySlug } from "@/core/repositories/modules.repository";
import { useAssetMap, resolveAssetRefs } from "@/core/asset-resolver/resolve-assets";
import { Markdown } from "@/shared/components/Markdown";

export function ModulePage() {
  const { slug } = useParams<{ slug: string }>();
  const { data: module, isPending } = useQuery({
    queryKey: ["module", slug],
    queryFn: () => fetchModuleBySlug(slug!),
    enabled: !!slug,
  });
  const { data: assetMap } = useAssetMap();

  if (isPending) {
    return <div className="p-6 text-sm text-light-onSurface/60">Carregando módulo...</div>;
  }

  if (!module) {
    return <div className="p-6 text-sm text-light-onSurface/60">Módulo não encontrado.</div>;
  }

  const content = assetMap
    ? resolveAssetRefs(module.content ?? "", assetMap)
    : module.content ?? "";

  return (
    <div className="p-6">
      <h1 className="mb-4 text-lg font-semibold text-light-onSurface dark:text-white">
        {module.name}
      </h1>
      <Markdown content={content} />
    </div>
  );
}
