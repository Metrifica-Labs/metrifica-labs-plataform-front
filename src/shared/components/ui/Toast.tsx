import { CheckCircle2, XCircle, Info, X } from "lucide-react";
import { cn } from "@/shared/lib/cn";
import { useToastStore, type ToastVariant } from "@/shared/hooks/useToast";

const variantStyle: Record<ToastVariant, string> = {
  success: "border-success/30 bg-success-soft text-success",
  error: "border-danger/30 bg-danger-soft text-danger",
  info: "border-primary/30 bg-primary-soft text-primary",
};

const variantIcon: Record<ToastVariant, React.ReactNode> = {
  success: <CheckCircle2 size={16} />,
  error: <XCircle size={16} />,
  info: <Info size={16} />,
};

export function ToastViewport() {
  const toasts = useToastStore((s) => s.toasts);
  const dismiss = useToastStore((s) => s.dismiss);

  if (toasts.length === 0) return null;

  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-50 flex w-80 flex-col gap-2">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          role="status"
          className={cn(
            "pointer-events-auto flex items-start gap-2 rounded-lg border px-3 py-2.5 text-[13px] font-medium shadow-floating",
            variantStyle[toast.variant]
          )}
        >
          <span className="mt-0.5 shrink-0">{variantIcon[toast.variant]}</span>
          <p className="flex-1 leading-snug">{toast.message}</p>
          <button
            onClick={() => dismiss(toast.id)}
            className="shrink-0 opacity-60 transition-opacity hover:opacity-100"
            aria-label="Dispensar notificação"
          >
            <X size={14} />
          </button>
        </div>
      ))}
    </div>
  );
}
