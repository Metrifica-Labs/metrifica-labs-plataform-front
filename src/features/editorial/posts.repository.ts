import { supabase } from "@/core/supabase/client";
import { postFromRow, type PostModel, type PostStatus } from "@/core/models/post";

export async function fetchPosts(orgId: string): Promise<PostModel[]> {
  const { data, error } = await supabase
    .from("posts")
    .select("*")
    .eq("organization_id", orgId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) throw error;
  return data.map(postFromRow);
}

export async function fetchPillarStats(orgId: string): Promise<Record<string, number>> {
  const since = new Date();
  since.setDate(since.getDate() - 30);

  const { data, error } = await supabase
    .from("posts")
    .select("pillar")
    .eq("organization_id", orgId)
    .gte("created_at", since.toISOString());
  if (error) throw error;

  const counts: Record<string, number> = {};
  for (const row of data) {
    const pillar = (row.pillar as string | null) ?? "sem pilar";
    counts[pillar] = (counts[pillar] ?? 0) + 1;
  }
  return counts;
}

export async function updatePostStatus(
  id: string,
  status: PostStatus,
  scheduledAt?: Date
): Promise<PostModel> {
  const { data, error } = await supabase
    .from("posts")
    .update({
      status,
      ...(scheduledAt ? { scheduled_at: scheduledAt.toISOString() } : {}),
    })
    .eq("id", id)
    .select()
    .single();
  if (error) throw error;
  return postFromRow(data);
}

export async function deletePost(id: string): Promise<void> {
  const { error } = await supabase.from("posts").delete().eq("id", id);
  if (error) throw error;
}
