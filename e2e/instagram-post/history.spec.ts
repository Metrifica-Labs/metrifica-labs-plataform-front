import { test, expect } from "../fixtures/auth";
import { InstagramPostPage } from "../pages/InstagramPostPage";

test.describe("History panel", () => {
  let ig: InstagramPostPage;

  test.beforeEach(async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await ig.goto();
  });

  test("history panel is not visible on page load", async () => {
    await expect(ig.historyPanel).not.toBeVisible();
  });

  test("clicking the history button opens the panel", async () => {
    await ig.historyButton.click();
    await expect(ig.historyPanel).toBeVisible();
  });

  test("panel shows 'Sem histórico ainda' when history is empty", async () => {
    await ig.historyButton.click();
    await expect(ig.historyEmptyState).toBeVisible();
  });

  test("closing the panel with the X button hides it", async () => {
    await ig.historyButton.click();
    await expect(ig.historyPanel).toBeVisible();
    await ig.historyCloseButton.click();
    await expect(ig.historyPanel).not.toBeVisible();
  });

  test("clicking the backdrop closes the panel", async ({ authedPage }) => {
    await ig.historyButton.click();
    await expect(ig.historyPanel).toBeVisible();
    await authedPage.locator("[aria-hidden='true'].fixed.inset-0").click({ force: true });
    await expect(ig.historyPanel).not.toBeVisible();
  });
});
