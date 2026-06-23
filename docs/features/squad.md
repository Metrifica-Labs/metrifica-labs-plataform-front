# Squad — Orquestração Multi-Agente (`/squads/:slug`)

## Aba Execução
- [ ] Iniciar nova run de squad
- [ ] Exibir timeline de agentes (status, pensamento, tool calls, output em markdown)
- [ ] Auto-scroll do painel de pensamento
- [ ] Retomar execução ("Continuar execução")
- [ ] Reiniciar execução

## Aba Calibração
- [ ] Testar cada ferramenta externa configurada por agente
- [ ] Exibir status agregado ("Tudo OK" / "Falhas detectadas")

## Histórico
- [ ] Listar runs anteriores (`squad_runs` / `agent_runs`)
- [ ] Restaurar run histórica para a view ativa

## Polling
- [ ] Polling do servidor a cada 3–5s (mais rápido se agente ativo)
- [ ] Avançar pipeline via Edge Function de "step" sem bloquear cliente
