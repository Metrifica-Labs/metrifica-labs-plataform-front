import { test, expect } from "../fixtures/auth";
import { InstagramPostPage } from "../pages/InstagramPostPage";

test.describe("Canvas preview", () => {
  let ig: InstagramPostPage;

  test.beforeEach(async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await ig.goto();
  });

  test("renders the page title", async () => {
    await expect(ig.pageTitle).toBeVisible();
  });

  test("canvas preview area is visible with a default slide", async () => {
    await expect(ig.canvasPreview).toBeVisible();
  });

  test("default slide shows 'Seu título aqui'", async () => {
    await expect(ig.canvasPreview).toContainText("Seu título aqui");
  });

  test("default slide shows 1/1 counter", async () => {
    await expect(ig.canvasPreview).toContainText("1/1");
  });

  test("canvas inner div has the fixed 432×540 dimensions", async ({ authedPage }) => {
    const canvas = authedPage.locator('[style*="width: 432px"]').first();
    await expect(canvas).toBeVisible();
    const box = await canvas.boundingBox();
    expect(box?.width).toBe(432);
    expect(box?.height).toBe(540);
  });

  test("layout button Tipo 2 switches to Image Cover without crashing", async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await authedPage.getByRole("button", { name: /Tipo 2/i }).click();
    await expect(ig.canvasPreview).toBeVisible();
  });

  test("layout button Tipo 3 switches to Text Grid without crashing", async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await authedPage.getByRole("button", { name: /Tipo 3/i }).click();
    await expect(ig.canvasPreview).toBeVisible();
  });

  test("layout button Tipo 4 switches to Image Stack without crashing", async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await authedPage.getByRole("button", { name: /Tipo 4/i }).click();
    await expect(ig.canvasPreview).toBeVisible();
  });

  test("layout button Tipo 5 switches to Freestyle without crashing", async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await authedPage.getByRole("button", { name: /Tipo 5/i }).click();
    await expect(ig.canvasPreview).toBeVisible();
  });
});
