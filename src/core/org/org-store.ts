import { create } from "zustand";
import { persist } from "zustand/middleware";

const ACTIVE_ORG_KEY = "metrifica_active_org_id";

interface OrgState {
  activeOrgId: string | null;
  setActiveOrgId: (id: string | null) => void;
}

export const useOrgStore = create<OrgState>()(
  persist(
    (set) => ({
      activeOrgId: null,
      setActiveOrgId: (id) => set({ activeOrgId: id }),
    }),
    { name: ACTIVE_ORG_KEY }
  )
);
