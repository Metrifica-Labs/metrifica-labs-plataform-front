import { supabase } from "@/core/supabase/client";
import { moduleFromRow, type ModuleModel } from "@/core/models/module";

export async function fetchModules(): Promise<ModuleModel[]> {
  const { data, error } = await supabase
    .from("modules")
    .select("*")
    .order("created_at");
  if (error) throw error;
  return data.map(moduleFromRow);
}

export async function fetchModuleBySlug(slug: string): Promise<ModuleModel | null> {
  const { data, error } = await supabase
    .from("modules")
    .select("*")
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw error;
  return data ? moduleFromRow(data) : null;
}

export async function fetchModulesBySlugs(slugs: string[]): Promise<ModuleModel[]> {
  if (slugs.length === 0) return [];
  const { data, error } = await supabase
    .from("modules")
    .select("*")
    .in("slug", slugs);
  if (error) throw error;
  return data.map(moduleFromRow);
}

export async function upsertModule(
  slug: string,
  content: string
): Promise<void> {
  const { error } = await supabase
    .from("modules")
    .update({ content })
    .eq("slug", slug);
  if (error) throw error;
}
