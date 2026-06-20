import { useRef, useState } from "react";
import { streamSSE, edgeFunctionUrl } from "@/core/sse/sse-client";
import { initialGenerationState, type GenerationState } from "@/features/generation/generation-types";

export function useGeneration() {
  const [state, setState] = useState<GenerationState>(initialGenerationState);
  const abortRef = useRef<AbortController | null>(null);

  async function runStream(flowSlug: string, userMessage: string, extraContext?: string) {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      await streamSSE(
        edgeFunctionUrl("run-flow"),
        {
          flow_slug: flowSlug,
          user_message: userMessage,
          ...(extraContext ? { extra_context: extraContext } : {}),
        },
        (event) => {
          switch (event.type) {
            case "flow_start":
              setState((s) => ({
                ...s,
                status: "thinking",
                flowName: (event.flow as string) ?? s.flowName,
              }));
              break;
            case "thinking":
              setState((s) => ({
                ...s,
                status: "thinking",
                thinking: s.thinking + ((event.text as string) ?? ""),
              }));
              break;
            case "text":
              setState((s) => ({
                ...s,
                status: "streaming",
                output: s.output + ((event.text as string) ?? ""),
              }));
              break;
            case "error":
              setState((s) => ({
                ...s,
                status: "error",
                error: (event.message as string) ?? "Erro desconhecido",
              }));
              return true;
          }
        },
        controller.signal
      );
      setState((s) => (s.status === "error" ? s : { ...s, status: "done" }));
    } catch (e) {
      if (controller.signal.aborted) return;
      setState((s) => ({
        ...s,
        status: "error",
        error: e instanceof Error ? e.message : String(e),
      }));
    }
  }

  function generate(flowSlug: string, userMessage: string, extraContext?: string) {
    setState({ ...initialGenerationState, status: "connecting", currentUserMessage: userMessage });
    void runStream(flowSlug, userMessage, extraContext);
  }

  function refine(flowSlug: string, correction: string) {
    const newTurns = [...state.turns, { userMessage: state.currentUserMessage, output: state.output }];
    const composed =
      "Você gerou anteriormente o seguinte conteúdo:\n\n" +
      `---\n${state.output}\n---\n\n` +
      `Por favor, aplique a seguinte correção/ajuste: ${correction}`;

    setState({
      ...initialGenerationState,
      status: "connecting",
      turns: newTurns,
      currentUserMessage: correction,
      flowName: state.flowName,
    });
    void runStream(flowSlug, composed);
  }

  async function generateImage(prompt: string, aspectRatio = "1:1") {
    if (state.imageStatus === "generating") return;
    setState((s) => ({ ...s, imageStatus: "generating", imageUrl: null, imageError: null }));

    try {
      await streamSSE(edgeFunctionUrl("generate-image"), { prompt, aspect_ratio: aspectRatio }, (event) => {
        if (event.type === "image_url") {
          setState((s) => ({ ...s, imageStatus: "done", imageUrl: (event.url as string) ?? null }));
        } else if (event.type === "error") {
          setState((s) => ({
            ...s,
            imageStatus: "error",
            imageError: (event.message as string) ?? "Erro desconhecido",
          }));
        }
      });
      setState((s) => (s.imageStatus === "generating" ? { ...s, imageStatus: "error", imageError: "Sem resposta do servidor" } : s));
    } catch (e) {
      setState((s) => ({
        ...s,
        imageStatus: "error",
        imageError: e instanceof Error ? e.message : String(e),
      }));
    }
  }

  function clearImage() {
    setState((s) => ({ ...s, imageStatus: "idle", imageUrl: null, imageError: null }));
  }

  function restoreFromHistory(output: string, flowName?: string | null) {
    abortRef.current?.abort();
    setState({ ...initialGenerationState, status: "done", output, flowName: flowName ?? null });
  }

  function clear() {
    abortRef.current?.abort();
    setState(initialGenerationState);
  }

  return { state, generate, refine, generateImage, clearImage, restoreFromHistory, clear };
}
