import { Send } from "lucide-react";
import { Input } from "@/shared/components/ui/Field";
import { IconButton } from "@/shared/components/ui/Button";

export function ChatComposer({
  value,
  onChange,
  onSend,
  placeholder,
  disabled,
}: {
  value: string;
  onChange: (value: string) => void;
  onSend: () => void;
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <div className="mt-4 flex items-center gap-2">
      <Input
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={(e) => e.key === "Enter" && onSend()}
        disabled={disabled}
        placeholder={placeholder}
        className="flex-1"
      />
      <IconButton
        onClick={onSend}
        disabled={disabled || !value.trim()}
        className="h-9 w-9 bg-primary text-white hover:bg-primary-hover hover:text-white disabled:opacity-50"
      >
        <Send size={15} />
      </IconButton>
    </div>
  );
}
