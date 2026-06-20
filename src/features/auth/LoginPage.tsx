import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/core/supabase/client";

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
    <div className="flex min-h-screen items-center justify-center bg-light-surface dark:bg-dark-surface">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-xl border border-light-border bg-light-card p-6 shadow-sm dark:border-dark-border dark:bg-dark-card"
      >
        <h1 className="mb-6 text-xl font-semibold text-light-onSurface dark:text-white">
          Entrar
        </h1>
        <label className="mb-1 block text-sm text-light-onSurface/70 dark:text-white/70">
          E-mail
        </label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4 w-full rounded-md border border-light-border-strong bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-dark-border"
        />
        <label className="mb-1 block text-sm text-light-onSurface/70 dark:text-white/70">
          Senha
        </label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-4 w-full rounded-md border border-light-border-strong bg-transparent px-3 py-2 text-sm outline-none focus:border-primary dark:border-dark-border"
        />
        {error && <p className="mb-4 text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-primary px-3 py-2 text-sm font-medium text-white disabled:opacity-60"
        >
          {loading ? "Entrando..." : "Entrar"}
        </button>
      </form>
    </div>
  );
}
