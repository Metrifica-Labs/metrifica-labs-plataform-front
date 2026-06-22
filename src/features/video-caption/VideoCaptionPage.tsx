import { useEffect, useRef, useState } from "react";
import { Upload, Save, Download, Trash2, Plus, Scissors, Captions, Film, Sparkles } from "lucide-react";
import {
  uploadVideo,
  fetchProcessingStatus,
  saveVideoEdit,
  exportFull,
  exportSegment,
} from "@/features/video-caption/video-caption-api";
import {
  computeKeepSegments,
  findCaptionGaps,
  fmtTime,
  createCaptionStyle,
  type VideoEdit,
  type Cut,
  type Caption,
  type CaptionStyle,
} from "@/features/video-caption/video-caption-models";
import { getApiBaseUrl, setApiBaseUrl } from "@/features/video-caption/api-base-url";
import { downloadBlob } from "@/features/audio-visualizer/web-download";
import { PageHeader, EmptyState } from "@/shared/components/ui/Card";
import { Tabs } from "@/shared/components/ui/Tabs";
import { Dialog } from "@/shared/components/ui/Dialog";
import { Select, Label } from "@/shared/components/ui/Field";
import { ColorInput } from "@/shared/components/ui/ColorInput";
import { Stepper } from "@/shared/components/ui/Stepper";
import { useToast } from "@/shared/hooks/useToast";

type Stage = "upload" | "processing" | "editor";
type TabKey = "cortes" | "legendas" | "segmentos" | "analise" | "estilo";

const TAB_ITEMS: { value: TabKey; label: string }[] = [
  { value: "cortes", label: "Cortes" },
  { value: "legendas", label: "Legendas" },
  { value: "segmentos", label: "Segmentos" },
  { value: "analise", label: "Análise" },
  { value: "estilo", label: "Estilo" },
];

const FONT_OPTIONS = ["Syne", "Inter", "Poppins", "Montserrat", "Roboto"];
const POSITION_OPTIONS = [
  { value: "bottom", label: "Inferior" },
  { value: "middle", label: "Centro" },
  { value: "top", label: "Superior" },
];

