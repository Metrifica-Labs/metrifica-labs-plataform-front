import { supabase } from "@/core/supabase/client";
import { flowFromRow, type FlowModel } from "@/core/models/flow";

export async function fetchFlows(): Promise<FlowModel[]> {
  const { data, error } = await supabase
    .from("flows")
    .select("*")
    .order("created_at");
  if (error) throw error;
  return data.map(flowFromRow);
}

export async function fetchFlowBySlug(slug: string): Promise<FlowModel | null> {
  const { data, error } = await supabase
    .from("flows")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw error;
  return data ? flowFromRow(data) : null;
}
