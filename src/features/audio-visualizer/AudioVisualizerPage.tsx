import { useEffect, useRef, useState } from "react";
import { AudioVisualizerEngine } from "@/features/audio-visualizer/audio-visualizer-engine";
import { createAudioVisualizerConfig, VIDEO_ASPECTS } from "@/features/audio-visualizer/audio-visualizer-config";
import { EMPTY_CAPTIONS, parseCaptions, type Captions } from "@/features/audio-visualizer/captions";
import { transcribeAudio } from "@/features/audio-visualizer/transcription.service";
import { downloadBlob } from "@/features/audio-visualizer/web-download";
import { listPresetNames, savePreset, loadPreset, deletePreset } from "@/features/audio-visualizer/audio-visualizer-presets";
import { pickImageDataUrl } from "@/shared/lib/pick-image";
import { UploadsSection } from "@/features/audio-visualizer/UploadsSection";
import { PresetsSection } from "@/features/audio-visualizer/PresetsSection";
import { FormatSection, RingControlsSection, CenterImageSection } from "@/features/audio-visualizer/RingControlsSection";
import { BackgroundSection } from "@/features/audio-visualizer/BackgroundSection";
import { CaptionsSection } from "@/features/audio-visualizer/CaptionsSection";

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

  function handleExportCaptions() {
    downloadBlob(new Blob([JSON.stringify(captions)], { type: "application/json" }), "captions.json");
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

        <UploadsSection
          audioUrl={audioUrl}
          isPlaying={isPlaying}
          isRecording={isRecording}
          isTranscribing={isTranscribing}
          pendingAudioFile={pendingAudioFile}
          onFileUpload={handleFileUpload}
          onCaptionsUpload={handleCaptionsUpload}
          onTogglePlay={togglePlay}
          onToggleRecording={toggleRecording}
          onRetranscribe={() => pendingAudioFile && runTranscription(pendingAudioFile)}
        />
      </div>

      <div className="w-[320px] shrink-0 space-y-4 overflow-y-auto border-l border-light-border bg-light-surface p-4 dark:border-dark-border dark:bg-dark-surface">
        <PresetsSection
          presetNames={presetNames}
          selectedPreset={selectedPreset}
          presetNameInput={presetNameInput}
          onSelectPreset={handleSelectPreset}
          onPresetNameInputChange={setPresetNameInput}
          onSavePreset={handleSavePreset}
          onDeletePreset={handleDeletePreset}
        />

        <FormatSection config={config} onConfigChange={setConfig} />

        <RingControlsSection config={config} onConfigChange={setConfig} />

        <CenterImageSection
          config={config}
          onConfigChange={setConfig}
          onPickCenterImage={handleCenterImagePick}
          onClearCenterImage={() => {
            setConfig((c) => ({ ...c, centerImageUrl: null }));
            engineRef.current?.setCenterImage(null);
          }}
        />

        <BackgroundSection
          config={config}
          onConfigChange={setConfig}
          onPickBackgroundImage={handleBackgroundImagePick}
          onClearBackgroundImage={() => {
            setConfig((c) => ({ ...c, backgroundImageUrl: null }));
            engineRef.current?.setBackgroundImage(null);
          }}
        />

        <CaptionsSection
          config={config}
          captions={captions}
          onConfigChange={setConfig}
          onExportCaptions={handleExportCaptions}
        />
      </div>
    </div>
  );
}
