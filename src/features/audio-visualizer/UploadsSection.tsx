import { Upload, Play, Pause, Circle, FileText, RefreshCw, AudioLines } from "lucide-react";
import { Button } from "@/shared/components/ui/Button";
import { EmptyState } from "@/shared/components/ui/Card";
import { Skeleton } from "@/shared/components/ui/Skeleton";

export function UploadsSection({
  audioUrl,
  isPlaying,
  isRecording,
  isTranscribing,
  pendingAudioFile,
  onFileUpload,
  onCaptionsUpload,
  onTogglePlay,
  onToggleRecording,
  onRetranscribe,
}: {
  audioUrl: string | null;
  isPlaying: boolean;
  isRecording: boolean;
  isTranscribing: boolean;
  pendingAudioFile: File | null;
  onFileUpload: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onCaptionsUpload: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onTogglePlay: () => void;
  onToggleRecording: () => void;
  onRetranscribe: () => void;
}) {
  return (
    <div className="flex w-full flex-col items-center gap-4">
      <div className="flex items-center gap-3">
        <label className="flex cursor-pointer items-center gap-1.5 rounded-md border border-light-border px-3 py-2 text-sm dark:border-dark-border">
          <Upload size={14} /> Áudio
          <input type="file" accept="audio/*" className="hidden" onChange={onFileUpload} />
        </label>
        <Button onClick={onTogglePlay} disabled={!audioUrl} size="sm">
          {isPlaying ? <Pause size={14} /> : <Play size={14} />}
        </Button>
        <Button
          variant={isRecording ? "danger" : "secondary"}
          size="sm"
          onClick={onToggleRecording}
          disabled={!audioUrl}
        >
          <Circle size={14} /> {isRecording ? "Gravando..." : "Gravar"}
        </Button>
      </div>

      <div className="flex items-center gap-3">
        <label className="flex cursor-pointer items-center gap-1.5 text-xs text-light-onSurface/50 hover:text-primary dark:text-white/40">
          <FileText size={13} /> Carregar legenda (.json/.srt)
          <input type="file" accept=".json,.srt,.vtt" className="hidden" onChange={onCaptionsUpload} />
        </label>
        {pendingAudioFile && (
          <button
            onClick={onRetranscribe}
            disabled={isTranscribing}
            className="flex items-center gap-1.5 text-xs text-light-onSurface/50 hover:text-primary disabled:opacity-50 dark:text-white/40"
          >
            <RefreshCw size={13} /> Transcrever novamente
          </button>
        )}
      </div>

      {isTranscribing && (
        <div className="w-full max-w-xs space-y-2">
          <p className="text-center text-xs text-light-onSurface/50">Transcrevendo áudio...</p>
          <Skeleton className="h-3 w-full" />
          <Skeleton className="h-3 w-4/5" />
        </div>
      )}

      {!audioUrl && !isTranscribing && (
        <EmptyState
          icon={<AudioLines size={20} />}
          title="Nenhum áudio enviado ainda"
          description="Envie um arquivo de áudio para visualizar o anel de frequência e gerar legendas automaticamente."
        />
      )}
    </div>
  );
}
