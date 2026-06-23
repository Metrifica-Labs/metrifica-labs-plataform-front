# Generation — Painel de Geração por IA (embutido em Flow)

## Geração de Texto
- [ ] Seleção de template de referência (scaffold) por flow (`proposal_templates`)
- [ ] Navegar entre placeholders `[[campo]]` via Tab
- [ ] Geração via streaming (Edge Function `run-flow`)
- [ ] Exibir seções de "pensamento" (thinking) durante geração
- [ ] Refinamento conversacional com histórico de turnos

## Geração de Imagem
- [ ] Extrair prompts de imagem de blocos de código no output
- [ ] Escolher proporção (1:1, 4:5, 9:16, 16:9)
- [ ] Gerar imagem via Edge Function `generate-image` (Higgsfield Soul)

## Post Automático
- [ ] Auto-criar rascunho de post (`posts`) a cada geração concluída
- [ ] Extrair `pillar` do texto por regex (`PILAR:\s*(\S+)`)
- [ ] Atualizar `image_url` do rascunho ao gerar imagem

## Histórico e Exportação
- [ ] Histórico de gerações (até 50 entradas) com painel lateral
- [ ] Restaurar geração histórica
- [ ] Exportar output como HTML estilizado para download
