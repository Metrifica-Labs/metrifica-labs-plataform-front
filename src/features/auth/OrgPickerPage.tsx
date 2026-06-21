import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Building2, ChevronRight } from "lucide-react";
import { useUserOrgs } from "@/core/org/org-queries";
import { useOrgStore } from "@/core/org/org-store";

export function OrgPickerPage() {
  const navigate = useNavigate();
  const { data: orgs, isPending } = useUserOrgs();
  const { activeOrgId, setActiveOrgId } = useOrgStore();

  useEffect(() => {
    if (!orgs || orgs.length === 0) return;

    const savedOrgStillValid = orgs.some((o) => o.id === activeOrgId);
    if (savedOrgStillValid) {
      navigate("/squads/dev-squad", { replace: true });
      return;
    }

    if (orgs.length === 1) {
      setActiveOrgId(orgs[0].id);
      navigate("/squads/dev-squad", { replace: true });
    }
  }, [orgs, activeOrgId, navigate, setActiveOrgId]);

  function selectOrg(id: string) {
    setActiveOrgId(id);
    navigate("/squads/dev-squad", { replace: true });
  }

  if (isPending) {
    return (
      <div className="flex h-screen items-center justify-center bg-light-surface text-sm text-light-onSurface/50 dark:bg-dark-surface dark:text-white/40">
        Carregando...
      </div>
    );
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-light-surface dark:bg-dark-surface">
      <div className="w-full max-w-sm">
        <h1 className="mb-1 text-lg font-semibold tracking-tight text-light-onSurface dark:text-dark-onSurface">
          Escolha uma organização
        </h1>
        <p className="mb-5 text-[13px] text-light-onSurface/45 dark:text-white/35">
          Selecione o workspace que deseja acessar
        </p>
        <ul className="space-y-2">
          {orgs?.map((org) => (
            <li key={org.id}>
              <button
                onClick={() => selectOrg(org.id)}
                className="group flex w-full items-center gap-3 rounded-xl border border-light-border bg-light-card px-3.5 py-3 text-left shadow-soft transition-all hover:border-primary/50 hover:shadow-panel dark:border-dark-border dark:bg-dark-card"
              >
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-primary-soft text-primary">
                  <Building2 size={16} />
                </div>
                <span className="flex-1 truncate text-sm font-medium text-light-onSurface dark:text-dark-onSurface">
                  {org.name}
                </span>
                <ChevronRight
                  size={16}
                  className="text-light-onSurface/25 transition-transform group-hover:translate-x-0.5 group-hover:text-primary"
                />
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
