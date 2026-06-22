import { useEffect, useRef, useState } from "react";
import { useN3Chat } from "@/features/instagram-n3/useN3Chat";
import { N3_POST_TYPES } from "@/features/instagram-n3/instagram-n3-card";
import { addN3HistoryEntry } from "@/features/instagram-n3/instagram-n3-history";
import { EmptyState } from "@/shared/components/ui/Card";
import { ChatMessageBubble } from "@/shared/components/chat/ChatMessageBubble";
import { ChatComposer } from "@/shared/components/chat/ChatComposer";
import { useToast } from "@/shared/hooks/useToast";

export function InstagramN3Page() {
  const chat = useN3Chat();
  const [input, setInput] = useState("");
  const toast = useToast();
  const lastError = useRef<string | null>(null);

  useEffect(() => {
    if (chat.state.error && chat.state.error !== lastError.current) {
      lastError.current = chat.state.error;
      toast.error(chat.state.error);
    }
  }, [chat.state.error, toast]);

  function handleSend() {
    if (!input.trim()) return;
    void chat.send(input);
    setInput("");
  }

  return (
    <div className="mx-auto flex h-full max-w-3xl flex-col p-6">
      <h1 className="mb-4 text-lg font-semibold text-light-onSurface dark:text-white">
        Instagram N3
      </h1>

      <div className="flex-1 space-y-4 overflow-y-auto">
        {chat.state.messages.length === 0 && (
          <EmptyState title="Descreva o tema do post" description="Descreva o tema do carrossel N3 que você quer gerar." />
        )}
        {chat.state.messages.map((msg) => (
          <ChatMessageBubble key={msg.id} role={msg.role} content={msg.content} isStreaming={msg.isStreaming}>
            {msg.post && msg.post.cards.length > 0 && (
              <div className="mt-3 grid grid-cols-1 gap-3 text-left sm:grid-cols-2">
                {msg.post.cards.map((card) => (
                  <div
                    key={card.card}
                    className="rounded-lg border border-light-border bg-light-card p-3 dark:border-dark-border dark:bg-dark-card"
                  >
                    <div className="mb-1 flex items-center justify-between text-[10px] uppercase tracking-wide text-light-onSurface/40">
                      <span>Card {card.card}</span>
                      <span>{N3_POST_TYPES[msg.post!.postType].name}</span>
                    </div>
                    <p className="mb-1 text-[11px] text-primary">{card.objetivo}</p>
                    <p className="mb-1 text-sm font-semibold text-light-onSurface dark:text-white">
                      {card.headline}
                    </p>
                    <p className="text-xs text-light-onSurface/60 dark:text-white/60">{card.body}</p>
                  </div>
                ))}
                <button
                  onClick={() => addN3HistoryEntry(input, msg.post!)}
                  className="col-span-full self-start text-xs text-primary hover:underline"
                >
                  Salvar no histórico
                </button>
              </div>
            )}
          </ChatMessageBubble>
        ))}
      </div>

      <ChatComposer
        value={input}
        onChange={setInput}
        onSend={handleSend}
        placeholder="Descreva o post..."
        disabled={chat.state.isGenerating}
      />
    </div>
  );
}
