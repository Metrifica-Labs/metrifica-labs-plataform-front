export function pickImageDataUrl(accept = "image/*"): Promise<string | null> {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = accept;
    input.style.position = "fixed";
    input.style.top = "-1000px";
    input.style.opacity = "0";
    document.body.appendChild(input);

    function settle(value: string | null) {
      input.remove();
      resolve(value);
    }

    input.onchange = () => {
      const file = input.files?.[0];
      if (!file) {
        settle(null);
        return;
      }
      const reader = new FileReader();
      reader.onload = () => settle(typeof reader.result === "string" ? reader.result : null);
      reader.onerror = () => settle(null);
      reader.readAsDataURL(file);
    };
    input.oncancel = () => settle(null);
    input.click();
  });
}
