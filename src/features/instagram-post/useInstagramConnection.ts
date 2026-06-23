import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/core/auth/auth-store";
import { useToast } from "@/shared/hooks/useToast";
import {
  fetchInstagramConnection,
  initiateInstagramConnection,
  disconnectInstagram,
  type InstagramConnection,
} from "@/features/instagram-post/instagram-connection";

const QK = (userId: string | undefined) => ["instagram-connection", userId] as const;

export function useInstagramConnection() {
  const userId = useAuthStore((s) => s.user?.id);
  const queryClient = useQueryClient();
  const toast = useToast();

  const { data: connection, isLoading } = useQuery({
    queryKey: QK(userId),
    queryFn: () => fetchInstagramConnection(userId!),
    enabled: !!userId,
    refetchInterval: (query) =>
      (query.state.data as InstagramConnection | null)?.status === "pending" ? 3000 : false,
  });

  const connect = useMutation({
    mutationFn: initiateInstagramConnection,
    onSuccess: (redirectUrl) => {
      const popup = window.open(redirectUrl, "_blank", "noopener,noreferrer");
      if (!popup) {
        toast.error("Popup bloqueado pelo navegador. Permita popups para este site e tente novamente.");
        return;
      }
      toast.info("Autorize o acesso ao Instagram na aba que foi aberta.");
      queryClient.invalidateQueries({ queryKey: QK(userId) });
    },
    onError: (err) => {
      const message = err instanceof Error ? err.message : String(err);
      toast.error(`Erro ao conectar Instagram: ${message}`);
    },
  });

  const disconnect = useMutation({
    mutationFn: () => disconnectInstagram(connection!.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: QK(userId) });
    },
    onError: (err) => {
      const message = err instanceof Error ? err.message : String(err);
      toast.error(`Erro ao desconectar: ${message}`);
    },
  });

  return { connection, isLoading, connect, disconnect };
}
