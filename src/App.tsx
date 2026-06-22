import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "react-router-dom";
import { router } from "@/app/router";
import { ThemeProvider } from "@/core/theme/ThemeProvider";
import { ToastViewport } from "@/shared/components/ui/Toast";

const queryClient = new QueryClient();

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <RouterProvider router={router} />
        <ToastViewport />
      </ThemeProvider>
    </QueryClientProvider>
  );
}
