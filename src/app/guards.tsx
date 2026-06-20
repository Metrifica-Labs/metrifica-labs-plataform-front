import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuthStore } from "@/core/auth/auth-store";

export function RequireAuth() {
  const { session, initialized } = useAuthStore();
  const location = useLocation();

  if (!initialized) return null;

  if (!session) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <Outlet />;
}

export function RedirectIfAuthed() {
  const { session, initialized } = useAuthStore();

  if (!initialized) return null;

  if (session) {
    return <Navigate to="/org-picker" replace />;
  }

  return <Outlet />;
}
