export type GenerationStatus =
  | "idle"
  | "connecting"
  | "thinking"
  | "streaming"
  | "done"
  | "error";

export type ImageStatus = "idle" | "generating" | "done" | "error";

export interface ChatTurn {
  userMessage: string;
  output: string;
}

export interface GenerationState {
  status: GenerationStatus;
  thinking: string;
  output: string;
  flowName: string | null;
  error: string | null;
  turns: ChatTurn[];
  currentUserMessage: string;
  imageStatus: ImageStatus;
  imageUrl: string | null;
  imageError: string | null;
}

export const initialGenerationState: GenerationState = {
  status: "idle",
  thinking: "",
  output: "",
  flowName: null,
  error: null,
  turns: [],
  currentUserMessage: "",
  imageStatus: "idle",
  imageUrl: null,
  imageError: null,
};

export function isGenerating(status: GenerationStatus): boolean {
  return status === "connecting" || status === "thinking" || status === "streaming";
}

export function extractImagePrompts(output: string): string[] {
  const matches = [...output.matchAll(/```(?:\w*\n)?([\s\S]+?)```/g)];
  return matches
    .map((m) => m[1]?.trim())
    .filter((s): s is string => !!s);
}
