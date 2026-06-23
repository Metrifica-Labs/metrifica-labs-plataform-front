import { test, expect } from "../fixtures/auth";
import { InstagramPostPage } from "../pages/InstagramPostPage";

test.describe("Style editor panel", () => {
  let ig: InstagramPostPage;

  test.beforeEach(async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await ig.goto();
  });

  test("style editor panel is visible", async ({ authedPage }) => {
    await expect(authedPage.getByText("Texto dos slides")).toBeVisible();
  });

  test("editing the headline textarea updates the canvas text", async () => {
    const textarea = ig.headlineTextarea;
    await textarea.clear();
    await textarea.fill("E2E headline test");
    await expect(ig.canvasPreview).toContainText("E2E headline test");
  });

  test("layout dropdown has all 5 layout options", async () => {
    const select = ig.layoutSelect;
    await expect(select).toBeVisible();
    const options = await select.locator("option").allTextContents();
    expect(options.length).toBe(5);
  });

  test("layout dropdown switches to Image Cover and shows cover-specific editor", async ({ authedPage }) => {
    // Select by option value (the SlideLayout key)
    await ig.layoutSelect.selectOption("imageCover");
    await expect(ig.canvasPreview).toBeVisible();
    // Scoped to the style panel to avoid matching the canvas Type 2 variant chip
    await expect(ig.styleEditorPanel.getByText("Imagem de capa").first()).toBeVisible();
  });

  test("preset chips section is visible", async ({ authedPage }) => {
    await expect(authedPage.getByText("Estilo do criador")).toBeVisible();
    await expect(authedPage.getByRole("button", { name: "Clean" })).toBeVisible();
  });

  test("clicking the Dark preset keeps canvas functional", async ({ authedPage }) => {
    await authedPage.getByRole("button", { name: "Dark" }).click();
    await expect(ig.canvasPreview).toBeVisible();
  });

  test("Destaque section is visible", async ({ authedPage }) => {
    // Use exact: true to avoid matching the MarkupHintInline text that also contains "Destaque"
    await expect(authedPage.getByText("Destaque", { exact: true })).toBeVisible();
  });

  test("Extras section shows arrows toggle", async ({ authedPage }) => {
    await expect(authedPage.getByText("Setas de navegação")).toBeVisible();
  });
});
