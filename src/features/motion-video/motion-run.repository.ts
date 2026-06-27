import { supabase } from "@/core/supabase/client";
import { useAuthStore } from "@/core/auth/auth-store";
import {
  motionRunFromRow,
  type MotionRunModel,
  type MotionRunRow,
} from "@/core/models/motion-run";
import type { MotionSpec, VideoFormat } from "@/remotion/motion-spec";

/**
 * Acesso à tabela `motion_video_runs` (Fase 4). Segue o padrão de
 * `squad-run.repository.ts`. A RLS por organização garante que cada usuário só
 * enxerga/grava runs das orgs de que é membro — por isso basta enviar
 * `organization_id`; o `auth.uid()` vem da sessão Supabase.
 */

export async function createMotionRun(params: {
  organizationId: string;
  input: string;
  format: VideoFormat;
  spec: MotionSpec;
}): Promise<MotionRunModel> {
  const createdBy = useAuthStore.getState().user?.id ?? null;
  const { data, error } = await supabase
    .from("motion_video_runs")
    .insert({
      organization_id: params.organizationId,
      created_by: createdBy,
      status: "completed",
      input: params.input,
      format: params.format,
      motion_spec: params.spec,
      spec_version: params.spec.specVersion,
    })
    .select("*")
    .single();
  if (error) throw error;
  return motionRunFromRow(data as MotionRunRow);
}

export async function updateMotionSpec(
  runId: string,
  spec: MotionSpec,
): Promise<MotionRunModel> {
  const { data, error } = await supabase
    .from("motion_video_runs")
    .update({ motion_spec: spec, spec_version: spec.specVersion })
    .eq("id", runId)
    .select("*")
    .single();
  if (error) throw error;
  return motionRunFromRow(data as MotionRunRow);
}

export async function fetchMotionRun(runId: string): Promise<MotionRunModel> {
  const { data, error } = await supabase
    .from("motion_video_runs")
    .select("*")
    .eq("id", runId)
    .single();
  if (error) throw error;
  return motionRunFromRow(data as MotionRunRow);
}

export async function listMotionRunsByOrg(
  organizationId: string,
): Promise<MotionRunModel[]> {
  const { data, error } = await supabase
    .from("motion_video_runs")
    .select("*")
    .eq("organization_id", organizationId)
    .order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []).map((row) => motionRunFromRow(row as MotionRunRow));
}
