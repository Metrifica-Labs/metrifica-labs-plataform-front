import { useEffect, useRef, useState } from "react";
import { supabase } from "@/core/supabase/client";
import { streamSSE, edgeFunctionUrl } from "@/core/sse/sse-client";

export type CopyChatRole = "user" | "assistant";

export interface CopyChatMessage {
  id: string;
  role: CopyChatRole;
  content: string;
  isStreaming: boolean;
  createdAt: string;
}

export interface CopyChatState {
  messages: CopyChatMessage[];
  isGenerating: boolean;
  error: string | null;
  sessionId: string | null;
  isLoadingSession: boolean;
}

const initialState: CopyChatState = {
  messages: [],
  isGenerating: false,
  error: null,
  sessionId: null,
  isLoadingSession: false,
};

export function useCopyChat(params: {
  agentSlug: string;
  personaContext?: string | null;
  orgId?: string | null;
  personaId?: string | null;
}) {
  const { agentSlug, personaContext, orgId, personaId } = params;
  const [state, setState] = useState<CopyChatState>(initialState);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    setState(initialState);
    if (!orgId) return;

    let active = true;
    setState((s) => ({ ...s, isLoadingSession: true }));

    (async () => {
      try {
        let query = supabase.from("copy_sessions").select("*").eq("org_id", orgId).eq("agent_slug", agentSlug);
        query = personaId ? query.eq("persona_id", personaId) : query.is("persona_id", null);
        const { data } = await query.order("updated_at", { ascending: false }).limit(1).maybeSingle();

        if (!active) return;
        if (!data) {
          setState((s) => ({ ...s, isLoadingSession: false }));
          return;
        }

        const messages = (data.messages as CopyChatMessage[]) ?? [];
        setState((s) => ({ ...s, messages, sessionId: data.id, isLoadingSession: false }));
      } catch {
        if (active) setState((s) => ({ ...s, isLoadingSession: false }));
      }
    })();

    return () => {
      active = false;
    };
  }, [agentSlug, orgId, personaId]);

  async function saveSession(messages: CopyChatMessage[], sessionId: string | null) {
    if (!orgId) return;
    const persisted = messages.filter((m) => !m.isStreaming);
    if (persisted.length === 0) return;

    try {
      if (!sessionId) {
        const { data } = await supabase
          .from("copy_sessions")
          .insert({ org_id: orgId, persona_id: personaId ?? null, agent_slug: agentSlug, messages: persisted })
          .select()
          .single();
        if (data) setState((s) => ({ ...s, sessionId: data.id }));
      } else {
        await supabase
          .from("copy_sessions")
          .update({ messages: persisted, updated_at: new Date().toISOString() })
          .eq("id", sessionId);
      }
    } catch {
      // auto-save falha silenciosamente
    }
  }

  async function send(userText: string) {
    const trimmed = userText.trim();
    if (state.isGenerating || !trimmed) return;

    const now = Date.now();
    const userMsg: CopyChatMessage = { id: String(now), role: "user", content: trimmed, isStreaming: false, createdAt: new Date(now).toISOString() };
    const assistantId = String(now + 1);
    const assistantMsg: CopyChatMessage = { id: assistantId, role: "assistant", content: "", isStreaming: true, createdAt: new Date(now).toISOString() };

    const nextMessages = [...state.messages, userMsg, assistantMsg];
    setState((s) => ({ ...s, messages: nextMessages, isGenerating: true, error: null }));

    const apiMessages = nextMessages
      .filter((m) => !(m.isStreaming && !m.content))
      .map((m) => ({ role: m.role, content: m.content }));

    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      await streamSSE(
        edgeFunctionUrl("run-agent"),
        { agent_slug: agentSlug, messages: apiMessages, ...(personaContext ? { persona_context: personaContext } : {}) },
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
    setState((s) => ({ ...s, messages: s.messages.map((m) => (m.id === id ? { ...m, content: m.content + text } : m)) }));
  }

  function finalize(id: string) {
    setState((s) => {
      const messages = s.messages.map((m) => (m.id === id ? { ...m, isStreaming: false } : m));
      void saveSession(messages, s.sessionId);
      return { ...s, messages, isGenerating: false };
    });
  }

  function setError(error: string, assistantId: string) {
    setState((s) => ({
      ...s,
      isGenerating: false,
      error,
      messages: s.messages.map((m) =>
        m.id === assistantId ? { ...m, content: "Não foi possível gerar a resposta. Tente novamente.", isStreaming: false } : m
      ),
    }));
  }

  async function generatePersonaSheet(): Promise<string> {
    const apiMessages = state.messages
      .filter((m) => !m.isStreaming && m.content)
      .map((m) => ({ role: m.role, content: m.content }));

    apiMessages.push({
      role: "user",
      content:
        "Com base em tudo que foi desenvolvido nessa conversa, crie uma ficha técnica completa e estruturada deste personagem. " +
        "Inclua todas as informações relevantes: perfil, dores, desejos, objeções, sonhos, valores, linguagem, comportamento e qualquer outro dado levantado. " +
        "Formate de forma clara em markdown.",
    });

    let output = "";
    await streamSSE(edgeFunctionUrl("run-agent"), { agent_slug: agentSlug, messages: apiMessages, ...(personaContext ? { persona_context: personaContext } : {}) }, (event) => {
      if (event.type === "text") output += (event.text as string) ?? "";
    });

    const result = output.trim();
    if (!result) throw new Error("A API retornou uma ficha vazia");
    return result;
  }

  function clear() {
    abortRef.current?.abort();
    setState(initialState);
  }

  return { state, send, clear, generatePersonaSheet };
}
