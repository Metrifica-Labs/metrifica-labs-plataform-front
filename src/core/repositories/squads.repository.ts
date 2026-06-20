import { supabase } from "@/core/supabase/client";
import { squadDefinitionFromRow, type SquadDefinitionModel } from "@/core/models/squad-definition";

export async function fetchSquads(): Promise<SquadDefinitionModel[]> {
  const { data, error } = await supabase
    .from("squad_definitions")
    .select("*")
    .order("created_at");
  if (error) throw error;
  return data.map(squadDefinitionFromRow);
}

export async function fetchSquadBySlug(slug: string): Promise<SquadDefinitionModel | null> {
  const { data, error } = await supabase
    .from("squad_definitions")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw error;
  return data ? squadDefinitionFromRow(data) : null;
}
