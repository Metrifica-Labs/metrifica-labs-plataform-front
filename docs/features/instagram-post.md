# Instagram Post — Editor Visual de Carrossel (`/instagram-post`)

## Canvas e Exportação
- [x] Canvas fixo 432x540 (proporção 4:5)
- [x] Exportar slide em PNG (pixelRatio 2.5 → ~1080x1350px)

## Layouts de Slide
- [x] Type 1 – Text Post (header de perfil, imagem, contador i/total)
- [x] Type 2 – Image Cover full-bleed (4 variantes: logoMid, logoTop, subtitleTop, logoTopInline)
- [x] Type 3 – Text Grid (imagem de fundo + grade 2x2 com negrito/alinhamento independentes)
- [x] Type 4 – Image Stack (duas imagens 50/50 com título/subtítulo sobrepostos)
- [x] Type 5 – Freestyle (sem header de perfil, posição de imagem "no meio")

## Marcação e Estilo
- [x] Linguagem de marcação inline: [hl], [hl=#RRGGBB], [c], [c=#RRGGBB], [b], [i], [u]
- [x] Selecionar entre 13 fontes do Google Fonts
- [x] Aplicar 5 presets de estilo (Clean, Dark, Editorial, Bold Blue, Punch)
- [x] Cores com precedência: override por slide → cor genérica → cor global

## Histórico e Persistência
- [x] Histórico local de carrosséis (SharedPreferences, 15 entradas)
- [x] Auto-save de estilo a cada 60s

## Conexão e Publicação
- [x] Conectar conta Instagram pessoal (OAuth via Composio) — frontend: UI + `instagram-connection.ts` + edge function `connect-instagram`
- [x] Exibir status da conexão (pendente/ativo/erro) — polling a cada 3s enquanto pendente
- [x] Upload de imagens exportadas para bucket `instagram-publish-media` — `instagram-publish.ts`
- [x] Publicação imediata (Edge Function `publish-instagram-post`) — chamada após upload
- [x] Agendamento de publicação (data/hora) processado por cron — edge function `schedule-instagram-post` + tabela `instagram_scheduled_posts`

> **Backend pendente:** as Edge Functions `connect-instagram`, `publish-instagram-post` e `schedule-instagram-post` precisam ser criadas no Supabase. A migração `20260622030000_instagram_connections.sql` cria o bucket e as tabelas necessárias.
