import { test as base, type Page } from "@playwright/test";

const SUPABASE_URL = "https://dlhgictfgyhmkobzyrua.supabase.co";
const SUPABASE_PROJECT_REF = "dlhgictfgyhmkobzyrua";

function buildFakeSession() {
  // Build a structurally valid JWT (client never verifies the signature)
  function b64url(obj: object) {
    return btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=/g, "");
  }
  const header = b64url({ alg: "HS256", typ: "JWT" });
  const payload = b64url({
    sub: "e2e-test-user-id",
    email: "e2e@test.dev",
    role: "authenticated",
    aud: "authenticated",
    exp: 9_999_999_999,
    iat: 1_700_000_000,
  });
  const accessToken = `${header}.${payload}.e2esig`;

  return {
    access_token: accessToken,
    token_type: "bearer",
    expires_in: 3600,
    expires_at: 9_999_999_999,
    refresh_token: "e2e-refresh-token",
    user: {
      id: "e2e-test-user-id",
      aud: "authenticated",
      role: "authenticated",
      email: "e2e@test.dev",
      created_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-01-01T00:00:00Z",
      app_metadata: {},
      user_metadata: {},
    },
  };
}

export async function mockAuth(page: Page) {
  const fakeSession = buildFakeSession();

  // Seed localStorage before any app script runs
  await page.addInitScript(
    ({ key, session }) => {
      localStorage.setItem(key, JSON.stringify(session));
      // Clear any stale ig-post state from previous test runs
      localStorage.removeItem("ig_post_history_v1");
      localStorage.removeItem("ig_post_style_v1");
    },
    {
      key: `sb-${SUPABASE_PROJECT_REF}-auth-token`,
      session: fakeSession,
    }
  );

  // Mock Supabase auth token endpoint (handles any refresh attempts)
  await page.route(`${SUPABASE_URL}/auth/v1/**`, (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(fakeSession),
    });
  });

  // Mock all Supabase REST API calls — return empty results so sidebar/hooks don't crash
  await page.route(`${SUPABASE_URL}/rest/v1/**`, (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      headers: { "Content-Range": "0-0/0" },
      body: JSON.stringify([]),
    });
  });
}

export const test = base.extend<{ authedPage: Page }>({
  authedPage: async ({ page }, use) => {
    await mockAuth(page);
    await use(page);
  },
});

export { expect } from "@playwright/test";
