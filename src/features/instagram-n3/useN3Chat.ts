import { useRef, useState } from "react";
import { streamSSE, edgeFunctionUrl } from "@/core/sse/sse-client";
import { parseN3Post, type N3Post } from "@/features/instagram-n3/instagram-n3-card";

const FLOW_SLUG = "instagram-n3";

export type N3ChatRole = "user" | "assistant";

export interface N3ChatMessage {
  id: string;
  role: N3ChatRole;
  content: string;
  post: N3Post | null;
  isStreaming: boolean;
  createdAt: string;
}

export interface N3ChatState {
  messages: N3ChatMessage[];
  isGenerating: boolean;
  error: string | null;
}

const initialState: N3ChatState = { messages: [], isGenerating: false, error: null };

export function useN3Chat() {
  const [state, setState] = useState<N3ChatState>(initialState);
  const abortRef = useRef<AbortController | null>(null);

  async function send(userText: string) {
    const trimmed = userText.trim();
    if (state.isGenerating || !trimmed) return;

    const now = Date.now();
    const userMsg: N3ChatMessage = {
      id: String(now),
      role: "user",
      content: trimmed,
      post: null,
      isStreaming: false,
      createdAt: new Date(now).toISOString(),
    };
    const assistantId = String(now + 1);
    const assistantMsg: N3ChatMessage = {
      id: assistantId,
      role: "assistant",
      content: "",
      post: null,
      isStreaming: true,
      createdAt: new Date(now).toISOString(),
    };

    const messagesForApi = [...state.messages, userMsg]
      .filter((m) => !m.isStreaming)
      .map((m) => ({ role: m.role, content: m.content }));

    setState((s) => ({ ...s, messages: [...s.messages, userMsg, assistantMsg], isGenerating: true }));

    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      await streamSSE(
        edgeFunctionUrl("run-flow"),
        { flow_slug: FLOW_SLUG, messages: messagesForApi },
        (event) => {
          if (event.type === "text") {
            append(assistantId, (event.text as string) ?? "");
          } else if (event.type === "error") {
            setError((event.message as string) ?? "Erro desconhecido", assistantId);
            return true;
          }
        },
        controller.signal
      );
      finalize(assistantId);
    } catch (e) {
      if (controller.signal.aborted) return;
      setError(e instanceof Error ? e.message : String(e), assistantId);
    }
  }

  function append(id: string, text: string) {
    setState((s) => ({
      ...s,
      messages: s.messages.map((m) => (m.id === id ? { ...m, content: m.content + text } : m)),
    }));
  }

  function finalize(id: string) {
    setState((s) => ({
      ...s,
      isGenerating: false,
      messages: s.messages.map((m) => {
        if (m.id !== id) return m;
        const parsed = parseN3Post(m.content);
        return { ...m, isStreaming: false, post: parsed.cards.length > 0 ? parsed : null };
      }),
    }));
  }

  function setError(error: string, assistantId: string) {
    setState((s) => ({
      ...s,
      isGenerating: false,
      error,
      messages: s.messages.map((m) =>
        m.id === assistantId
          ? { ...m, content: "Não foi possível gerar a resposta. Tente novamente.", isStreaming: false }
          : m
      ),
    }));
  }

  function clear() {
    abortRef.current?.abort();
    setState(initialState);
  }

  return { state, send, clear };
}
