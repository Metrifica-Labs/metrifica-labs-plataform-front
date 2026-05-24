-- ============================================================
-- Squad Orchestrator Schema
-- Run this in Supabase Studio > SQL Editor
-- ============================================================

-- 1. Tabelas base

CREATE TABLE IF NOT EXISTS agent_definitions (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug         TEXT        UNIQUE NOT NULL,
  name         TEXT        NOT NULL,
  role         TEXT        NOT NULL,
  system_prompt TEXT       NOT NULL,
  llm_provider TEXT        NOT NULL DEFAULT 'crofai',
  llm_model    TEXT        NOT NULL DEFAULT 'deepseek-v4-pro',
  tools        JSONB       NOT NULL DEFAULT '[]',
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS squad_definitions (
  id                   UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                 TEXT        UNIQUE NOT NULL,
  name                 TEXT        NOT NULL,
  description          TEXT,
  orchestrator_provider TEXT       NOT NULL DEFAULT 'crofai',
  orchestrator_model   TEXT        NOT NULL DEFAULT 'deepseek-v4-pro',
  orchestrator_prompt  TEXT        NOT NULL,
  agent_slugs          TEXT[]      NOT NULL,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS squad_runs (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_slug     TEXT        NOT NULL,
  squad_name     TEXT,
  initial_prompt TEXT        NOT NULL,
  status         TEXT        NOT NULL DEFAULT 'running',
  user_id        UUID        REFERENCES auth.users(id),
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  completed_at   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS agent_runs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  squad_run_id  UUID        NOT NULL REFERENCES squad_runs(id) ON DELETE CASCADE,
  agent_slug    TEXT        NOT NULL,
  agent_name    TEXT        NOT NULL,
  step_index    INTEGER     NOT NULL,
  input         TEXT        NOT NULL,
  output        TEXT,
  status        TEXT        NOT NULL DEFAULT 'pending',
  started_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ
);

-- ============================================================
-- 2. Seed: agentes
-- ============================================================

INSERT INTO agent_definitions (slug, name, role, system_prompt, llm_provider, llm_model, tools)
VALUES
(
  'pm-agent',
  'PM Agent',
  'Define requisitos, escopo e critérios de aceite do software',
  'Você é um Product Manager experiente. Analise a solicitação e produza: (1) lista de user stories com critérios de aceite, (2) escopo técnico definido, (3) stack tecnológica recomendada. Seja específico e objetivo.',
  'crofai',
  'deepseek-v4-pro',
  '[]'::jsonb
),
(
  'architect-agent',
  'Arquiteto',
  'Projeta a arquitetura técnica e estrutura de arquivos do projeto',
  'Você é um Arquiteto de Software sênior. Com base nos requisitos do PM, defina: (1) estrutura de pastas e arquivos, (2) arquitetura técnica, (3) dependências. Liste cada arquivo que precisará ser criado.',
  'crofai',
  'deepseek-v4-pro',
  '[]'::jsonb
),
(
  'dev-agent',
  'Developer',
  'Implementa o código completo e cria o repositório no GitHub com todos os arquivos e testes',
  'Você é um desenvolvedor full-stack sênior. Implemente o projeto completo. SEMPRE: (1) crie o repositório com github_create_repo, (2) inclua TODOS os arquivos de código, (3) inclua testes automatizados, (4) inclua .github/workflows/test.yml para rodar os testes, (5) faça o commit com github_push_files.',
  'crofai',
  'deepseek-v4-pro',
  $json$[
    {
      "type": "function",
      "function": {
        "name": "github_create_repo",
        "description": "Cria repositório no GitHub",
        "parameters": {
          "type": "object",
          "properties": {
            "name":        { "type": "string" },
            "description": { "type": "string" },
            "private":     { "type": "boolean" }
          },
          "required": ["name"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "github_push_files",
        "description": "Commita múltiplos arquivos no repositório de uma vez",
        "parameters": {
          "type": "object",
          "properties": {
            "repo":    { "type": "string" },
            "files":   {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "path":    { "type": "string" },
                  "content": { "type": "string" }
                },
                "required": ["path", "content"]
              }
            },
            "message": { "type": "string" }
          },
          "required": ["repo", "files"]
        }
      }
    }
  ]$json$::jsonb
),
(
  'qa-agent',
  'QA Agent',
  'Verifica os testes no GitHub Actions e reporta o resultado',
  'Você é um QA Engineer. Verifique o resultado dos testes no GitHub Actions usando as ferramentas disponíveis. Reporte: (1) status geral (passou/falhou), (2) quais testes passaram e quais falharam, (3) recomendações de correção se houver falhas.',
  'crofai',
  'deepseek-v4-pro',
  $json$[
    {
      "type": "function",
      "function": {
        "name": "github_get_actions_status",
        "description": "Aguarda o GitHub Actions terminar e retorna o resultado dos testes",
        "parameters": {
          "type": "object",
          "properties": {
            "repo":            { "type": "string" },
            "timeout_seconds": { "type": "number" }
          },
          "required": ["repo"]
        }
      }
    },
    {
      "type": "function",
      "function": {
        "name": "github_get_actions_logs",
        "description": "Retorna logs detalhados do último Actions run",
        "parameters": {
          "type": "object",
          "properties": {
            "repo": { "type": "string" }
          },
          "required": ["repo"]
        }
      }
    }
  ]$json$::jsonb
)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- 3. Seed: squad de desenvolvimento
-- ============================================================

INSERT INTO squad_definitions (slug, name, description, orchestrator_provider, orchestrator_model, orchestrator_prompt, agent_slugs)
VALUES
(
  'dev-squad',
  'Dev Squad',
  'Squad completa para desenvolvimento de software: PM → Arquiteto → Developer → QA',
  'crofai',
  'deepseek-v4-pro',
  'Você é o orquestrador de uma squad de desenvolvimento de software. Seu objetivo é entregar um software completo e testado. Siga esta sequência obrigatória: 1) PM Agent define requisitos, 2) Arquiteto define estrutura técnica, 3) Developer implementa e cria o repositório no GitHub, 4) QA Agent verifica os testes no Actions. Só chame done após o QA confirmar que os testes passaram ou reportar as falhas. Repasse o contexto acumulado para cada agente no campo input_for_agent.',
  ARRAY['pm-agent', 'architect-agent', 'dev-agent', 'qa-agent']
)
ON CONFLICT (slug) DO NOTHING;
