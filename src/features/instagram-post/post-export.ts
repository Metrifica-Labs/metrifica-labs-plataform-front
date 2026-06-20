import { toPng } from "html-to-image";

export async function exportSlideToPng(node: HTMLElement, filename: string): Promise<void> {
  const dataUrl = await toPng(node, { pixelRatio: 2.5 });
  const link = document.createElement("a");
  link.href = dataUrl;
  link.download = filename;
  link.click();
}
