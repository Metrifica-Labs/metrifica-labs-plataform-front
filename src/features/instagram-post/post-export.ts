import { toPng } from "html-to-image";

export async function exportSlideToPng(node: HTMLElement, filename: string): Promise<void> {
  const dataUrl = await toPng(node, { pixelRatio: 2.5 });
  const link = document.createElement("a");
  link.href = dataUrl;
  link.download = filename;
  link.click();
}

export async function exportAllSlidesToPng(nodes: HTMLElement[]): Promise<void> {
  for (let i = 0; i < nodes.length; i++) {
    await exportSlideToPng(nodes[i], `slide-${i + 1}.png`);
    if (i < nodes.length - 1) {
      await new Promise((r) => setTimeout(r, 150));
    }
  }
}
