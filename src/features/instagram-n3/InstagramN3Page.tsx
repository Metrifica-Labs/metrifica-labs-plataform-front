import { useState } from "react";
import { Send } from "lucide-react";
import { useN3Chat } from "@/features/instagram-n3/useN3Chat";
import { N3_POST_TYPES } from "@/features/instagram-n3/instagram-n3-card";
import { addN3HistoryEntry } from "@/features/instagram-n3/instagram-n3-history";

export function InstagramN3Page() {
  const chat = useN3Chat();
  const [input, setInput] = useState("");

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
        {chat.state.messages.map((msg) => (
          <div key={msg.id} className={msg.role === "user" ? "text-right" : "text-left"}>
            <div
              className={`inline-block max-w-[85%] rounded-lg px-3 py-2 text-sm ${
                msg.role === "user"
                  ? "bg-primary text-white"
                  : "bg-light-onSurface/5 text-light-onSurface/80 dark:bg-white/5 dark:text-white/80"
              }`}
            >
              {msg.isStreaming && !msg.content ? "Pensando..." : msg.content}
            </div>

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
          </div>
        ))}
        {chat.state.messages.length === 0 && (
          <p className="text-sm text-light-onSurface/40 dark:text-white/30">
            Descreva o tema do carrossel N3 que você quer gerar.
          </p>
        )}
      </div>

      <div className="mt-4 flex items-center gap-2">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleSend()}
          placeholder="Descreva o post..."
          disabled={chat.state.isGenerating}
          className="flex-1 rounded-md border border-light-border-strong bg-transparent px-3 py-2 text-sm outline-none focus:border-primary disabled:opacity-50 dark:border-dark-border"
        />
        <button
          onClick={handleSend}
          disabled={chat.state.isGenerating || !input.trim()}
          className="flex items-center justify-center rounded-md bg-primary p-2 text-white disabled:opacity-50"
        >
          <Send size={16} />
        </button>
      </div>
    </div>
  );
}
