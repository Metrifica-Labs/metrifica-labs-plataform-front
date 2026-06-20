import { describe, it, expect, beforeEach } from "vitest";
import { useOrgStore } from "@/core/org/org-store";

beforeEach(() => {
  localStorage.clear();
  useOrgStore.setState({ activeOrgId: null });
});

describe("useOrgStore", () => {
  it("starts with no active org", () => {
    expect(useOrgStore.getState().activeOrgId).toBeNull();
  });

  it("sets and persists the active org id", () => {
    useOrgStore.getState().setActiveOrgId("org-123");
    expect(useOrgStore.getState().activeOrgId).toBe("org-123");

    const raw = localStorage.getItem("metrifica_active_org_id");
    expect(raw).not.toBeNull();
    expect(JSON.parse(raw!).state.activeOrgId).toBe("org-123");
  });

  it("clears the active org id", () => {
    useOrgStore.getState().setActiveOrgId("org-123");
    useOrgStore.getState().setActiveOrgId(null);
    expect(useOrgStore.getState().activeOrgId).toBeNull();
  });
});
