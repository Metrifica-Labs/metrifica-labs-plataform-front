# Fase 8 — Audio Visualizer

Equivalente a `lib/features/audio_visualizer/*`. Módulo 100% client-side, sem chamadas de rede — na prática **mais simples de portar que os outros módulos**, porque depende só de Web APIs nativas (Web Audio API, Canvas 2D, MediaRecorder) que o Flutter Web já acessava via interop (`package:web`). Em React, a mesma classe pode ser portada quase literalmente para TypeScript, removendo a camada de interop.

## 8.1 Configuração

Equivalente a `audio_visualizer_config.dart`:
```ts
type VideoAspect = 'square' | 'portrait' | 'landscape'; // 1080x1080 | 1080x1920 | 1920x1080
type BackgroundType = 'solid' | 'gradient' | 'image';
type CaptionMode = 'segment' | 'karaoke' | 'word';

interface AudioVisualizerConfig {
  aspect: VideoAspect; fps: number;
  // anel de barras
  barColorStart: string; barColorEnd: string; barCount: number; barRadiusFraction: number;
  barMaxLength: number; barWidth: number; sensitivity: number; rotationSpeed: number; glow: boolean;
  // imagem central
  centerImageBytes?: Uint8Array; centerImageScaleFraction: number; centerImageCircular: boolean; centerImagePulse: boolean;
  // fundo
  backgroundType: BackgroundType; backgroundColor1: string; backgroundColor2: string; backgroundImageBytes?: Uint8Array;
  // legenda
  captionsEnabled: boolean; captionMode: CaptionMode; captionFontSize: number; captionColor: string;
  captionHighlightColor: string; captionBottomOffsetFraction: number; captionMaxWords: number;
  captionShadow: boolean; captionBold: boolean;
}
```
(~25 campos no total, imutável/objeto plano — sem necessidade de classe).

## 8.2 Parser de legendas — `captions.ts`

Equivalente a `captions.dart`, aceita 2 formatos:
1. **JSON customizado**: `{segments: [{start, end, text, words: [{word, start, end}]}], words: [...]}` — gerado por script externo `scripts/transcribe.py` (Whisper, fora do escopo desta migração — só consumir o formato).
2. **SRT/WebVTT simples**: regex de timestamp `HH:MM:SS,mmm --> HH:MM:SS,mmm`; sem granularidade por palavra — cada bloco se torna 1 "word" sintética cobrindo a frase inteira.

## 8.3 Utilitários de arquivo

Equivalente a `web_download.dart` — já cobertos pelos utilitários genéricos da fase 2 (`downloadFile`, `pickFile`); não precisa de implementação própria.

## 8.4 Engine — `AudioVisualizerEngine` (TypeScript)

Equivalente a `audio_visualizer_engine.dart` — **a peça mais complexa e self-contained do projeto**, mas a mais portável 1:1, pois não há lógica de negócio específica do Flutter.

### Setup
- `<canvas>` real via ref do React (sem necessidade de `platformViewRegistry`/`HtmlElementView` — essa camada de interop do Flutter Web desaparece inteiramente em React).
- Dimensões do canvas conforme `aspect` (1080×1080 / 1080×1920 / 1920×1080).

### Pipeline de áudio (Web Audio API)
- `new AudioContext()`.
- Carregar arquivo de áudio como Blob URL num elemento `<audio>`.
- `audioContext.createMediaElementSource(audioEl)` → conectar a um `AnalyserNode` (`fftSize=512`, `smoothingTimeConstant=0.8`) → conectar ao `audioContext.destination` (para tocar) **e** a um `MediaStreamAudioDestinationNode` (para permitir gravar o áudio junto do vídeo).
- Eventos do `<audio>`: `timeupdate` (progresso), `ended` (finaliza, incluindo parar gravação se ativa), `play`/`pause` (atualiza callbacks expostos: `onStateChanged`, `onProgress`, `onRecordingChanged`, `onExportReady`).

### Loop de render (`requestAnimationFrame`)
A cada frame:
1. Calcular `dt` (delta time).
2. Atualizar rotação acumulada: `rotation += rotationSpeed * dt`.
3. Ler dados de frequência: `analyser.getByteFrequencyData(dataArray)`.
4. Calcular "pulse" (suavização exponencial): `pulse += (avg - pulse) * Math.min(1, dt * 8)`.
5. Desenhar em ordem: fundo → imagem central → anel de barras → legenda.

Sem áudio carregado: gerar onda senoidal sintética (`Math.sin(i*0.4 + t*2)`) como preview decorativo.

### Desenho do fundo
- `solid`: `ctx.fillRect`.
- `gradient`: `ctx.createLinearGradient` top-left → bottom-right, 2 stops.
- `image`: função `drawCover(ctx, img, canvasW, canvasH)` — centraliza e recorta mantendo aspect ratio (replicar exatamente a lógica de crop manual do `_drawCover` original).

