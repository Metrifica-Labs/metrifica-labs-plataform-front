import { useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { edgeFunctionUrl, streamSSE, type SSEEvent } from "@/core/sse/sse-client";
import { useOrgStore } from "@/core/org/org-store";
import {
  EXAMPLE_SPEC,
  validateMotionSpec,
  type MotionSpec,
  type VideoFormat,
} from "@/remotion/motion-spec";
import { createMotionRun, updateMotionSpec } from "./motion-run.repository";
import { motionRunsQueryKey } from "./useMotionRuns";

export type MotionStatus = "idle" | "connecting" | "streaming" | "done" | "error";

export interface EditMessage {
  role: "user" | "assistant";
  content: string;
}

export interface MotionVideoState {
  status: MotionStatus;
  /** Spec atualmente no preview. Começa no exemplo; é substituído ao gerar. */
  spec: MotionSpec;
  /** Id do run persistido (Fase 4). `null` enquanto for só o exemplo. */
  runId: string | null;
  /** Texto cru acumulado da IA (JSON em construção) — útil para debug. */
  raw: string;
  /** Histórico do chat de edição (Fase 5). */
  messages: EditMessage[];
  error: string | null;
}

const initialState: MotionVideoState = {
  status: "idle",
  spec: EXAMPLE_SPEC,
  runId: null,
  raw: "",
  messages: [],
  error: null,
};

/** Extrai um objeto JSON de um texto que pode vir com cercas/ruído ao redor. */
function extractJson(raw: string): unknown {
  let text = raw.trim();
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) text = fenced[1].trim();
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first >= 0 && last > first) text = text.slice(first, last + 1);
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

export function useMotionVideo() {
  const [state, setState] = useState<MotionVideoState>(initialState);
  const abortRef = useRef<AbortController | null>(null);
  const queryClient = useQueryClient();
  const activeOrgId = useOrgStore((s) => s.activeOrgId);

  /**
   * Streama uma edge function que emite o JSON do MotionSpec, acumula o texto e
   * valida com Zod. Compartilhado entre geração (Fase 3) e edição (Fase 5).
   * Retorna o spec validado ou `null` (com `state.error` já preenchido).
   */
  async function streamSpec(
    fnName: "start-motion-run" | "edit-motion-run",
    body: unknown,
  ): Promise<MotionSpec | null> {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setState((s) => ({ ...s, status: "connecting", raw: "", error: null }));

    let buffer = "";
    try {
      await streamSSE(
        edgeFunctionUrl(fnName),
        body,
        (event: SSEEvent) => {
          if (event.type === "text") {
            buffer += (event.text as string) ?? "";
            setState((s) => ({ ...s, status: "streaming", raw: buffer }));
          } else if (event.type === "error") {
            setState((s) => ({
              ...s,
              status: "error",
              error: (event.message as string) ?? "Erro na geração",
            }));
            return true; // encerra o stream
          }
        },
        controller.signal,
      );
    } catch (err) {
      if (controller.signal.aborted) return null;
      setState((s) => ({
        ...s,
        status: "error",
        error: err instanceof Error ? err.message : String(err),
      }));
      return null;
    }

    const result = validateMotionSpec(extractJson(buffer));
    if (!result.success) {
      setState((s) => ({
        ...s,
        status: "error",
        error: "A IA retornou um roteiro inválido. Tente reformular o pedido.",
      }));
      return null;
    }
    return result.data;
  }

  async function generate(input: string, format: VideoFormat) {
    const trimmed = input.trim();
    if (!trimmed || state.status === "connecting" || state.status === "streaming") {
      return;
    }

    const spec = await streamSpec("start-motion-run", { input: trimmed, format });
    if (!spec) return;

    // Persiste o run (Fase 4). A RLS garante o escopo por org; só gravamos spec
    // válido. Falha de persistência não invalida o preview já exibido.
    let runId: string | null = null;
    if (activeOrgId) {
      try {
        const run = await createMotionRun({
          organizationId: activeOrgId,
          input: trimmed,
          format,
          spec,
        });
        runId = run.id;
        queryClient.invalidateQueries({ queryKey: motionRunsQueryKey(activeOrgId) });
      } catch (err) {
        console.error("Falha ao salvar o run de motion:", err);
      }
    }

    setState((s) => ({ ...s, status: "done", spec, runId, messages: [], error: null }));
  }

  /**
   * Aplica uma instrução de edição (Fase 5): a IA devolve o spec inteiro
   * revisado, validamos com Zod e — se o run estiver persistido — atualizamos
   * a mesma linha. O Player reflete na hora.
   */
  async function editSpec(instruction: string) {
    const trimmed = instruction.trim();
    if (!trimmed || state.status === "connecting" || state.status === "streaming") {
      return;
    }

    const baseSpec = state.spec;
    const runId = state.runId;
    setState((s) => ({ ...s, messages: [...s.messages, { role: "user", content: trimmed }] }));

    const spec = await streamSpec("edit-motion-run", {
      instruction: trimmed,
      currentSpec: baseSpec,
    });
    if (!spec) {
      setState((s) => ({
        ...s,
        messages: [
          ...s.messages,
          { role: "assistant", content: "Não consegui aplicar essa edição. Tente reformular." },
        ],
      }));
      return;
    }

    if (runId) {
      try {
        await updateMotionSpec(runId, spec);
        if (activeOrgId) {
          queryClient.invalidateQueries({ queryKey: motionRunsQueryKey(activeOrgId) });
        }
      } catch (err) {
        console.error("Falha ao salvar a edição do run:", err);
      }
    }

    setState((s) => ({
      ...s,
      status: "done",
      spec,
      error: null,
      messages: [...s.messages, { role: "assistant", content: "Pronto, apliquei a alteração." }],
    }));
  }

  /** Restaura um run já existente (ex.: ao clicar num item do histórico). */
  function loadSpec(spec: MotionSpec, runId: string | null) {
    abortRef.current?.abort();
    setState({ status: "done", spec, runId, raw: "", messages: [], error: null });
  }

  function reset() {
    abortRef.current?.abort();
    setState(initialState);
  }

  return { state, generate, editSpec, loadSpec, reset };
}
