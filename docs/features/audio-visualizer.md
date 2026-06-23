# Audio Visualizer — Gerador de Vídeo com Visualizador (`/audio-visualizer`)

## Upload e Configuração de Mídia
- [ ] Upload de arquivo de áudio
- [ ] Upload de imagem central opcional
- [ ] Configurar fundo sólido, gradiente ou imagem
- [ ] Upload de legendas em JSON, SRT ou VTT
- [ ] Transcrição automática de áudio (Edge Function `transcribe-audio`)

## Visualizador de Frequência
- [ ] Anel circular de barras de frequência (Web Audio API AnalyserNode)
- [ ] Configurar cor das barras
- [ ] Configurar contagem de barras
- [ ] Configurar raio e espessura
- [ ] Configurar sensibilidade
- [ ] Configurar velocidade de rotação
- [ ] Configurar brilho

## Legendas
- [ ] Modo segmento completo
- [ ] Modo karaokê (palavra destacada dentro da frase)
- [ ] Modo palavra a palavra

## Exportação
- [ ] Exportar em formato quadrado
- [ ] Exportar em formato retrato/story
- [ ] Exportar em formato paisagem
- [ ] FPS configurável
- [ ] Re-codificação para MP4 de taxa constante via ffmpeg.wasm
- [ ] Fallback: entrega arquivo bruto com aviso ao usuário se a normalização falhar

## Presets
- [ ] Salvar preset de configuração por organização (`audio_visualizer_presets`)
- [ ] Carregar preset salvo
