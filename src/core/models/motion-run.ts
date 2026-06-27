import type { MotionSpec, VideoFormat } from "@/remotion/motion-spec";

export type MotionRunStatus = "completed" | "failed";

export interface MotionRunModel {
  id: string;
  organizationId: string;
  status: MotionRunStatus;
  input: string;
  format: VideoFormat;
  /** MotionSpec validado. `null` apenas em runs que falharam. */
  motionSpec: MotionSpec | null;
  specVersion: number;
  videoUrl: string | null;
  error: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

export interface MotionRunRow {
  id: string;
  organization_id: string;
  status: MotionRunStatus;
  input: string;
  format: string;
  motion_spec: MotionSpec | null;
  spec_version: number;
  video_url: string | null;
  error: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export function motionRunFromRow(row: MotionRunRow): MotionRunModel {
  return {
    id: row.id,
    organizationId: row.organization_id,
    status: row.status,
    input: row.input,
    format: row.format as VideoFormat,
    motionSpec: row.motion_spec,
    specVersion: row.spec_version,
    videoUrl: row.video_url,
    error: row.error,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
