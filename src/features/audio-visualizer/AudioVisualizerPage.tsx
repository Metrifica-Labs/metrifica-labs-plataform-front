import { useEffect, useRef, useState } from "react";
import {
  Upload,
  Play,
  Pause,
  Circle,
  Download,
  AudioLines,
  Image as ImageIcon,
  Disc3,
  Captions as CaptionsIcon,
  Save,
  FileText,
  RefreshCw,
} from "lucide-react";
import { AudioVisualizerEngine } from "@/features/audio-visualizer/audio-visualizer-engine";
import {
  createAudioVisualizerConfig,
  VIDEO_ASPECTS,
  type BackgroundType,
  type CaptionMode,
} from "@/features/audio-visualizer/audio-visualizer-config";
import { EMPTY_CAPTIONS, parseCaptions, type Captions } from "@/features/audio-visualizer/captions";
import { transcribeAudio } from "@/features/audio-visualizer/transcription.service";
import { downloadBlob } from "@/features/audio-visualizer/web-download";
import { listPresetNames, savePreset, loadPreset, deletePreset } from "@/features/audio-visualizer/audio-visualizer-presets";
import { pickImageDataUrl } from "@/shared/lib/pick-image";
import { Button } from "@/shared/components/ui/Button";
import { Select, Input } from "@/shared/components/ui/Field";
import { SectionCard } from "@/shared/components/ui/Card";
import { Stepper } from "@/shared/components/ui/Stepper";
import { Switch as Toggle } from "@/shared/components/ui/Switch";
import { ImagePicker } from "@/shared/components/ui/ImagePicker";
import { ColorInput } from "@/shared/components/ui/ColorInput";

const BACKGROUND_TYPE_LABELS: Record<BackgroundType, string> = {
  solid: "Cor sólida",
  gradient: "Degradê",
  image: "Imagem",
};

const CAPTION_MODE_LABELS: Record<CaptionMode, string> = {
  segment: "Frase completa",
  karaoke: "Karaoke (palavra)",
  word: "Palavra por palavra",
};

