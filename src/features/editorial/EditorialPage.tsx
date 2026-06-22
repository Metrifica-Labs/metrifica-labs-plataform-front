import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { FileText } from "lucide-react";
import { useOrgStore } from "@/core/org/org-store";
import {
  fetchPosts,
  fetchPillarStats,
  updatePostStatus,
  deletePost,
} from "@/features/editorial/posts.repository";
import {
  POST_STATUS_LABELS,
  POST_STATUS_COLORS,
  type PostModel,
  type PostStatus,
} from "@/core/models/post";
import { Markdown } from "@/shared/components/Markdown";
import { PageHeader, Badge, EmptyState } from "@/shared/components/ui/Card";
import { Skeleton } from "@/shared/components/ui/Skeleton";
import { useToast } from "@/shared/hooks/useToast";

const ALL_STATUSES: PostStatus[] = ["draft", "approved", "scheduled", "published"];

export function EditorialPage() {
  const orgId = useOrgStore((s) => s.activeOrgId);
  const [filter, setFilter] = useState<PostStatus | null>(null);

  const postsQuery = useQuery({
    queryKey: ["posts", orgId],
    queryFn: () => fetchPosts(orgId!),
    enabled: !!orgId,
  });

  const statsQuery = useQuery({
    queryKey: ["posts-pillar-stats", orgId],
    queryFn: () => fetchPillarStats(orgId!),
    enabled: !!orgId,
  });

  const posts = postsQuery.data ?? [];
  const filtered = filter ? posts.filter((p) => p.status === filter) : posts;

  return (
    <div className="mx-auto max-w-3xl p-8">
      <PageHeader title="Editorial" subtitle="Posts gerados — pipeline de publicação" />

      {statsQuery.data && Object.keys(statsQuery.data).length > 0 && (
        <div className="mb-5 rounded-xl border border-light-border/60 bg-light-onSurface/[0.03] p-4 dark:border-dark-border/60 dark:bg-white/[0.03]">
          <p className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
            Pilares — últimos 30 dias
          </p>
          <div className="flex flex-wrap gap-2">
            {Object.entries(statsQuery.data).map(([pillar, count]) => (
              <Badge key={pillar} color="#5B5FEF">
                {pillar} · {count}
              </Badge>
            ))}
          </div>
        </div>
      )}

      <div className="mb-4 flex gap-2 overflow-x-auto">
        {[null, ...ALL_STATUSES].map((s) => (
          <button
            key={s ?? "all"}
            onClick={() => setFilter(s)}
            className={`whitespace-nowrap rounded-full border px-3.5 py-1.5 text-xs font-medium transition-colors ${
              filter === s
                ? "border-primary/40 bg-primary/[0.12] text-primary"
                : "border-light-onSurface/10 bg-light-onSurface/[0.04] text-light-onSurface/50 dark:border-white/10 dark:bg-white/[0.04] dark:text-white/50"
            }`}
          >
            {s ? POST_STATUS_LABELS[s] : "Todos"}
          </button>
        ))}
      </div>

      {postsQuery.isPending && (
        <div className="space-y-2">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
        </div>
      )}

      {!postsQuery.isPending && filtered.length === 0 && (
        <EmptyState
          icon={<FileText size={20} />}
          title="Nenhum post encontrado"
          description="Posts gerados pelo fluxo de criação aparecem aqui."
        />
      )}

      <div className="space-y-2">
        {filtered.map((post) => (
          <PostCard key={post.id} post={post} orgId={orgId!} />
        ))}
      </div>
    </div>
  );
}

function PostCard({ post, orgId }: { post: PostModel; orgId: string }) {
  const [expanded, setExpanded] = useState(false);
  const queryClient = useQueryClient();
  const toast = useToast();

  function invalidate() {
    queryClient.invalidateQueries({ queryKey: ["posts", orgId] });
    queryClient.invalidateQueries({ queryKey: ["posts-pillar-stats", orgId] });
  }

  const changeStatus = useMutation({
    mutationFn: ({ status, scheduledAt }: { status: PostStatus; scheduledAt?: Date }) =>
      updatePostStatus(post.id, status, scheduledAt),
    onSuccess: (_data, variables) => {
      invalidate();
      toast.success(`Post atualizado para "${POST_STATUS_LABELS[variables.status]}".`);
    },
    onError: () => {
      toast.error("Não foi possível atualizar o status do post.");
    },
  });

  const remove = useMutation({
    mutationFn: () => deletePost(post.id),
    onSuccess: () => {
      invalidate();
      toast.success("Post excluído.");
    },
    onError: () => {
      toast.error("Não foi possível excluir o post.");
    },
  });

  const statusColor = POST_STATUS_COLORS[post.status];
  const preview = post.content.length > 100 ? `${post.content.slice(0, 100)}...` : post.content;

  return (
    <div className="overflow-hidden rounded-xl border border-light-border/50 bg-light-onSurface/[0.02] dark:border-dark-border/50 dark:bg-white/[0.02]">
      <button
        onClick={() => setExpanded((e) => !e)}
        className="flex w-full items-center gap-2.5 px-4 py-3 text-left"
      >
        <Badge color={statusColor}>{POST_STATUS_LABELS[post.status]}</Badge>
        {post.pillar && (
          <span className="rounded-full bg-light-onSurface/5 px-2 py-0.5 text-[10px] text-light-onSurface/50 dark:bg-white/5 dark:text-white/50">
            Pilar {post.pillar}
          </span>
        )}
        <span className="flex-1 truncate text-xs text-light-onSurface/60 dark:text-white/60">
          {preview}
        </span>
        <span className="text-[11px] text-light-onSurface/30 dark:text-white/30">
          {new Date(post.createdAt).toLocaleDateString("pt-BR")}
        </span>
      </button>

      {expanded && (
        <div className="border-t border-light-border/40 p-4 dark:border-dark-border/40">
          {post.imageUrl && (
            <img src={post.imageUrl} className="mb-4 h-48 w-full rounded-lg object-cover" />
          )}
          <Markdown content={post.content} />
          <div className="mt-4 flex items-center gap-2">
            {post.status === "draft" && (
              <ActionButton
                label="Aprovar"
                color="#3B82F6"
                onClick={() => changeStatus.mutate({ status: "approved" })}
              />
            )}
            {post.status === "approved" && (
              <ActionButton
                label="Agendar"
                color="#F97316"
                onClick={() => changeStatus.mutate({ status: "scheduled", scheduledAt: new Date() })}
              />
            )}
            {post.status === "scheduled" && (
              <ActionButton
                label="Publicado"
                color="#22C55E"
                onClick={() => changeStatus.mutate({ status: "published" })}
              />
            )}
            <div className="flex-1" />
            <button
              onClick={() => navigator.clipboard.writeText(post.content)}
              className="text-xs text-light-onSurface/40 hover:text-light-onSurface/70 dark:text-white/40"
            >
              Copiar
            </button>
            <button
              onClick={() => remove.mutate()}
              className="text-xs text-red-500/60 hover:text-red-500"
            >
              Excluir
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function ActionButton({
  label,
  color,
  onClick,
}: {
  label: string;
  color: string;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className="rounded-md border px-3 py-1.5 text-xs font-semibold"
      style={{ color, borderColor: `${color}4D`, backgroundColor: `${color}1A` }}
    >
      {label}
    </button>
  );
}
