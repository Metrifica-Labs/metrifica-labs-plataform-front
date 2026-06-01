-- Migra todos os agentes e squads para Anthropic (claude-haiku-4-5)
UPDATE agent_definitions
SET llm_provider = 'anthropic',
    llm_model    = 'claude-haiku-4-5';

UPDATE squad_definitions
SET orchestrator_provider = 'anthropic',
    orchestrator_model    = 'claude-haiku-4-5';
