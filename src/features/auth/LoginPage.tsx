import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/core/supabase/client";
import { Button } from "@/shared/components/ui/Button";
import { Input, Label } from "@/shared/components/ui/Field";

function friendlyAuthError(message: string): string {
  if (message.includes("Invalid login credentials")) {
    return "E-mail ou senha incorretos.";
  }
  return "Não foi possível entrar. Tente novamente.";
}

export function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) {
      setError(friendlyAuthError(error.message));
      return;
    }
    navigate("/org-picker", { replace: true });
  }

  return (
    <div className="relative flex min-h-screen items-center justify-center overflow-hidden bg-light-surface dark:bg-dark-surface">
      <div className="pointer-events-none absolute -left-32 -top-32 h-80 w-80 rounded-full bg-primary/15 blur-[100px]" />
      <div className="pointer-events-none absolute -bottom-32 -right-32 h-80 w-80 rounded-full bg-accent/10 blur-[100px]" />

      <form
        onSubmit={handleSubmit}
        className="relative z-10 w-full max-w-sm rounded-2xl border border-light-border bg-light-card p-7 shadow-floating dark:border-dark-border dark:bg-dark-card"
      >
        <div className="mb-6 flex flex-col items-center text-center">
          <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-primary shadow-glow-primary">
            <span className="text-base font-bold text-white">M</span>
          </div>
          <h1 className="text-lg font-semibold tracking-tight text-light-onSurface dark:text-dark-onSurface">
            Entrar na Metrifica
          </h1>
          <p className="mt-1 text-[13px] text-light-onSurface/45 dark:text-white/35">
            Acesse o painel da sua organização
          </p>
        </div>

        <Label htmlFor="email">E-mail</Label>
        <Input
          id="email"
          type="email"
          required
          autoFocus
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4"
        />
        <Label htmlFor="password">Senha</Label>
        <Input
          id="password"
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-4"
        />
        {error && (
          <p className="mb-4 rounded-md border border-red-500/20 bg-red-500/5 px-3 py-2 text-[13px] text-red-500">
            {error}
          </p>
        )}
        <Button type="submit" disabled={loading} className="w-full">
          {loading ? "Entrando..." : "Entrar"}
        </Button>
      </form>
    </div>
  );
}
