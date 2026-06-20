import { create } from "zustand";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/core/supabase/client";

interface AuthState {
  session: Session | null;
  user: User | null;
  initialized: boolean;
}

export const useAuthStore = create<AuthState>(() => ({
  session: null,
  user: null,
  initialized: false,
}));

supabase.auth.getSession().then(({ data }) => {
  useAuthStore.setState({
    session: data.session,
    user: data.session?.user ?? null,
    initialized: true,
  });
});

supabase.auth.onAuthStateChange((_event, session) => {
  useAuthStore.setState({ session, user: session?.user ?? null, initialized: true });
});
