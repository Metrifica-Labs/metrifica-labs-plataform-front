import { Markdown } from "@/shared/components/Markdown";
import { cn } from "@/shared/lib/cn";
import { TypingIndicator } from "@/shared/components/chat/TypingIndicator";

export function ChatMessageBubble({
  role,
  content,
  isStreaming,
  children,
}: {
  role: "user" | "assistant";
  content: string;
  isStreaming?: boolean;
  /** Extra content rendered below the bubble's main text (e.g. parsed cards), left-aligned. */
  children?: React.ReactNode;
}) {
  return (
    <div className={role === "user" ? "text-right" : "text-left"}>
      <div
        className={cn(
          "inline-block max-w-[85%] rounded-xl px-3.5 py-2.5 text-sm",
          role === "user"
            ? "bg-primary text-white"
            : "border border-light-border bg-light-card dark:border-dark-border dark:bg-dark-raised"
        )}
      >
        {isStreaming && !content ? <TypingIndicator /> : <Markdown content={content} />}
      </div>
      {children}
    </div>
  );
}
