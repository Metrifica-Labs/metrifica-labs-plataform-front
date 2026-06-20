import { NavLink } from "react-router-dom";
import {
  Workflow,
  BookOpen,
  Users,
  PenLine,
  CalendarDays,
  Image,
  Layers,
  AudioLines,
  Captions,
  Moon,
  Sun,
  LogOut,
} from "lucide-react";
import { useSidebarNav } from "@/shared/hooks/useSidebarNav";
import { useThemeStore } from "@/core/theme/theme-store";
import { supabase } from "@/core/supabase/client";
import { useNavigate } from "react-router-dom";

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors ${
    isActive
      ? "bg-primary/10 text-primary"
      : "text-light-onSurface/70 hover:bg-light-border/50 dark:text-white/60 dark:hover:bg-dark-border/50"
  }`;

export function Sidebar() {
  const { flows, modules, squads } = useSidebarNav();
  const { mode, toggle } = useThemeStore();
  const navigate = useNavigate();

  async function signOut() {
    await supabase.auth.signOut();
    navigate("/login", { replace: true });
  }

  return (
    <aside className="flex h-screen w-[220px] flex-col border-r border-light-border bg-light-card dark:border-dark-border dark:bg-dark-card">
      <div className="px-4 py-4 text-sm font-semibold text-light-onSurface dark:text-white">
        Metrifica
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto px-2">
        {flows.map((flow) => (
          <NavLink key={flow.id} to={`/flows/${flow.slug}`} className={navLinkClass}>
            <Workflow size={16} />
            {flow.name}
          </NavLink>
        ))}

        {modules.map((mod) => (
          <NavLink key={mod.id} to={`/modules/${mod.slug}`} className={navLinkClass}>
            <BookOpen size={16} />
            {mod.name}
          </NavLink>
        ))}

        {squads.map((squad) => (
          <NavLink key={squad.id} to={`/squads/${squad.slug}`} className={navLinkClass}>
            <Users size={16} />
            {squad.name}
          </NavLink>
        ))}

        <div className="my-2 border-t border-light-border dark:border-dark-border" />

        <NavLink to="/copy" className={navLinkClass}>
          <PenLine size={16} />
          Copy
        </NavLink>
        <NavLink to="/editorial" className={navLinkClass}>
          <CalendarDays size={16} />
          Editorial
        </NavLink>
        <NavLink to="/instagram-post" className={navLinkClass}>
          <Image size={16} />
          Instagram Post
        </NavLink>
        <NavLink to="/instagram-n3" className={navLinkClass}>
          <Layers size={16} />
          Instagram N3
        </NavLink>
        <NavLink to="/audio-visualizer" className={navLinkClass}>
          <AudioLines size={16} />
          Audio Visualizer
        </NavLink>
        <NavLink to="/video-caption" className={navLinkClass}>
          <Captions size={16} />
          Video Caption
        </NavLink>
      </nav>

      <div className="flex items-center justify-between border-t border-light-border px-3 py-3 dark:border-dark-border">
        <button onClick={toggle} className="text-light-onSurface/60 dark:text-white/60">
          {mode === "light" ? <Moon size={16} /> : <Sun size={16} />}
        </button>
        <button onClick={signOut} className="text-light-onSurface/60 dark:text-white/60">
          <LogOut size={16} />
        </button>
      </div>
    </aside>
  );
}
