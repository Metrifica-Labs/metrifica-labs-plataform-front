import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Send, Plus, Trash2 } from "lucide-react";
import { useOrgStore } from "@/core/org/org-store";
import { fetchPersonas, createPersona, deletePersona } from "@/features/copy/personas.repository";
import { useCopyChat } from "@/features/copy/useCopyChat";
import type { PersonaModel } from "@/features/copy/persona-model";
import { Markdown } from "@/shared/components/Markdown";

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
        <h2 className="mb-3 text-xs font-semibold uppercase tracking-wide text-light-onSurface/40 dark:text-white/40">
          Personagens
        </h2>
        <div className="space-y-1">
          {personasQuery.data?.map((persona) => (
            <div
              key={persona.id}
              className={`flex items-center justify-between rounded-md px-2 py-1.5 text-sm ${
                selectedPersona?.id === persona.id ? "bg-primary/10 text-primary" : "text-light-onSurface/70 dark:text-white/60"
              }`}
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
              <button onClick={() => removePersona.mutate(persona.id)} className="text-red-500/50">
                <Trash2 size={12} />
              </button>
            </div>
          ))}
        </div>
      </div>

      <div className="flex flex-1 flex-col p-6">
        <div className="mb-4 flex items-center gap-2">
          <button
            onClick={() => setTab("personas")}
            className={`rounded-full px-3 py-1 text-xs ${tab === "personas" ? "bg-primary/10 text-primary" : "text-light-onSurface/50"}`}
          >
            Criar personagem
          </button>
          <button
            onClick={() => setTab("tools")}
            disabled={!selectedPersona}
            className={`rounded-full px-3 py-1 text-xs disabled:opacity-40 ${tab === "tools" ? "bg-primary/10 text-primary" : "text-light-onSurface/50"}`}
          >
            Ferramentas {selectedPersona ? `— ${selectedPersona.name}` : ""}
          </button>
          {tab === "personas" && avatarChat.state.messages.length > 0 && (
            <button onClick={() => saveFromChat.mutate()} className="ml-auto flex items-center gap-1 text-xs text-primary">
              <Plus size={12} /> Salvar como personagem
            </button>
          )}
        </div>

        <div className="flex-1 space-y-3 overflow-y-auto">
          {activeChat.state.messages.map((msg) => (
            <div key={msg.id} className={msg.role === "user" ? "text-right" : "text-left"}>
              <div
                className={`inline-block max-w-[85%] rounded-lg px-3 py-2 text-sm ${
                  msg.role === "user" ? "bg-primary text-white" : "bg-light-onSurface/5 dark:bg-white/5"
                }`}
              >
                {msg.isStreaming && !msg.content ? "..." : <Markdown content={msg.content} />}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-4 flex items-center gap-2">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && handleSend()}
            disabled={activeChat.state.isGenerating}
            placeholder={tab === "personas" ? "Descreva o personagem..." : "Peça uma copy contextualizada..."}
            className="flex-1 rounded-md border border-light-border-strong bg-transparent px-3 py-2 text-sm outline-none focus:border-primary disabled:opacity-50 dark:border-dark-border"
          />
          <button
            onClick={handleSend}
            disabled={activeChat.state.isGenerating || !input.trim()}
            className="flex items-center justify-center rounded-md bg-primary p-2 text-white disabled:opacity-50"
          >
            <Send size={16} />
          </button>
        </div>
      </div>
    </div>
  );
}
