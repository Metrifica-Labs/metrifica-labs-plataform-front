import { supabase } from "@/core/supabase/client";

export interface HistoryEntry {
  id: string;
  flowSlug: string;
  flowName: string | null;
  userMessage: string;
  templateName: string | null;
  output: string;
  createdAt: string;
}

function fromRow(row: {
  id: string;
  flow_slug: string;
  flow_name: string | null;
  user_message: string;
  template_name: string | null;
  output: string;
  created_at: string;
}): HistoryEntry {
  return {
    id: row.id,
    flowSlug: row.flow_slug,
    flowName: row.flow_name,
    userMessage: row.user_message,
    templateName: row.template_name,
    output: row.output,
    createdAt: row.created_at,
  };
}

export async function fetchGenerationHistory(): Promise<HistoryEntry[]> {
  const { data, error } = await supabase
    .from("generation_history")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(50);
  if (error) throw error;
  return data.map(fromRow);
}

export async function addGenerationHistoryEntry(params: {
  flowSlug: string;
  flowName?: string | null;
  userMessage: string;
  templateName?: string | null;
  output: string;
  organizationId?: string | null;
}): Promise<HistoryEntry> {
  const { data, error } = await supabase
    .from("generation_history")
    .insert({
      flow_slug: params.flowSlug,
      flow_name: params.flowName ?? null,
      user_message: params.userMessage,
      template_name: params.templateName ?? null,
      output: params.output,
      ...(params.organizationId ? { organization_id: params.organizationId } : {}),
    })
    .select()
    .single();
  if (error) throw error;
  return fromRow(data);
}

export async function removeGenerationHistoryEntry(id: string): Promise<void> {
  const { error } = await supabase.from("generation_history").delete().eq("id", id);
  if (error) throw error;
}

export async function clearGenerationHistory(): Promise<void> {
  const { error } = await supabase.from("generation_history").delete().neq("id", "");
  if (error) throw error;
}
