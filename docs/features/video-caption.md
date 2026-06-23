# Video Caption — Editor de Legendas e Cortes (`/video-caption`)

## Upload e Processamento
- [ ] Upload de vídeo
- [ ] Transcrição via Whisper (API local Node localhost:3002)
- [ ] Sugestão automática de cortes pelo backend
- [ ] Sugestão automática de legendas pelo backend

## Aba Cortes
- [ ] Criar corte manual
- [ ] Editar corte existente
- [ ] Excluir corte
- [ ] Aplicar cortes sugeridos

## Aba Legendas
- [ ] Detectar gaps de fala sem legenda
- [ ] Regenerar legendas de gap
- [ ] Identificar legendas com mais de 2 linhas
- [ ] Reotimizar/dividir legendas longas

## Aba Segmentos
- [ ] Gerenciar clipes "outro" anexados na exportação
- [ ] Visualizar trechos mantidos após os cortes

## Aba Análise
- [ ] Exibir notas de IA sobre a edição

## Aba Estilo
- [ ] Configurar fonte da legenda
- [ ] Configurar tamanho da legenda
- [ ] Configurar posição da legenda
- [ ] Configurar cor do texto
- [ ] Configurar cor do fundo da legenda

## Reflow e Exportação
- [ ] Reflow inteligente de legendas (respeita pausas > 0.7s)
- [ ] Preservar legendas editadas manualmente (sem timing)
- [ ] Exportar vídeo completo (corte + legenda aplicados)
- [ ] Exportar segmentos individuais
- [ ] Rotação em incrementos de 90°
- [ ] Converter estilo para proporções independentes de resolução antes de enviar ao backend
