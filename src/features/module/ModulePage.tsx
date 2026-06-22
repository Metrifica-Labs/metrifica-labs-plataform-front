import { useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { BookOpen } from "lucide-react";
import { fetchModuleBySlug } from "@/core/repositories/modules.repository";
import { useAssetMap, resolveAssetRefs } from "@/core/asset-resolver/resolve-assets";
import { Markdown } from "@/shared/components/Markdown";
import { PageHeader, EmptyState } from "@/shared/components/ui/Card";
import { Skeleton } from "@/shared/components/ui/Skeleton";

export function ModulePage() {
  const { slug } = useParams<{ slug: string }>();
  const { data: module, isPending } = useQuery({
    queryKey: ["module", slug],
    queryFn: () => fetchModuleBySlug(slug!),
    enabled: !!slug,
  });
  const { data: assetMap } = useAssetMap();

  if (isPending) {
    return (
      <div className="p-6">
        <Skeleton className="mb-4 h-7 w-1/3" />
        <Skeleton className="mb-2 h-4 w-full" />
        <Skeleton className="mb-2 h-4 w-5/6" />
        <Skeleton className="h-4 w-2/3" />
      </div>
    );
  }

  if (!module) {
    return (
      <div className="p-6">
        <EmptyState
          icon={<BookOpen size={20} />}
          title="Módulo não encontrado"
          description="O conteúdo solicitado não existe ou foi removido."
        />
      </div>
    );
  }

  const content = assetMap
    ? resolveAssetRefs(module.content ?? "", assetMap)
    : module.content ?? "";

  return (
    <div className="p-6">
      <PageHeader title={module.name} />
      <Markdown content={content} />
    </div>
  );
}
