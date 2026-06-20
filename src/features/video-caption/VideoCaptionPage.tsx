import { useEffect, useRef, useState } from "react";
import { Upload, Save, Download, Trash2, Plus } from "lucide-react";
import {
  uploadVideo,
  fetchProcessingStatus,
  saveVideoEdit,
  exportFull,
} from "@/features/video-caption/video-caption-api";
import {
  computeKeepSegments,
  findCaptionGaps,
  fmtTime,
  type VideoEdit,
  type Cut,
  type Caption,
} from "@/features/video-caption/video-caption-models";
import { getApiBaseUrl, setApiBaseUrl } from "@/features/video-caption/api-base-url";
import { downloadBlob } from "@/features/audio-visualizer/web-download";

type Stage = "upload" | "processing" | "editor";

export function VideoCaptionPage() {
  const [stage, setStage] = useState<Stage>("upload");
  const [apiBaseUrl, setApiBaseUrlState] = useState(getApiBaseUrl());
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<VideoEdit | null>(null);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const pollRef = useRef<number | null>(null);

  useEffect(() => () => {
    if (pollRef.current) window.clearInterval(pollRef.current);
  }, []);

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    setVideoUrl(URL.createObjectURL(file));
    try {
      const id = await uploadVideo(file);
      setProcessingId(id);
      setStage("processing");
      pollRef.current = window.setInterval(async () => {
        try {
          const { status, edit: result } = await fetchProcessingStatus(id);
          if (status === "done" && result) {
            if (pollRef.current) window.clearInterval(pollRef.current);
            setEdit(result);
            setStage("editor");
          } else if (status === "error") {
            if (pollRef.current) window.clearInterval(pollRef.current);
            setError("Falha no processamento do vídeo.");
            setStage("upload");
          }
        } catch (err) {
          if (pollRef.current) window.clearInterval(pollRef.current);
          setError(err instanceof Error ? err.message : String(err));
          setStage("upload");
        }
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setStage("upload");
    }
  }

  function updateCut(index: number, patch: Partial<Cut>) {
    setEdit((e) => (e ? { ...e, cuts: e.cuts.map((c, i) => (i === index ? { ...c, ...patch } : c)) } : e));
  }

  function removeCut(index: number) {
    setEdit((e) => (e ? { ...e, cuts: e.cuts.filter((_, i) => i !== index) } : e));
  }

  function addCut() {
    setEdit((e) => (e ? { ...e, cuts: [...e.cuts, { start: 0, end: 1, reason: "" }] } : e));
  }

  function updateCaption(index: number, patch: Partial<Caption>) {
    setEdit((e) =>
      e
        ? {
            ...e,
            captions: e.captions.map((c, i) => (i === index ? { ...c, ...patch, words: patch.text !== undefined ? null : c.words } : c)),
          }
        : e
    );
  }

  async function handleSave() {
    if (!edit) return;
    setSaving(true);
    try {
      await saveVideoEdit(edit);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }

  async function handleExport() {
    if (!edit) return;
    try {
      const blob = await exportFull(edit.id);
      downloadBlob(blob, `${edit.videoFileName || "video"}-edited.mp4`);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    }
  }

  if (stage === "upload") {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-4 p-6">
        <h1 className="text-lg font-semibold text-light-onSurface dark:text-white">Video Caption</h1>
        <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
          Endpoint da API local
          <input
            value={apiBaseUrl}
            onChange={(e) => {
              setApiBaseUrlState(e.target.value);
              setApiBaseUrl(e.target.value);
            }}
            placeholder="http://localhost:3002"
            className="mt-1 w-64 rounded-md border border-light-border-strong bg-transparent p-2 text-sm outline-none dark:border-dark-border"
          />
        </label>
        <label className="flex cursor-pointer items-center gap-1.5 rounded-md bg-primary px-4 py-2 text-sm font-medium text-white">
          <Upload size={14} /> Enviar vídeo
          <input type="file" accept="video/*" className="hidden" onChange={handleUpload} />
        </label>
        {error && <p className="text-sm text-red-500">{error}</p>}
      </div>
    );
  }

  if (stage === "processing") {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-3">
        <p className="text-sm text-light-onSurface/60 dark:text-white/50">
          Processando vídeo (id {processingId})...
        </p>
        <div className="h-1 w-48 overflow-hidden rounded-full bg-light-onSurface/10 dark:bg-white/10">
          <div className="h-full w-1/3 animate-pulse bg-primary" />
        </div>
      </div>
    );
  }

  if (!edit) return null;

  const keeps = computeKeepSegments(edit);
  const gaps = findCaptionGaps(edit);

  return (
    <div className="flex h-full">
      <div className="flex-1 overflow-y-auto p-6">
        <div className="mb-4 flex items-center justify-between">
          <h1 className="text-lg font-semibold text-light-onSurface dark:text-white">{edit.videoFileName}</h1>
          <div className="flex gap-2">
            <button onClick={handleSave} disabled={saving} className="flex items-center gap-1.5 rounded-md border border-light-border px-3 py-1.5 text-xs dark:border-dark-border">
              <Save size={12} /> {saving ? "Salvando..." : "Salvar"}
            </button>
            <button onClick={handleExport} className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-xs text-white">
              <Download size={12} /> Exportar
            </button>
          </div>
        </div>

        {videoUrl && <video src={videoUrl} controls className="mb-4 w-full max-w-xl rounded-lg" />}

        <p className="mb-4 text-xs text-light-onSurface/50 dark:text-white/40">
          Duração {fmtTime(edit.durationSeconds)} · {edit.fps}fps · {keeps.length} trechos mantidos ·{" "}
          {gaps.length} lacunas de legenda
        </p>

        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40">Cortes</h2>
        <div className="mb-6 space-y-2">
          {edit.cuts.map((cut, i) => (
            <div key={i} className="flex items-center gap-2 rounded-md border border-light-border p-2 text-xs dark:border-dark-border">
              <input
                type="number"
                value={cut.start}
                onChange={(e) => updateCut(i, { start: parseFloat(e.target.value) })}
                className="w-16 rounded border border-light-border-strong bg-transparent p-1 dark:border-dark-border"
              />
              <span>→</span>
              <input
                type="number"
                value={cut.end}
                onChange={(e) => updateCut(i, { end: parseFloat(e.target.value) })}
                className="w-16 rounded border border-light-border-strong bg-transparent p-1 dark:border-dark-border"
              />
              <input
                value={cut.reason}
                onChange={(e) => updateCut(i, { reason: e.target.value })}
                placeholder="motivo"
                className="flex-1 rounded border border-light-border-strong bg-transparent p-1 dark:border-dark-border"
              />
              <button onClick={() => removeCut(i)} className="text-red-500/70">
                <Trash2 size={12} />
              </button>
            </div>
          ))}
          <button onClick={addCut} className="flex items-center gap-1 text-xs text-primary">
            <Plus size={12} /> Adicionar corte
          </button>
        </div>

        <h2 className="mb-2 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40">Legendas</h2>
        <div className="space-y-2">
          {edit.captions.map((caption, i) => (
            <div key={i} className="rounded-md border border-light-border p-2 text-xs dark:border-dark-border">
              <p className="mb-1 text-light-onSurface/40">
                {(caption.startFrame / edit.fps).toFixed(1)}s - {(caption.endFrame / edit.fps).toFixed(1)}s
              </p>
              <textarea
                value={caption.text}
                onChange={(e) => updateCaption(i, { text: e.target.value })}
                rows={2}
                className="w-full rounded border border-light-border-strong bg-transparent p-1 text-sm dark:border-dark-border"
              />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
