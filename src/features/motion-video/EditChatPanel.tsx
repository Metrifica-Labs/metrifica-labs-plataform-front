import { useState } from "react";
import { Wand2 } from "lucide-react";
import { ChatComposer } from "@/shared/components/chat/ChatComposer";
import { ChatMessageBubble } from "@/shared/components/chat/ChatMessageBubble";
import type { EditMessage } from "./useMotionVideo";

interface EditChatPanelProps {
  messages: EditMessage[];
  busy: boolean;
  /** Habilitado apenas quando há um vídeo gerado/carregado para editar. */
  enabled: boolean;
  onSend: (instruction: string) => void;
}

/**
 * Chat de edição (Fase 5). Cada mensagem dispara `edit-motion-run`; a IA devolve
 * o spec revisado e o preview ao lado atualiza na hora. Reusa os componentes de
 * chat compartilhados (`shared/components/chat/*`).
 */
export function EditChatPanel({ messages, busy, enabled, onSend }: EditChatPanelProps) {
  const [draft, setDraft] = useState("");

  function handleSend() {
    const text = draft.trim();
    if (!text || busy || !enabled) return;
    onSend(text);
    setDraft("");
  }

  return (
    <div className="flex h-full flex-col">
      <div className="mb-3 flex items-center gap-2">
        <Wand2 size={15} className="text-primary" />
        <h2 className="text-[13px] font-semibold text-light-onSurface dark:text-dark-onSurface">
          Editar com IA
        </h2>
      </div>

      <div className="flex-1 space-y-3 overflow-y-auto">
        {messages.length === 0 && (
          <p className="text-[12px] leading-relaxed text-light-onSurface/45 dark:text-dark-onSurface/45">
            {enabled
              ? "Peça ajustes em linguagem natural. Ex.: “deixa a primeira cena mais lenta e troca a cor de destaque para azul”."
              : "Gere um vídeo primeiro para poder editá-lo aqui."}
          </p>
        )}
        {messages.map((m, i) => (
          <ChatMessageBubble key={i} role={m.role} content={m.content} />
        ))}
        {busy && <ChatMessageBubble role="assistant" content="" isStreaming />}
      </div>

      <ChatComposer
        value={draft}
        onChange={setDraft}
        onSend={handleSend}
        disabled={busy || !enabled}
        placeholder={enabled ? "Descreva o ajuste…" : "Gere um vídeo primeiro"}
      />
    </div>
  );
}
