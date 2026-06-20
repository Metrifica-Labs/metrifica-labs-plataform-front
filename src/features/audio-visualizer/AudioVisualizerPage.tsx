import { useEffect, useRef, useState } from "react";
import { Upload, Play, Pause, Circle, Download } from "lucide-react";
import { AudioVisualizerEngine } from "@/features/audio-visualizer/audio-visualizer-engine";
import { createAudioVisualizerConfig, VIDEO_ASPECTS } from "@/features/audio-visualizer/audio-visualizer-config";
import { EMPTY_CAPTIONS, type Captions } from "@/features/audio-visualizer/captions";
import { transcribeAudio } from "@/features/audio-visualizer/transcription.service";
import { downloadBlob } from "@/features/audio-visualizer/web-download";

export function AudioVisualizerPage() {
  const [config, setConfig] = useState(createAudioVisualizerConfig());
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [captions, setCaptions] = useState<Captions>(EMPTY_CAPTIONS);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  const engineRef = useRef<AudioVisualizerEngine | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const configRef = useRef(config);
  const captionsRef = useRef(captions);
  configRef.current = config;
  captionsRef.current = captions;

  useEffect(() => {
    if (!canvasRef.current || !audioRef.current) return;
    const audioCtx = new AudioContext();
    const source = audioCtx.createMediaElementSource(audioRef.current);
    const analyser = audioCtx.createAnalyser();
    analyser.fftSize = 256;
    source.connect(analyser);
    analyser.connect(audioCtx.destination);
    audioCtxRef.current = audioCtx;

    const engine = new AudioVisualizerEngine(
      canvasRef.current,
      analyser,
      () => configRef.current,
      () => captionsRef.current,
      () => audioRef.current?.currentTime ?? 0
    );
    engine.start();
    engineRef.current = engine;

    return () => {
      engine.stop();
      void audioCtx.close();
    };
  }, [audioUrl]);

  function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setAudioUrl(URL.createObjectURL(file));

    setIsTranscribing(true);
    transcribeAudio(file)
      .then(setCaptions)
      .catch(() => setCaptions(EMPTY_CAPTIONS))
      .finally(() => setIsTranscribing(false));
  }

  function handleCenterImageUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const url = URL.createObjectURL(file);
    setConfig((c) => ({ ...c, centerImageUrl: url }));
    engineRef.current?.setCenterImage(url);
  }

  function togglePlay() {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
    } else {
      void audioCtxRef.current?.resume();
      void audioRef.current.play();
    }
    setIsPlaying((p) => !p);
  }

  function toggleRecording() {
    if (!canvasRef.current) return;
    if (isRecording) {
      recorderRef.current?.stop();
      setIsRecording(false);
      return;
    }
    const stream = canvasRef.current.captureStream(config.fps);
    const recorder = new MediaRecorder(stream, { mimeType: "video/webm" });
    const chunks: Blob[] = [];
    recorder.ondataavailable = (e) => chunks.push(e.data);
    recorder.onstop = () => downloadBlob(new Blob(chunks, { type: "video/webm" }), "audio-visualizer.webm");
    recorder.start();
    recorderRef.current = recorder;
    setIsRecording(true);
  }

  const { width, height } = VIDEO_ASPECTS[config.aspect];

  return (
    <div className="flex h-full">
      <div className="flex flex-1 flex-col items-center justify-center gap-4 p-6">
        <canvas
          ref={canvasRef}
          width={width}
          height={height}
          style={{ width: 320, height: (320 * height) / width, borderRadius: 12 }}
          className="bg-black"
        />
        <audio ref={audioRef} src={audioUrl ?? undefined} onEnded={() => setIsPlaying(false)} />

        <div className="flex items-center gap-3">
          <label className="flex cursor-pointer items-center gap-1.5 rounded-md border border-light-border px-3 py-2 text-sm dark:border-dark-border">
            <Upload size={14} /> Áudio
            <input type="file" accept="audio/*" className="hidden" onChange={handleFileUpload} />
          </label>
          <button
            onClick={togglePlay}
            disabled={!audioUrl}
            className="flex items-center gap-1.5 rounded-md bg-primary px-3 py-2 text-sm text-white disabled:opacity-50"
          >
            {isPlaying ? <Pause size={14} /> : <Play size={14} />}
          </button>
          <button
            onClick={toggleRecording}
            disabled={!audioUrl}
            className={`flex items-center gap-1.5 rounded-md border px-3 py-2 text-sm disabled:opacity-50 ${
              isRecording ? "border-red-500 text-red-500" : "border-light-border dark:border-dark-border"
            }`}
          >
            <Circle size={14} /> {isRecording ? "Gravando..." : "Gravar"}
          </button>
        </div>

        {isTranscribing && <p className="text-xs text-light-onSurface/50">Transcrevendo áudio...</p>}
      </div>

      <div className="w-72 shrink-0 overflow-y-auto border-l border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card">
        <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
          Configuração
        </h2>
        <div className="space-y-3">
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Formato
            <select
              value={config.aspect}
              onChange={(e) => setConfig((c) => ({ ...c, aspect: e.target.value as typeof c.aspect }))}
              className="mt-1 w-full rounded-md border border-light-border-strong bg-transparent p-2 text-sm dark:border-dark-border"
            >
              {Object.entries(VIDEO_ASPECTS).map(([value, { label }]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Imagem central
            <input type="file" accept="image/*" onChange={handleCenterImageUpload} className="mt-1 block w-full text-xs" />
          </label>
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Sensibilidade ({config.sensitivity.toFixed(1)})
            <input
              type="range"
              min={0.2}
              max={3}
              step={0.1}
              value={config.sensitivity}
              onChange={(e) => setConfig((c) => ({ ...c, sensitivity: parseFloat(e.target.value) }))}
              className="mt-1 w-full"
            />
          </label>
          <label className="block text-xs text-light-onSurface/60 dark:text-white/50">
            Rotação ({config.rotationSpeed}°/s)
            <input
              type="range"
              min={0}
              max={30}
              value={config.rotationSpeed}
              onChange={(e) => setConfig((c) => ({ ...c, rotationSpeed: parseFloat(e.target.value) }))}
              className="mt-1 w-full"
            />
          </label>
          <label className="flex items-center gap-2 text-xs text-light-onSurface/60 dark:text-white/50">
            <input
              type="checkbox"
              checked={config.captionEnabled}
              onChange={(e) => setConfig((c) => ({ ...c, captionEnabled: e.target.checked }))}
            />
            Legendas
          </label>
        </div>

        {captions.segments.length > 0 && (
          <button
            onClick={() => downloadBlob(new Blob([JSON.stringify(captions)], { type: "application/json" }), "captions.json")}
            className="mt-4 flex items-center gap-1.5 text-xs text-primary hover:underline"
          >
            <Download size={12} /> Exportar legendas
          </button>
        )}
      </div>
    </div>
  );
}