### Desenho do anel de barras (espectro circular)
- Usar metade do espectro de frequência e espelhar para simetria.
- Para cada barra: `ctx.save(); ctx.rotate(angle); ctx.fillRect(-barW/2, -radius-len, barW, len); ctx.restore();`.
- Gradiente linear ao longo do comprimento da barra (`barColorStart` → `barColorEnd`).
- `glow`: aplicar `ctx.shadowColor`/`ctx.shadowBlur` antes de desenhar as barras.
- Rotação geral do anel acumulada ao longo do tempo (`rotation`, calculada no loop de render).

### Imagem central
- Escala pulsante: `scale = centerImagePulse ? 1 + pulse * 0.12 : 1`.
- Clip circular opcional: `ctx.arc(...); ctx.clip();` antes de desenhar.
- Desenhar via `drawCover`.
- Placeholder translúcido se não houver imagem central configurada.

### Legenda (3 modos)
- `word`: mostra só a palavra atual centralizada (busca por timestamp no array de words).
- `segment`: mostra a frase do segmento atual, com word-wrap manual (`fillWrapped`: quebra linhas medindo largura via `ctx.measureText`).
- `karaoke`: agrupa palavras em blocos de `captionMaxWords`, desenha o grupo horizontalmente centralizado, destacando a palavra ativa com `captionHighlightColor` (demais com `captionColor`). Busca da palavra ativa por timestamp com fallback para "última iniciada" (evita buracos visuais em silêncios).
- Sombra de texto opcional (`captionShadow`) via `ctx.shadowColor`/`shadowBlur`.

### Exportação de vídeo (gravação)
1. `canvas.captureStream(fps)` → gera `MediaStream` de vídeo a partir do canvas sendo desenhado em tempo real.
2. Combinar com o stream de áudio (`mediaStreamDestNode.stream`) num único `MediaStream` (`new MediaStream([...videoTrack, ...audioTrack])`).
3. `new MediaRecorder(combinedStream, { mimeType, videoBitsPerSecond: 8_000_000 })`.
   - Escolher `mimeType` por feature-detection: `MediaRecorder.isTypeSupported('video/webm;codecs=vp9,opus')` → fallback `vp8,opus` → fallback `webm` genérico.
4. Reiniciar áudio do zero (`audioEl.currentTime = 0`), começar a tocar + gravar simultaneamente.
5. Coletar chunks a cada 100ms (`recorder.start(100)`, evento `dataavailable`).
6. Ao `ended` do áudio (ou cancelamento manual): `recorder.stop()`.
7. No evento `stop`: concatenar blobs (`new Blob(chunks, {type: mimeType})`), ler como ArrayBuffer (`blob.arrayBuffer()`), expor via callback `onExportReady(bytes, mimeType)` — a página então dispara `downloadFile`.

### Estrutura recomendada em React
- Classe `AudioVisualizerEngine` quase idêntica ao original (sem interop), instanciada num `useRef` dentro de um hook `useAudioVisualizerEngine(canvasRef, config)`.
- Hook expõe estado reativo (`isPlaying`, `progress`, `isRecording`) via `useState` atualizado pelos callbacks da engine, e métodos imperativos (`play`, `pause`, `startExport`, `cancelExport`).
- Atualizar a `config` via `useEffect` chamando um método `engine.updateConfig(config)` (sem recriar a engine inteira a cada mudança de cor/slider).

## 8.5 Página — `audio_visualizer_page.dart`

- Pickers: áudio, legendas, imagem central, imagem de fundo (`pickFile` da fase 2).
- Controles de reprodução (play/pause), barra de progresso.
- Painel de configuração completo mapeado 1:1 aos campos de `AudioVisualizerConfig` (sliders, color pickers, selects).
- Botão de exportar: exibir aviso "não troque de aba" durante a gravação (a gravação depende do canvas estar sendo efetivamente renderizado — abas em background podem pausar `requestAnimationFrame` em alguns browsers).

## Critério de aceite da fase

- Carregar um áudio real + legendas (testar os dois formatos: JSON customizado e SRT) e validar sincronia visual da legenda nos 3 modos.
- Testar os 3 tipos de fundo (sólido, gradiente, imagem) e os 2 modos de imagem central (circular/não, com/sem pulso).
- Exportar um vídeo curto (~10-15s) e validar no player que áudio e vídeo estão sincronizados, com a resolução/aspect ratio corretos.
- Confirmar que trocar de aba durante a exportação não corrompe o resultado (ou documentar a mesma limitação do app atual, se for o caso).
- Testar nos browsers-alvo (Chrome/Edge garantido; validar `MediaRecorder`/`captureStream` em Firefox/Safari, que têm suporte historicamente mais instável a essas APIs).
