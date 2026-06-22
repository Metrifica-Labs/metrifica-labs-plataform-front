import { NavLink, useNavigate } from "react-router-dom";
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
  Building2,
  ChevronsUpDown,
} from "lucide-react";
import { useSidebarNav } from "@/shared/hooks/useSidebarNav";
import { useThemeStore } from "@/core/theme/theme-store";
import { useOrgStore } from "@/core/org/org-store";
import { useUserOrgs } from "@/core/org/org-queries";
import { supabase } from "@/core/supabase/client";
import { IconButton } from "@/shared/components/ui/Button";
import { Tooltip } from "@/shared/components/ui/Tooltip";
import { DropdownMenu } from "@/shared/components/ui/DropdownMenu";

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `group flex items-center gap-2.5 rounded-md px-2.5 py-[7px] text-[13px] font-medium transition-colors ${
    isActive
      ? "bg-primary-soft text-primary"
      : "text-light-onSurface/55 hover:bg-light-onSurface/6 hover:text-light-onSurface dark:text-dark-onSurface/50 dark:hover:bg-white/6 dark:hover:text-dark-onSurface"
  }`;

function SectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="mb-1.5 mt-4 px-2.5 font-mono text-[10px] font-medium uppercase tracking-wider text-light-onSurface/30 dark:text-dark-onSurface/30">
      {children}
    </p>
  );
}

export function Sidebar() {
  const { flows, modules, squads } = useSidebarNav();
  const { mode, toggle } = useThemeStore();
  const { activeOrgId, setActiveOrgId } = useOrgStore();
  const { data: orgs } = useUserOrgs();
  const navigate = useNavigate();

  const activeOrg = orgs?.find((org) => org.id === activeOrgId);
  const otherOrgs = orgs?.filter((org) => org.id !== activeOrgId) ?? [];

  function switchOrg(id: string) {
    setActiveOrgId(id);
    navigate("/squads/dev-squad", { replace: true });
  }

  async function signOut() {
    await supabase.auth.signOut();
    navigate("/login", { replace: true });
  }

  return (
    <aside className="flex h-screen w-[232px] flex-col border-r border-light-border bg-light-card dark:border-dark-border dark:bg-dark-card">
      <div className="flex items-center gap-2 px-4 py-4">
        <div className="flex h-6 w-6 items-center justify-center rounded-[7px] bg-primary shadow-glow-primary">
          <span className="text-[11px] font-bold text-white">M</span>
        </div>
        <span className="text-[13px] font-semibold tracking-tight text-light-onSurface dark:text-dark-onSurface">
          Metrifica
        </span>
      </div>

      <nav className="flex-1 overflow-y-auto px-2.5 pb-3">
        {flows.length > 0 && (
          <>
            <SectionLabel>Flows</SectionLabel>
            <div className="space-y-0.5">
              {flows.map((flow) => (
                <NavLink key={flow.id} to={`/flows/${flow.slug}`} className={navLinkClass}>
                  <Workflow size={15} className="shrink-0" />
                  <span className="truncate">{flow.name}</span>
                </NavLink>
              ))}
            </div>
          </>
        )}

        {modules.length > 0 && (
          <>
            <SectionLabel>Módulos</SectionLabel>
            <div className="space-y-0.5">
              {modules.map((mod) => (
                <NavLink key={mod.id} to={`/modules/${mod.slug}`} className={navLinkClass}>
                  <BookOpen size={15} className="shrink-0" />
                  <span className="truncate">{mod.name}</span>
                </NavLink>
              ))}
            </div>
          </>
        )}

        {squads.length > 0 && (
          <>
            <SectionLabel>Squads</SectionLabel>
            <div className="space-y-0.5">
              {squads.map((squad) => (
                <NavLink key={squad.id} to={`/squads/${squad.slug}`} className={navLinkClass}>
                  <Users size={15} className="shrink-0" />
                  <span className="truncate">{squad.name}</span>
                </NavLink>
              ))}
            </div>
          </>
        )}

        <SectionLabel>Ferramentas</SectionLabel>
        <div className="space-y-0.5">
          <NavLink to="/copy" className={navLinkClass}>
            <PenLine size={15} className="shrink-0" />
            Copy
          </NavLink>
          <NavLink to="/editorial" className={navLinkClass}>
            <CalendarDays size={15} className="shrink-0" />
            Editorial
          </NavLink>
          <NavLink to="/instagram-post" className={navLinkClass}>
            <Image size={15} className="shrink-0" />
            Instagram Post
          </NavLink>
          <NavLink to="/instagram-n3" className={navLinkClass}>
            <Layers size={15} className="shrink-0" />
            Instagram N3
          </NavLink>
          <NavLink to="/audio-visualizer" className={navLinkClass}>
            <AudioLines size={15} className="shrink-0" />
            Audio Visualizer
          </NavLink>
          <NavLink to="/video-caption" className={navLinkClass}>
            <Captions size={15} className="shrink-0" />
            Video Caption
          </NavLink>
        </div>
      </nav>

      <div className="border-t border-light-border px-3 py-2.5 dark:border-dark-border">
        {orgs && orgs.length > 1 && (
          <DropdownMenu
            trigger={
              <span className="flex w-full items-center justify-between gap-2 rounded-md px-2 py-1.5 text-[13px] font-medium text-light-onSurface/70 transition-colors hover:bg-light-onSurface/6 dark:text-dark-onSurface/65 dark:hover:bg-white/6">
                <span className="flex items-center gap-2 truncate">
                  <Building2 size={14} className="shrink-0 text-light-onSurface/40 dark:text-white/35" />
                  <span className="truncate">{activeOrg?.name ?? "Organização"}</span>
                </span>
                <ChevronsUpDown size={13} className="shrink-0 text-light-onSurface/30" />
              </span>
            }
            items={otherOrgs.map((org) => ({ label: org.name, onClick: () => switchOrg(org.id) }))}
          />
        )}
        <div className="mt-1.5 flex items-center justify-between">
          <Tooltip label="Alternar tema">
            <IconButton onClick={toggle}>
              {mode === "light" ? <Moon size={15} /> : <Sun size={15} />}
            </IconButton>
          </Tooltip>
          <Tooltip label="Sair">
            <IconButton onClick={signOut}>
              <LogOut size={15} />
            </IconButton>
          </Tooltip>
        </div>
      </div>
    </aside>
  );
}
