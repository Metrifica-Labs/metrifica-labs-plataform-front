import type { Page } from "@playwright/test";

export class InstagramPostPage {
  constructor(readonly page: Page) {}

  async goto() {
    await this.page.goto("/instagram-post");
    await this.page.waitForLoadState("networkidle");
  }

  // ── Header ──────────────────────────────────────────────
  get pageTitle() {
    return this.page.getByRole("heading", { name: "Instagram Post" });
  }

  get historyButton() {
    return this.page.getByTitle("Histórico");
  }

  // ── Canvas ───────────────────────────────────────────────
  get canvasPreview() {
    return this.page.getByTestId("canvas-preview");
  }

  // ── Slide list ───────────────────────────────────────────
  get slideList() {
    return this.page.getByTestId("slide-list");
  }

  get addSlideButton() {
    return this.slideList.locator("button[class*='border-dashed']");
  }

  slideButton(n: number) {
    // Slide thumbnail buttons are scoped inside slide-list to avoid matching layout buttons
    return this.slideList.getByRole("button", { name: String(n), exact: true });
  }

  get exportButton() {
    return this.page.getByRole("button", { name: /Exportar PNG/i });
  }

  get removeSlideButton() {
    return this.page.getByRole("button", { name: /Remover slide/i });
  }

  // ── Style editor panel ───────────────────────────────────
  get styleEditorPanel() {
    return this.page.getByTestId("style-editor-panel");
  }

  get headlineTextarea() {
    // First textarea inside the style editor panel is the headline
    return this.styleEditorPanel.locator("textarea").first();
  }

  get layoutSelect() {
    return this.page.getByTestId("layout-select");
  }

  // ── Publish panel ─────────────────────────────────────────
  get publishPanelTitle() {
    return this.page.getByText("Publicar no Instagram");
  }

  get connectionStatus() {
    return this.page.getByText(/Não conectado|Conectado|Aguardando/i);
  }

  get connectButton() {
    return this.page.getByRole("button", { name: "Conectar" });
  }

  // ── History panel ─────────────────────────────────────────
  get historyPanel() {
    return this.page.getByTestId("history-panel");
  }

  get historyEmptyState() {
    return this.page.getByText("Sem histórico ainda");
  }

  get historyCloseButton() {
    return this.page.getByTitle("Fechar");
  }
}
