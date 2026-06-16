# Módulo Audio Visualizer

Gera um vídeo de **audio visualizer** (espectro circular com imagem central e
legenda sincronizada) a partir de um arquivo de áudio, totalmente no navegador,
com opção de exportar/baixar o resultado.

Rota: `/audio-visualizer` · Item na sidebar: **Audio Visualizer**.

## Como funciona

Tudo roda **client-side** (sem backend):

1. O áudio é decodificado pela **Web Audio API** (`AnalyserNode`) para extrair o
   espectro de frequência em tempo real.
2. Um `<canvas>` HTML é desenhado a cada frame (anel de barras + imagem central
   + fundo + legenda) e embutido no Flutter via `HtmlElementView` (preview ao
   vivo).
3. A exportação usa **`MediaRecorder`**: o stream do canvas
   (`canvas.captureStream`) é combinado com o áudio (`MediaStreamAudioDestinationNode`)
   e gravado em **`.webm`** (VP9/Opus quando suportado). Por ser gravação em
   tempo real, o export leva o mesmo tempo do áudio — não troque de aba durante a
   gravação.

## Configurável

- **Formato**: proporção/resolução (quadrado, vertical/story, horizontal) e FPS.
- **Anel**: cor inicial/final (gradiente), nº de barras, raio, largura e altura
  das barras, sensibilidade, rotação e brilho (glow).
- **Imagem central**: upload, tamanho, recorte circular e pulsar com o áudio.
- **Fundo**: cor sólida, gradiente ou imagem.
- **Legenda**: modo (frase completa / karaoke / palavra), fonte, cores
  (texto e destaque), posição, palavras por linha, negrito e sombra.

## Legenda (transcrição com Whisper)

A legenda sincronizada vem de um JSON com timestamps por palavra. Gere com o
script Python incluído:

```bash
pip install -r scripts/requirements-transcribe.txt   # requer ffmpeg instalado
python scripts/transcribe.py meu_audio.mp3 small      # modelo: tiny|base|small|medium|large
# gera meu_audio.captions.json
```

No módulo, faça upload de **(1)** o áudio e **(2)** o `*.captions.json`. O modo
*karaoke* destaca a palavra atual conforme o áudio toca.

> Também é aceito `.srt` / `.vtt` como fallback (sem destaque por palavra).

## Limitações

- O formato de saída é **`.webm`** (limitação do `MediaRecorder` no navegador).
  Para `.mp4`, converta depois (ex.: `ffmpeg -i saida.webm saida.mp4`).
- A gravação acontece em tempo real; áudios longos levam o tempo correspondente.
