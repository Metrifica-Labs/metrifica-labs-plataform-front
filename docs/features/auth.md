# Auth — Autenticação e Multi-tenancy

- [ ] Login com email e senha (`supabase.auth.signInWithPassword`)
- [ ] Mapeamento de erros para mensagens amigáveis em PT-BR
- [ ] Tela de org-picker: lista de organizations do usuário
- [ ] Auto-seleção de org única ou salva em localStorage
- [ ] Navegação por teclado (setas + Enter) na lista de orgs
- [ ] Redirecionamento pós-seleção para `/flows/<slug>` ou `/squads/dev-squad`
- [ ] Tela de erro fixa para usuário sem nenhuma org
- [ ] Troca de empresa pelo rodapé da sidebar (PopupMenuButton)
- [ ] Feature flags por org via `organizations.config.enabled_features`
- [ ] Visibilidade granular de flows por org (`organization_flows`)
- [ ] Visibilidade granular de modules por org (`organization_modules`)
- [ ] Logout (`supabase.auth.signOut` + redirect `/login`)
