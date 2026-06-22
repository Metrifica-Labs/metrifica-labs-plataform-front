import { useEffect, useRef, useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Plus, Trash2, Users2 } from "lucide-react";
import { useOrgStore } from "@/core/org/org-store";
import { fetchPersonas, createPersona, deletePersona } from "@/features/copy/personas.repository";
import { useCopyChat } from "@/features/copy/useCopyChat";
import type { PersonaModel } from "@/features/copy/persona-model";
import { cn } from "@/shared/lib/cn";
import { EmptyState } from "@/shared/components/ui/Card";
import { Skeleton } from "@/shared/components/ui/Skeleton";
import { Tabs } from "@/shared/components/ui/Tabs";
import { ChatMessageBubble } from "@/shared/components/chat/ChatMessageBubble";
import { ChatComposer } from "@/shared/components/chat/ChatComposer";
import { useToast } from "@/shared/hooks/useToast";

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
  const toast = useToast();
  const lastAvatarError = useRef<string | null>(null);
  const lastToolsError = useRef<string | null>(null);

  useEffect(() => {
    if (avatarChat.state.error && avatarChat.state.error !== lastAvatarError.current) {
      lastAvatarError.current = avatarChat.state.error;
      toast.error(avatarChat.state.error);
    }
  }, [avatarChat.state.error, toast]);

  useEffect(() => {
    if (toolsChat.state.error && toolsChat.state.error !== lastToolsError.current) {
      lastToolsError.current = toolsChat.state.error;
      toast.error(toolsChat.state.error);
    }
  }, [toolsChat.state.error, toast]);

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

  function handleTabChange(next: Tab) {
    if (next === "tools" && !selectedPersona) return;
    setTab(next);
  }

  return (
    <div className="flex h-full">
      <div className="w-64 shrink-0 overflow-y-auto border-r border-light-border bg-light-card p-4 dark:border-dark-border dark:bg-dark-card">
        <h2 className="mb-3 px-1 font-mono text-[11px] font-medium uppercase tracking-wider text-light-onSurface/35 dark:text-white/30">
          Personagens
        </h2>
        {personasQuery.isPending && (
          <div className="space-y-1.5">
            <Skeleton className="h-7 w-full" />
            <Skeleton className="h-7 w-full" />
            <Skeleton className="h-7 w-3/4" />
          </div>
        )}
        {!personasQuery.isPending && personasQuery.data?.length === 0 && (
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
        <div className="mb-5 flex items-center gap-3">
          <Tabs
            value={tab}
            onChange={handleTabChange}
            items={[
              { value: "personas", label: "Criar personagem" },
              { value: "tools", label: `Ferramentas${selectedPersona ? ` — ${selectedPersona.name}` : ""}` },
            ]}
          />
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
          {activeChat.state.isLoadingSession && (
            <div className="space-y-3">
              <Skeleton className="ml-auto h-9 w-1/2" />
              <Skeleton className="h-16 w-2/3" />
            </div>
          )}
          {!activeChat.state.isLoadingSession && activeChat.state.messages.length === 0 && (
            <EmptyState
              title={tab === "personas" ? "Descreva um personagem" : "Converse com a persona"}
              description="As mensagens aparecerão aqui."
            />
          )}
          {activeChat.state.messages.map((msg) => (
            <ChatMessageBubble key={msg.id} role={msg.role} content={msg.content} isStreaming={msg.isStreaming} />
          ))}
        </div>

        <ChatComposer
          value={input}
          onChange={setInput}
          onSend={handleSend}
          disabled={activeChat.state.isGenerating}
          placeholder={tab === "personas" ? "Descreva o personagem..." : "Peça uma copy contextualizada..."}
        />
      </div>
    </div>
  );
}
