import { useState } from "react";
import { Instagram, CheckCircle2, AlertCircle, Clock, Loader2 } from "lucide-react";
import { useInstagramConnection } from "@/features/instagram-post/useInstagramConnection";
import type { useInstagramPublish } from "@/features/instagram-post/useInstagramPublish";
import { SectionCard } from "@/features/instagram-post/controls";
import { Button } from "@/shared/components/ui/Button";

type Publish = ReturnType<typeof useInstagramPublish>;

const STATUS_ICONS: Record<string, React.ReactNode> = {
  active: <CheckCircle2 size={14} className="text-green-500" />,
  pending: <Clock size={14} className="text-yellow-500" />,
  error: <AlertCircle size={14} className="text-red-500" />,
  none: <AlertCircle size={14} className="text-light-onSurface/30 dark:text-white/25" />,
};

const STATUS_LABELS: Record<string, string> = {
  active: "Conectado",
  pending: "Aguardando autorização…",
  error: "Erro na conexão",
  none: "Não conectado",
};

const WORKING_LABELS: Record<string, string> = {
  uploading: "Enviando imagens…",
  publishing: "Publicando…",
};

export function PublishPanel({ publish }: { publish: Publish }) {
  const { connection, isLoading, connect, disconnect } = useInstagramConnection();
  const [scheduledAt, setScheduledAt] = useState("");
  const [showSchedule, setShowSchedule] = useState(false);

  const status = connection?.status ?? "none";
  const isConnected = status === "active";
  const hasSlides = publish.slideCount > 0;

  const minDatetime = new Date();
  minDatetime.setMinutes(minDatetime.getMinutes() + 5);
  const minValue = minDatetime.toISOString().slice(0, 16);

  function handleScheduleConfirm() {
    if (!scheduledAt) return;
    publish.schedule(new Date(scheduledAt));
    setShowSchedule(false);
  }

  return (
    <SectionCard
      title="Publicar no Instagram"
      icon={<Instagram size={14} className="text-primary" />}
    >
      <div className="space-y-4">
        {/* Connection row */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex min-w-0 items-center gap-2">
            {isLoading ? (
              <Loader2 size={14} className="shrink-0 animate-spin text-light-onSurface/40" />
            ) : (
              <span className="shrink-0">{STATUS_ICONS[status]}</span>
            )}
            <div className="min-w-0">
              <p className="text-xs font-medium leading-none text-light-onSurface dark:text-white/80">
                {STATUS_LABELS[status]}
              </p>
              {isConnected && connection?.instagramHandle && (
                <p className="mt-0.5 truncate text-[11px] text-light-onSurface/45 dark:text-white/35">
                  {connection.instagramHandle}
                </p>
              )}
            </div>
          </div>

          {isConnected ? (
            <button
              onClick={() => disconnect.mutate()}
              disabled={disconnect.isPending}
              className="shrink-0 text-[11px] text-light-onSurface/40 hover:text-red-500 disabled:opacity-50 dark:text-white/30"
            >
              Desconectar
            </button>
          ) : (
            <Button
              size="sm"
              onClick={() => connect.mutate()}
              disabled={connect.isPending || status === "pending"}
              className="shrink-0"
            >
              {status === "pending" ? "Aguardando…" : "Conectar"}
            </Button>
          )}
        </div>

        {connection?.errorMessage && (
          <p className="text-[11px] text-red-500">{connection.errorMessage}</p>
        )}

        {/* Publish actions — only when connected */}
        {isConnected && (
          <div className="space-y-3 border-t border-light-border pt-3 dark:border-dark-border">
            {publish.state === "done" && (
              <p className="text-center text-xs font-medium text-green-500">
                ✓ Concluído com sucesso!
              </p>
            )}

            {publish.state === "error" && (
              <div className="space-y-1">
                <p className="text-[11px] text-red-500">{publish.error}</p>
                <button
                  onClick={publish.reset}
                  className="text-[11px] text-light-onSurface/40 hover:text-primary dark:text-white/30"
                >
                  Tentar novamente
                </button>
              </div>
            )}

            {publish.isWorking && (
              <div className="flex items-center justify-center gap-2 py-1">
                <Loader2 size={14} className="animate-spin text-primary" />
                <span className="text-xs text-light-onSurface/60 dark:text-white/50">
                  {WORKING_LABELS[publish.state] ?? "Processando…"}
                </span>
              </div>
            )}

            {publish.state === "idle" && (
              <>
                {!hasSlides && (
                  <p className="text-center text-[11px] text-light-onSurface/40 dark:text-white/30">
                    Gere os slides antes de publicar.
                  </p>
                )}

                <div className="flex gap-2">
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => publish.publish()}
                    disabled={!hasSlides}
                    className="flex-1"
                  >
                    Publicar agora
                  </Button>
                  <Button
                    variant="secondary"
                    size="sm"
                    onClick={() => setShowSchedule((v) => !v)}
                    disabled={!hasSlides}
                    className="flex-1"
                  >
                    Agendar
                  </Button>
                </div>

                {showSchedule && (
                  <div className="space-y-2">
                    <input
                      type="datetime-local"
                      value={scheduledAt}
                      onChange={(e) => setScheduledAt(e.target.value)}
                      min={minValue}
                      className="w-full rounded-md border border-light-border bg-transparent px-3 py-1.5 text-xs text-light-onSurface focus:outline-none focus:ring-1 focus:ring-primary dark:border-dark-border dark:text-white/80"
                    />
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={handleScheduleConfirm}
                      disabled={!scheduledAt}
                      className="w-full"
                    >
                      Confirmar agendamento
                    </Button>
                  </div>
                )}
              </>
            )}
          </div>
        )}
      </div>
    </SectionCard>
  );
}
