import { test, expect } from "../fixtures/auth";
import { InstagramPostPage } from "../pages/InstagramPostPage";

test.describe("Slide management", () => {
  let ig: InstagramPostPage;

  test.beforeEach(async ({ authedPage }) => {
    ig = new InstagramPostPage(authedPage);
    await ig.goto();
  });

  test("shows slide 1 thumbnail as active by default", async () => {
    await expect(ig.slideButton(1)).toBeVisible();
  });

  test("Export PNG button is visible", async () => {
    await expect(ig.exportButton).toBeVisible();
  });

  test("Remove slide button is not visible with only one slide", async () => {
    await expect(ig.removeSlideButton).not.toBeVisible();
  });

  test("adds a second slide with the + button", async () => {
    await ig.addSlideButton.click();
    await expect(ig.slideButton(2)).toBeVisible();
  });

  test("counter updates to 1/2 after adding a slide", async () => {
    await ig.addSlideButton.click();
    await ig.slideButton(1).click();
    await expect(ig.canvasPreview).toContainText("1/2");
  });

  test("Remove slide button appears when there are two slides", async () => {
    await ig.addSlideButton.click();
    await expect(ig.removeSlideButton).toBeVisible();
  });

  test("navigating to slide 2 shows counter 2/2", async () => {
    await ig.addSlideButton.click();
    await ig.slideButton(2).click();
    await expect(ig.canvasPreview).toContainText("2/2");
  });

  test("removing a slide decreases count back to 1/1", async () => {
    await ig.addSlideButton.click();
    await ig.removeSlideButton.click();
    await expect(ig.slideButton(2)).not.toBeVisible();
    await expect(ig.canvasPreview).toContainText("1/1");
  });
});
