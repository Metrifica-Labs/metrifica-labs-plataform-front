import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
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
    return <div className="flex h-screen items-center justify-center">Carregando...</div>;
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-light-surface dark:bg-dark-surface">
      <div className="w-full max-w-sm">
        <h1 className="mb-4 text-lg font-semibold text-light-onSurface dark:text-white">
          Escolha uma organização
        </h1>
        <ul className="space-y-2">
          {orgs?.map((org) => (
            <li key={org.id}>
              <button
                onClick={() => selectOrg(org.id)}
                className="w-full rounded-md border border-light-border bg-light-card px-3 py-2 text-left text-sm hover:border-primary dark:border-dark-border dark:bg-dark-card"
              >
                {org.name}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
