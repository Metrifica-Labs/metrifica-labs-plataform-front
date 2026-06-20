import { Outlet } from "react-router-dom";
import { Sidebar } from "@/shared/components/Sidebar";

export function ShellScaffold() {
  return (
    <div className="flex h-screen bg-light-surface dark:bg-dark-surface">
      <Sidebar />
      <main className="flex-1 overflow-y-auto">
        <Outlet />
      </main>
    </div>
  );
}