export function VideoCaptionPage() {
  const toast = useToast();
  const [stage, setStage] = useState<Stage>("upload");
  const [apiBaseUrl, setApiBaseUrlState] = useState(getApiBaseUrl());
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [edit, setEdit] = useState<VideoEdit | null>(null);
  const [videoUrl, setVideoUrl] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [exportingSegment, setExportingSegment] = useState<number | null>(null);
  const [tab, setTab] = useState<TabKey>("cortes");
  const [captionStyle, setCaptionStyle] = useState<CaptionStyle>(createCaptionStyle());
  const [stylePosition, setStylePosition] = useState<"bottom" | "middle" | "top">("bottom");
  const [deleteTarget, setDeleteTarget] = useState<
    { kind: "cut" | "caption"; index: number } | null
  >(null);
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

  function removeCaption(index: number) {
    setEdit((e) => (e ? { ...e, captions: e.captions.filter((_, i) => i !== index) } : e));
  }

  function confirmDelete() {
    if (!deleteTarget) return;
    if (deleteTarget.kind === "cut") removeCut(deleteTarget.index);
    else removeCaption(deleteTarget.index);
    setDeleteTarget(null);
  }

  async function handleSave() {
    if (!edit) return;
    setSaving(true);
    try {
      await saveVideoEdit(edit);
      toast.success("Edição salva.");
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
      toast.error(message);
    } finally {
      setSaving(false);
    }
  }

  async function handleExport() {
    if (!edit) return;
    try {
      const blob = await exportFull(edit.id);
      downloadBlob(blob, `${edit.videoFileName || "video"}-edited.mp4`);
      toast.success("Vídeo exportado.");
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
      toast.error(message);
    }
  }

  async function handleExportSegment(index: number, start: number, end: number) {
    if (!edit) return;
    setExportingSegment(index);
    try {
      const blob = await exportSegment(edit.id, start, end);
      downloadBlob(blob, `${edit.videoFileName || "video"}-segmento-${index + 1}.mp4`);
      toast.success("Segmento exportado.");
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      setError(message);
      toast.error(message);
    } finally {
      setExportingSegment(null);
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
    <div className="flex h-full flex-col overflow-y-auto p-6">
      <PageHeader
        title={edit.videoFileName}
        subtitle={`Duração ${fmtTime(edit.durationSeconds)} · ${edit.fps}fps · ${keeps.length} trechos mantidos · ${gaps.length} lacunas de legenda`}
        actions={
          <>
            <button
              onClick={handleSave}
              disabled={saving}
              className="flex items-center gap-1.5 rounded-md border border-light-border px-3 py-1.5 text-xs dark:border-dark-border"
            >
              <Save size={12} /> {saving ? "Salvando..." : "Salvar"}
            </button>
            <button
              onClick={handleExport}
              className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-xs text-white"
            >
              <Download size={12} /> Exportar
            </button>
          </>
        }
      />

      {videoUrl && <video src={videoUrl} controls className="mb-4 w-full max-w-xl rounded-lg" />}
      {error && <p className="mb-4 text-sm text-red-500">{error}</p>}

      <div className="mb-4">
        <Tabs value={tab} onChange={setTab} items={TAB_ITEMS} />
      </div>

      {tab === "cortes" && (
        <div className="space-y-2">
          {edit.cuts.length === 0 ? (
            <EmptyState
              icon={<Scissors size={20} />}
              title="Nenhum corte ainda"
              description="Adicione um corte manual ou aguarde as sugestões automáticas do processamento."
            />
          ) : (
            edit.cuts.map((cut, i) => (
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
                <button onClick={() => setDeleteTarget({ kind: "cut", index: i })} className="text-red-500/70">
                  <Trash2 size={12} />
                </button>
              </div>
            ))
          )}
          <button onClick={addCut} className="flex items-center gap-1 text-xs text-primary">
            <Plus size={12} /> Adicionar corte
          </button>
        </div>
      )}

      {tab === "legendas" && (
        <div className="space-y-2">
          {edit.captions.length === 0 ? (
            <EmptyState
              icon={<Captions size={20} />}
              title="Nenhuma legenda ainda"
              description="As legendas aparecem aqui depois que a transcrição automática é concluída."
            />
          ) : (
            edit.captions.map((caption, i) => (
              <div key={i} className="rounded-md border border-light-border p-2 text-xs dark:border-dark-border">
                <div className="mb-1 flex items-center justify-between">
                  <p className="text-light-onSurface/40">
                    {(caption.startFrame / edit.fps).toFixed(1)}s - {(caption.endFrame / edit.fps).toFixed(1)}s
                  </p>
                  <button onClick={() => setDeleteTarget({ kind: "caption", index: i })} className="text-red-500/70">
                    <Trash2 size={12} />
                  </button>
                </div>
                <textarea
                  value={caption.text}
                  onChange={(e) => updateCaption(i, { text: e.target.value })}
                  rows={2}
                  className="w-full rounded border border-light-border-strong bg-transparent p-1 text-sm dark:border-dark-border"
                />
              </div>
            ))
          )}
          {gaps.length > 0 && (
            <div className="mt-4">
              <h3 className="mb-2 text-2xs font-semibold uppercase tracking-wide text-light-onSurface/40">
                Lacunas sem legenda
              </h3>
              <div className="space-y-1">
                {gaps.map((gap, i) => (
                  <p key={i} className="text-2xs text-light-onSurface/50 dark:text-white/40">
                    {fmtTime(gap.start)} – {fmtTime(gap.end)}
                  </p>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {tab === "segmentos" && (
        <div className="space-y-2">
          {keeps.length === 0 ? (
            <EmptyState
              icon={<Film size={20} />}
              title="Nenhum segmento mantido"
              description="Os trechos mantidos após os cortes aparecem aqui."
            />
          ) : (
            keeps.map((keep, i) => (
              <div
                key={i}
                className="flex items-center justify-between gap-2 rounded-md border border-light-border p-2 text-xs dark:border-dark-border"
              >
                <span className="text-light-onSurface/70 dark:text-white/60">
                  Segmento {i + 1} · {fmtTime(keep.start)} – {fmtTime(keep.end)}
                </span>
                <button
                  onClick={() => handleExportSegment(i, keep.start, keep.end)}
                  disabled={exportingSegment === i}
                  className="flex items-center gap-1.5 rounded-md border border-light-border px-2 py-1 text-2xs dark:border-dark-border"
                >
                  <Download size={11} /> {exportingSegment === i ? "Exportando..." : "Exportar"}
                </button>
              </div>
            ))
          )}
        </div>
      )}

      {tab === "analise" && (
        <div className="space-y-3">
          {edit.analysisNotes ? (
            <div className="rounded-md border border-light-border p-3 text-sm dark:border-dark-border">
              <p className="whitespace-pre-wrap text-light-onSurface/80 dark:text-white/70">
                {edit.analysisNotes}
              </p>
            </div>
          ) : (
            <EmptyState
              icon={<Sparkles size={20} />}
              title="Nenhuma nota de análise"
              description="As notas de IA sobre a edição aparecem aqui quando disponíveis."
            />
          )}
        </div>
      )}

      {tab === "estilo" && (
        <div className="max-w-sm space-y-4">
          <div>
            <Label>Fonte</Label>
            <Select
              value={captionStyle.fontFamily}
              onChange={(e) => setCaptionStyle((s) => ({ ...s, fontFamily: e.target.value }))}
            >
              {FONT_OPTIONS.map((font) => (
                <option key={font} value={font}>
                  {font}
                </option>
              ))}
            </Select>
          </div>

          <Stepper
            label="Tamanho da fonte"
            value={captionStyle.fontSize}
            min={10}
            max={48}
            step={1}
            onChange={(v) => setCaptionStyle((s) => ({ ...s, fontSize: v }))}
          />

          <div>
            <Label>Posição</Label>
            <Select
              value={stylePosition}
              onChange={(e) => setStylePosition(e.target.value as "bottom" | "middle" | "top")}
            >
              {POSITION_OPTIONS.map((opt) => (
                <option key={opt.value} value={opt.value}>
                  {opt.label}
                </option>
              ))}
            </Select>
          </div>

          <ColorInput
            label="Cor do texto"
            value={captionStyle.textColor}
            onChange={(v) => setCaptionStyle((s) => ({ ...s, textColor: v }))}
          />
          <ColorInput
            label="Cor de fundo"
            value={captionStyle.backgroundColor}
            onChange={(v) => setCaptionStyle((s) => ({ ...s, backgroundColor: v }))}
          />

          <Stepper
            label="Distância da base (px)"
            value={captionStyle.bottomOffset}
            min={0}
            max={200}
            step={2}
            onChange={(v) => setCaptionStyle((s) => ({ ...s, bottomOffset: v }))}
          />

          <Stepper
            label="Largura máxima (%)"
            value={captionStyle.maxWidthPercent}
            min={30}
            max={100}
            step={5}
            onChange={(v) => setCaptionStyle((s) => ({ ...s, maxWidthPercent: v }))}
          />
        </div>
      )}

      <Dialog
        open={deleteTarget !== null}
        onClose={() => setDeleteTarget(null)}
        title={deleteTarget?.kind === "cut" ? "Excluir corte" : "Excluir legenda"}
      >
        <p className="mb-4 text-sm text-light-onSurface/65 dark:text-dark-onSurface/60">
          Essa ação não pode ser desfeita. Deseja continuar?
        </p>
        <div className="flex justify-end gap-2">
          <button
            onClick={() => setDeleteTarget(null)}
            className="rounded-md border border-light-border px-3 py-1.5 text-xs dark:border-dark-border"
          >
            Cancelar
          </button>
          <button
            onClick={confirmDelete}
            className="rounded-md bg-red-500 px-3 py-1.5 text-xs font-medium text-white"
          >
            Excluir
          </button>
        </div>
      </Dialog>
    </div>
  );
}
