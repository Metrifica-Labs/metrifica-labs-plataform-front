import { supabase } from "@/core/supabase/client";
import { personaFromRow, type PersonaModel } from "@/features/copy/persona-model";

export async function fetchPersonas(orgId: string): Promise<PersonaModel[]> {
  const { data, error } = await supabase
    .from("personas")
    .select("*")
    .eq("org_id", orgId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data.map(personaFromRow);
}

export async function createPersona(orgId: string, name: string, content: string): Promise<PersonaModel> {
  const { data, error } = await supabase
    .from("personas")
    .insert({ org_id: orgId, name, content })
    .select()
    .single();
  if (error) throw error;
  return personaFromRow(data);
}

export async function updatePersona(id: string, patch: { name?: string; content?: string }): Promise<PersonaModel> {
  const { data, error } = await supabase
    .from("personas")
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select()
    .single();
  if (error) throw error;
  return personaFromRow(data);
}

export async function deletePersona(id: string): Promise<void> {
  const { error } = await supabase.from("personas").delete().eq("id", id);
  if (error) throw error;
}
