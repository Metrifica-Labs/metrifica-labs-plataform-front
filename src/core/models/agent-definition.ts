export interface AgentDefinitionModel {
  id: string;
  slug: string;
  name: string;
  role: string;
  systemPrompt: string;
  llmProvider: string;
  llmModel: string;
  toolNames: string[];
}

export function agentDefinitionFromRow(row: {
  id: string;
  slug: string;
  name: string;
  role: string;
  system_prompt: string;
  llm_provider: string;
  llm_model: string;
  tool_names: string[] | null;
}): AgentDefinitionModel {
  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    role: row.role,
    systemPrompt: row.system_prompt,
    llmProvider: row.llm_provider,
    llmModel: row.llm_model,
    toolNames: row.tool_names ?? [],
  };
}
