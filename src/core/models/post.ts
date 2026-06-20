export type PostStatus = "draft" | "approved" | "scheduled" | "published";

export const POST_STATUS_LABELS: Record<PostStatus, string> = {
  draft: "Rascunho",
  approved: "Aprovado",
  scheduled: "Agendado",
  published: "Publicado",
};

export const POST_STATUS_COLORS: Record<PostStatus, string> = {
  draft: "#94A3B8",
  approved: "#3B82F6",
  scheduled: "#F97316",
  published: "#22C55E",
};

export interface PostModel {
  id: string;
  organizationId: string;
  flowSlug: string;
  content: string;
  imageUrl: string | null;
  status: PostStatus;
  pillar: string | null;
  scheduledAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export function postFromRow(row: {
  id: string;
  organization_id: string;
  flow_slug: string;
  content: string;
  image_url: string | null;
  status: string | null;
  pillar: string | null;
  scheduled_at: string | null;
  created_at: string;
  updated_at: string;
}): PostModel {
  return {
    id: row.id,
    organizationId: row.organization_id,
    flowSlug: row.flow_slug,
    content: row.content,
    imageUrl: row.image_url,
    status: (row.status as PostStatus) ?? "draft",
    pillar: row.pillar,
    scheduledAt: row.scheduled_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
