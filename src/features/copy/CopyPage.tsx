import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Send, Plus, Trash2, Users2 } from "lucide-react";
import { useOrgStore } from "@/core/org/org-store";
import { fetchPersonas, createPersona, deletePersona } from "@/features/copy/personas.repository";
import { useCopyChat } from "@/features/copy/useCopyChat";
import type { PersonaModel } from "@/features/copy/persona-model";
import { Markdown } from "@/shared/components/Markdown";
import { cn } from "@/shared/lib/cn";
import { EmptyState } from "@/shared/components/ui/Card";
import { Input, } from "@/shared/components/ui/Field";
import { IconButton } from "@/shared/components/ui/Button";

type Tab = "personas" | "tools";

export function CopyPage() {
  const [tab, setTab] = useState<Tab>("personas");
  const [selectedPersona, setSelectedPersona] = useState<PersonaModel | null>(null);
  const orgId = useOrgStore((s) => s.activeOrgId);
  const queryClient = useQueryClient();

  const personasQuery = useQuery({
    queryKey: ["personas", orgId],
    queryFn: () => fetchPersonas(orgId!),
    enabled: !!orgId,
  });

  const avatarChat = useCopyChat({ agentSlug: "copy-avatar", orgId });
  const toolsChat = useCopyChat({
    agentSlug: "copy-tools",
    orgId,
    personaContext: selectedPersona?.content,
    personaId: selectedPersona?.id,
  });

  const [input, setInput] = useState("");

  const removePersona = useMutation({
    mutationFn: deletePersona,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["personas", orgId] });
      setSelectedPersona(null);
    },
  });

  const saveFromChat = useMutation({
    mutationFn: async () => {
      const sheet = await avatarChat.generatePersonaSheet();
      return createPersona(orgId!, `Personagem ${new Date().toLocaleDateString("pt-BR")}`, sheet);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["personas", orgId] });
      avatarChat.clear();
    },
  });

  function handleSend() {
    if (!input.trim()) return;
    const chat = tab === "personas" ? avatarChat : toolsChat;
    void chat.send(input);
    setInput("");
  }

  const activeChat = tab === "personas" ? avatarChat : toolsChat;

  return (
    <div className="flex h-full">
      <div className="w-64 shrink-0 overflow-y-auto border-r border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card">
        <h2 className="mb-3 px-1 font-mono text-[11px] font-medium uppercase tracking-wider text-light-onSurface/35 dark:text-white/30">
          Personagens
        </h2>
        {personasQuery.data?.length === 0 && (
          <EmptyState icon={<Users2 size={16} />} title="Nenhum personagem" description="Crie um na aba ao lado." />
        )}
        <div className="space-y-0.5">
          {personasQuery.data?.map((persona) => (
            <div
              key={persona.id}
              className={cn(
                "group flex items-center justify-between rounded-md px-2.5 py-1.5 text-[13px]",
                selectedPersona?.id === persona.id
                  ? "bg-primary-soft text-primary"
                  : "text-light-onSurface/65 hover:bg-light-onSurface/5 dark:text-white/55 dark:hover:bg-white/5"
              )}
            >
              <button
                onClick={() => {
                  setSelectedPersona(persona);
                  setTab("tools");
                }}
                className="flex-1 truncate text-left"
              >
                {persona.name}
              </button>
              <button
                onClick={() => removePersona.mutate(persona.id)}
                className="text-red-500/50 opacity-0 transition-opacity group-hover:opacity-100 hover:text-red-500"
              >
                <Trash2 size={12} />
              </button>
            </div>
          ))}
        </div>
      </div>

      <div className="flex flex-1 flex-col p-6">
        <div className="mb-5 flex items-center gap-1.5 rounded-full border border-light-border bg-light-raised p-1 dark:border-dark-border dark:bg-dark-raised">
          <button
            onClick={() => setTab("personas")}
            className={cn(
              "rounded-full px-3 py-1.5 text-[13px] font-medium transition-colors",
              tab === "personas"
                ? "bg-primary text-white shadow-soft"
                : "text-light-onSurface/55 hover:text-light-onSurface dark:text-white/45"
            )}
          >
            Criar personagem
          </button>
          <button
            onClick={() => setTab("tools")}
            disabled={!selectedPersona}
            className={cn(
              "rounded-full px-3 py-1.5 text-[13px] font-medium transition-colors disabled:opacity-40",
              tab === "tools"
                ? "bg-primary text-white shadow-soft"
                : "text-light-onSurface/55 hover:text-light-onSurface dark:text-white/45"
            )}
          >
            Ferramentas {selectedPersona ? `— ${selectedPersona.name}` : ""}
          </button>
          {tab === "personas" && avatarChat.state.messages.length > 0 && (
            <button
              onClick={() => saveFromChat.mutate()}
              className="ml-auto flex items-center gap-1 px-2 text-xs font-medium text-primary"
            >
              <Plus size={12} /> Salvar como personagem
            </button>
          )}
        </div>

        <div className="flex-1 space-y-3 overflow-y-auto">
          {activeChat.state.messages.length === 0 && (
            <EmptyState
              title={tab === "personas" ? "Descreva um personagem" : "Converse com a persona"}
              description="As mensagens aparecerão aqui."
            />
          )}
          {activeChat.state.messages.map((msg) => (
            <div key={msg.id} className={msg.role === "user" ? "text-right" : "text-left"}>
              <div
                className={cn(
                  "inline-block max-w-[85%] rounded-xl px-3.5 py-2.5 text-sm",
                  msg.role === "user"
                    ? "bg-primary text-white"
                    : "border border-light-border bg-light-card dark:border-dark-border dark:bg-dark-raised"
                )}
              >
                {msg.isStreaming && !msg.content ? (
                  <span className="inline-flex gap-1">
                    <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-current opacity-60 [animation-delay:-0.3s]" />
                    <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-current opacity-60 [animation-delay:-0.15s]" />
                    <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-current opacity-60" />
                  </span>
                ) : (
                  <Markdown content={msg.content} />
                )}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-4 flex items-center gap-2">
          <Input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSend()}
            disabled={activeChat.state.isGenerating}
            placeholder={tab === "personas" ? "Descreva o personagem..." : "Peça uma copy contextualizada..."}
            className="flex-1"
          />
          <IconButton
            onClick={handleSend}
            disabled={activeChat.state.isGenerating || !input.trim()}
            className="h-9 w-9 bg-primary text-white hover:bg-primary-hover hover:text-white disabled:opacity-50"
          >
            <Send size={15} />
          </IconButton>
        </div>
      </div>
    </div>
  );
}
