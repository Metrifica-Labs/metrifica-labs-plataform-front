import { Construction } from "lucide-react";
import { EmptyState } from "@/shared/components/ui/Card";

export function StubPage({ title }: { title: string }) {
  return (
    <div className="flex h-full items-center justify-center">
      <EmptyState icon={<Construction size={20} />} title={title} description="Em construção" />
    </div>
  );
}
