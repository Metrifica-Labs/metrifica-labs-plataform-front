-- Corrige a geração de imagens de carrossel: o modelo gerava apenas 1 prompt de
-- imagem porque os módulos descreviam o processo no singular ("escolha o template,
-- copie o prompt"). A UI já fatia cada bloco ``` em um slide, então basta instruir
-- o modelo a emitir UM prompt completo por slide, cada um em seu próprio bloco.
--
-- Idempotente: só anexa a seção se ela ainda não estiver presente.

-- 1. Módulo do template de prompt de imagem
UPDATE modules
SET content = content || E'\n\n---\n\n'
  || E'## Regra obrigatória para carrosséis (um prompt por slide)\n\n'
  || E'Quando o conteúdo for um carrossel com N slides, gere N prompts de imagem '
  || E'completos — UM para CADA slide, na ordem dos slides. Nunca gere um único '
  || E'prompt cobrindo só o slide principal.\n\n'
  || E'Para cada slide:\n'
  || E'- Escolha o template visual adequado ao papel daquele slide (hook, dado, '
  || E'dor, virada, solução, apresentação, CTA) usando o "Guia rápido de qual '
  || E'template usar".\n'
  || E'- Preencha todos os campos entre [COLCHETES] com o conteúdo real do slide.\n'
  || E'- Escreva o prompt em inglês.\n\n'
  || E'Formato de saída obrigatório: cada prompt deve vir isolado em seu próprio '
  || E'bloco de código (``` ... ```), contendo SOMENTE o prompt. Nada de juntar '
  || E'vários slides no mesmo bloco. N slides = N blocos de código, na ordem.'
WHERE slug = 'template-prompt-imagem'
  AND content NOT LIKE '%Regra obrigatória para carrosséis (um prompt por slide)%';

-- 2. Módulo de regras de post (reforço no contexto da estrutura do carrossel)
UPDATE modules
SET content = content || E'\n\n## Imagens do carrossel\n\n'
  || E'Gere um prompt de imagem completo para CADA slide do carrossel, na ordem, '
  || E'cada prompt em seu próprio bloco de código (``` ... ```). Use o módulo '
  || E'"Template de Prompt de Imagem" para escolher o template de cada slide. '
  || E'Um carrossel de 8 slides deve produzir 8 prompts de imagem.'
WHERE slug = 'regras-post-instagram'
  AND content NOT LIKE '%Imagens do carrossel%';