export function AudioVisualizerPage() {
  const [config, setConfig] = useState(createAudioVisualizerConfig());
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [captions, setCaptions] = useState<Captions>(EMPTY_CAPTIONS);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isTranscribing, setIsTranscribing] = useState(false);
  const [isRecording, setIsRecording] = useState(false);
  const [presetNames, setPresetNames] = useState<string[]>(() => listPresetNames());
  const [selectedPreset, setSelectedPreset] = useState("");
  const [presetNameInput, setPresetNameInput] = useState("");
  const [pendingAudioFile, setPendingAudioFile] = useState<File | null>(null);

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  const engineRef = useRef<AudioVisualizerEngine | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const recorderRef = useRef<MediaRecorder | null>(null);
  const configRef = useRef(config);
  const captionsRef = useRef(captions);
  configRef.current = config;
  captionsRef.current = captions;

  useEffect(() => {
    if (!canvasRef.current || !audioRef.current) return;

    if (!audioCtxRef.current) {
      const audioCtx = new AudioContext();
      const source = audioCtx.createMediaElementSource(audioRef.current);
      const analyser = audioCtx.createAnalyser();
      analyser.fftSize = 256;
      source.connect(analyser);
      analyser.connect(audioCtx.destination);
      audioCtxRef.current = audioCtx;
      analyserRef.current = analyser;
    }

    const engine = new AudioVisualizerEngine(
      canvasRef.current,
      analyserRef.current!,
      () => configRef.current,
      () => captionsRef.current,
      () => audioRef.current?.currentTime ?? 0
    );
    if (config.centerImageUrl) engine.setCenterImage(config.centerImageUrl);
    if (config.backgroundImageUrl) engine.setBackgroundImage(config.backgroundImageUrl);
    engine.start();
    engineRef.current = engine;

    return () => {
      engine.stop();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [audioUrl]);

  useEffect(() => {
    return () => {
      void audioCtxRef.current?.close();
    };
  }, []);

  function runTranscription(file: File) {
    setIsTranscribing(true);
    transcribeAudio(file)
      .then(setCaptions)
      .catch(() => setCaptions(EMPTY_CAPTIONS))
      .finally(() => setIsTranscribing(false));
  }

  function handleFileUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setAudioUrl(URL.createObjectURL(file));
    setPendingAudioFile(file);
    runTranscription(file);
  }

  function handleCaptionsUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    file.text().then((content) => setCaptions(parseCaptions(content)));
  }

  async function handleCenterImagePick() {
    const url = await pickImageDataUrl();
    if (!url) return;
    setConfig((c) => ({ ...c, centerImageUrl: url }));
    engineRef.current?.setCenterImage(url);
  }

  async function handleBackgroundImagePick() {
    const url = await pickImageDataUrl();
    if (!url) return;
    setConfig((c) => ({ ...c, backgroundImageUrl: url }));
    engineRef.current?.setBackgroundImage(url);
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

  function handleSelectPreset(name: string) {
    setSelectedPreset(name);
    if (!name) return;
    const loaded = loadPreset(name, config);
    if (loaded) setConfig(loaded);
  }

  function handleSavePreset() {
    const name = presetNameInput.trim() || selectedPreset.trim();
    if (!name) return;
    savePreset(name, config);
    setPresetNames(listPresetNames());
    setSelectedPreset(name);
    setPresetNameInput("");
  }

  function handleDeletePreset() {
    if (!selectedPreset) return;
    deletePreset(selectedPreset);
    setPresetNames(listPresetNames());
    setSelectedPreset("");
  }

  const { width, height } = VIDEO_ASPECTS[config.aspect];

  return (
    <div className="flex h-full">
      <div className="flex flex-1 flex-col items-center justify-center gap-4 overflow-y-auto p-6">
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
          <Button onClick={togglePlay} disabled={!audioUrl} size="sm">
            {isPlaying ? <Pause size={14} /> : <Play size={14} />}
          </Button>
          <Button
            variant={isRecording ? "danger" : "secondary"}
            size="sm"
            onClick={toggleRecording}
            disabled={!audioUrl}
          >
            <Circle size={14} /> {isRecording ? "Gravando..." : "Gravar"}
          </Button>
        </div>

        <div className="flex items-center gap-3">
          <label className="flex cursor-pointer items-center gap-1.5 text-xs text-light-onSurface/50 hover:text-primary dark:text-white/40">
            <FileText size={13} /> Carregar legenda (.json/.srt)
            <input type="file" accept=".json,.srt,.vtt" className="hidden" onChange={handleCaptionsUpload} />
          </label>
          {pendingAudioFile && (
            <button
              onClick={() => runTranscription(pendingAudioFile)}
              disabled={isTranscribing}
              className="flex items-center gap-1.5 text-xs text-light-onSurface/50 hover:text-primary disabled:opacity-50 dark:text-white/40"
            >
              <RefreshCw size={13} /> Transcrever novamente
            </button>
          )}
        </div>

        {isTranscribing && <p className="text-xs text-light-onSurface/50">Transcrevendo áudio...</p>}
      </div>

      <div className="w-[320px] shrink-0 space-y-4 overflow-y-auto border-l border-light-border bg-light-surface p-4 dark:border-dark-border dark:bg-dark-surface">
        <SectionCard title="Presets" icon={<Save size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <Select value={selectedPreset} onChange={(e) => handleSelectPreset(e.target.value)}>
              <option value="">Selecione um preset...</option>
              {presetNames.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </Select>
            <Button variant="secondary" size="sm" onClick={handleDeletePreset} disabled={!selectedPreset} className="w-full">
              Excluir preset
            </Button>
            <div className="flex gap-2">
              <Input
                value={presetNameInput}
                onChange={(e) => setPresetNameInput(e.target.value)}
                placeholder={selectedPreset || "Nome do preset"}
                className="flex-1"
              />
              <Button size="sm" onClick={handleSavePreset} disabled={!presetNameInput.trim() && !selectedPreset}>
                Salvar
              </Button>
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Formato" icon={<AudioLines size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <Select value={config.aspect} onChange={(e) => setConfig((c) => ({ ...c, aspect: e.target.value as typeof c.aspect }))}>
              {Object.entries(VIDEO_ASPECTS).map(([value, { label }]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </Select>
            <Stepper label="FPS" value={config.fps} min={15} max={60} onChange={(v) => setConfig((c) => ({ ...c, fps: v }))} />
          </div>
        </SectionCard>

        <SectionCard title="Anel / Espectro" icon={<Disc3 size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <ColorInput label="Cor inicial" value={config.ringColorStart} onChange={(v) => setConfig((c) => ({ ...c, ringColorStart: v }))} />
            <ColorInput label="Cor final" value={config.ringColorEnd} onChange={(v) => setConfig((c) => ({ ...c, ringColorEnd: v }))} />
            <Stepper label="Nº de barras" value={config.barCount} min={24} max={180} step={4} onChange={(v) => setConfig((c) => ({ ...c, barCount: v }))} />
            <Stepper label="Raio do anel" value={config.ringRadius} min={0.15} max={0.45} step={0.01} decimals={2} onChange={(v) => setConfig((c) => ({ ...c, ringRadius: v }))} />
            <Stepper label="Espessura da barra" value={config.barWidth} min={2} max={16} onChange={(v) => setConfig((c) => ({ ...c, barWidth: v }))} />
            <Stepper label="Tamanho máx. da barra" value={config.barMaxLength} min={40} max={260} step={5} onChange={(v) => setConfig((c) => ({ ...c, barMaxLength: v }))} />
            <Stepper label="Sensibilidade" value={config.sensitivity} min={0.4} max={2.5} step={0.1} decimals={1} onChange={(v) => setConfig((c) => ({ ...c, sensitivity: v }))} />
            <Stepper label="Velocidade de rotação" value={config.rotationSpeed} min={0} max={30} onChange={(v) => setConfig((c) => ({ ...c, rotationSpeed: v }))} />
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Brilho (glow)</span>
              <Toggle checked={config.glow} onChange={(v) => setConfig((c) => ({ ...c, glow: v }))} />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Imagem central" icon={<ImageIcon size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <ImagePicker
              src={config.centerImageUrl}
              height={90}
              onPick={handleCenterImagePick}
              onClear={() => {
                setConfig((c) => ({ ...c, centerImageUrl: null }));
                engineRef.current?.setCenterImage(null);
              }}
            />
            <Stepper label="Escala" value={config.centerImageScale} min={0.4} max={1} step={0.05} decimals={2} onChange={(v) => setConfig((c) => ({ ...c, centerImageScale: v }))} />
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Circular</span>
              <Toggle checked={config.centerImageCircular} onChange={(v) => setConfig((c) => ({ ...c, centerImageCircular: v }))} />
            </div>
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Pulsar com o áudio</span>
              <Toggle checked={config.centerImagePulse} onChange={(v) => setConfig((c) => ({ ...c, centerImagePulse: v }))} />
            </div>
          </div>
        </SectionCard>

        <SectionCard title="Fundo" icon={<ImageIcon size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <Select
              value={config.backgroundType}
              onChange={(e) => setConfig((c) => ({ ...c, backgroundType: e.target.value as BackgroundType }))}
            >
              {Object.entries(BACKGROUND_TYPE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </Select>
            <ColorInput label="Cor de fundo" value={config.backgroundColor} onChange={(v) => setConfig((c) => ({ ...c, backgroundColor: v }))} />
            {config.backgroundType === "gradient" && (
              <ColorInput label="Cor secundária" value={config.backgroundColor2} onChange={(v) => setConfig((c) => ({ ...c, backgroundColor2: v }))} />
            )}
            {config.backgroundType === "image" && (
              <ImagePicker
                src={config.backgroundImageUrl}
                height={90}
                emptyLabel="Adicionar imagem de fundo"
                onPick={handleBackgroundImagePick}
                onClear={() => {
                  setConfig((c) => ({ ...c, backgroundImageUrl: null }));
                  engineRef.current?.setBackgroundImage(null);
                }}
              />
            )}
          </div>
        </SectionCard>

        <SectionCard title="Legendas" icon={<CaptionsIcon size={14} className="text-primary" />}>
          <div className="space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Ativadas</span>
              <Toggle checked={config.captionEnabled} onChange={(v) => setConfig((c) => ({ ...c, captionEnabled: v }))} />
            </div>
            {config.captionEnabled && (
              <>
                <Select value={config.captionMode} onChange={(e) => setConfig((c) => ({ ...c, captionMode: e.target.value as CaptionMode }))}>
                  {Object.entries(CAPTION_MODE_LABELS).map(([value, label]) => (
                    <option key={value} value={value}>
                      {label}
                    </option>
                  ))}
                </Select>
                <Stepper label="Tamanho da fonte" value={config.captionFontSize} min={20} max={96} step={2} onChange={(v) => setConfig((c) => ({ ...c, captionFontSize: v }))} />
                <ColorInput label="Cor do texto" value={config.captionColor} onChange={(v) => setConfig((c) => ({ ...c, captionColor: v }))} />
                <ColorInput label="Cor de destaque" value={config.captionHighlightColor} onChange={(v) => setConfig((c) => ({ ...c, captionHighlightColor: v }))} />
                <Stepper label="Posição (da base)" value={config.captionBottomOffset} min={0.05} max={0.5} step={0.01} decimals={2} onChange={(v) => setConfig((c) => ({ ...c, captionBottomOffset: v }))} />
                {config.captionMode === "karaoke" && (
                  <Stepper label="Palavras por bloco" value={config.captionMaxWords} min={1} max={10} onChange={(v) => setConfig((c) => ({ ...c, captionMaxWords: v }))} />
                )}
                <div className="flex items-center justify-between">
                  <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Negrito</span>
                  <Toggle checked={config.captionBold} onChange={(v) => setConfig((c) => ({ ...c, captionBold: v }))} />
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-[11px] text-light-onSurface/45 dark:text-white/35">Sombra</span>
                  <Toggle checked={config.captionShadow} onChange={(v) => setConfig((c) => ({ ...c, captionShadow: v }))} />
                </div>
              </>
            )}
          </div>

          {captions.segments.length > 0 && (
            <button
              onClick={() => downloadBlob(new Blob([JSON.stringify(captions)], { type: "application/json" }), "captions.json")}
              className="mt-3 flex items-center gap-1.5 text-xs text-primary hover:underline"
            >
              <Download size={12} /> Exportar legendas
            </button>
          )}
        </SectionCard>
      </div>
    </div>
  );
}
