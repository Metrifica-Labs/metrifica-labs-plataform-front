import { test, expect } from "../fixtures/auth";
import { InstagramPostPage } from "../pages/InstagramPostPage";

test.describe("Publish panel (not connected)", () => {
  let ig: InstagramPostPage;

  test.beforeEach(async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await ig.goto();
  });

  test("publish panel section title is visible", async () => {
    await expect(ig.publishPanelTitle).toBeVisible();
  });

  test("shows 'Não conectado' status when no connection exists", async () => {
    await expect(ig.connectionStatus).toBeVisible();
    await expect(ig.connectionStatus).toHaveText(/Não conectado/i);
  });

  test("shows the 'Conectar' button when not connected", async () => {
    await expect(ig.connectButton).toBeVisible();
  });

  test("publish and schedule buttons are not visible when not connected", async ({ authedPage }) => {
    await expect(authedPage.getByRole("button", { name: /Publicar agora/i })).not.toBeVisible();
    await expect(authedPage.getByRole("button", { name: /Agendar/i })).not.toBeVisible();
  });
});
