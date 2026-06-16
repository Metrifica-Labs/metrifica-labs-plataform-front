"""
Gerador de Legendas (Audio Visualizer) — app desktop com interface grafica.

Mesma logica do transcribe.py, mas sem linha de comando: o usuario escolhe o
audio, clica em "Gerar Legenda" e salva o arquivo .captions.json para subir
no modulo Audio Visualizer do site.

Rodar direto com Python:
    python scripts/transcribe_gui.py

Empacotar como app de macOS (.app), ver scripts/README_GUI.md.
"""
from __future__ import annotations

import json
import os
import sys
import threading
import traceback
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from transcribe_core import transcribe_audio

MODELOS = ["tiny", "base", "small", "medium", "large"]
IDIOMAS = [("Português", "pt"), ("Inglês", "en"), ("Espanhol", "es"), ("Detectar automaticamente", "auto")]


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Gerador de Legendas — Audio Visualizer")
        self.geometry("560x420")
        self.minsize(480, 380)

        self.audio_path: str | None = None
        self._build_ui()

    def _build_ui(self) -> None:
        pad = {"padx": 16, "pady": 8}

        frame = ttk.Frame(self)
        frame.pack(fill="both", expand=True)

        ttk.Label(
            frame,
            text="1. Escolha o arquivo de áudio",
            font=("", 12, "bold"),
        ).pack(anchor="w", **pad)

        row = ttk.Frame(frame)
        row.pack(fill="x", padx=16)
        self.audio_label = ttk.Label(row, text="Nenhum arquivo selecionado", foreground="#666")
        self.audio_label.pack(side="left", fill="x", expand=True)
        ttk.Button(row, text="Selecionar áudio...", command=self._pick_audio).pack(side="right")

        ttk.Label(
            frame,
            text="2. Configurações",
            font=("", 12, "bold"),
        ).pack(anchor="w", **pad)

        opts = ttk.Frame(frame)
        opts.pack(fill="x", padx=16)

        ttk.Label(opts, text="Qualidade (modelo):").grid(row=0, column=0, sticky="w", pady=4)
        self.model_var = tk.StringVar(value="small")
        ttk.OptionMenu(opts, self.model_var, "small", *MODELOS).grid(row=0, column=1, sticky="w")

        ttk.Label(opts, text="Idioma do áudio:").grid(row=1, column=0, sticky="w", pady=4)
        self.lang_var = tk.StringVar(value="pt")
        lang_names = [n for n, _ in IDIOMAS]
        self.lang_display = tk.StringVar(value=lang_names[0])
        ttk.OptionMenu(
            opts, self.lang_display, lang_names[0], *lang_names, command=self._on_lang_change
        ).grid(row=1, column=1, sticky="w")

        ttk.Label(
            frame,
            text="3. Gerar",
            font=("", 12, "bold"),
        ).pack(anchor="w", **pad)

        self.generate_btn = ttk.Button(frame, text="Gerar Legenda", command=self._start_transcribe)
        self.generate_btn.pack(padx=16, anchor="w")

        self.progress = ttk.Progressbar(frame, mode="indeterminate")
        self.progress.pack(fill="x", padx=16, pady=(12, 4))

        self.log = tk.Text(frame, height=10, state="disabled", wrap="word")
        self.log.pack(fill="both", expand=True, padx=16, pady=(4, 16))

    def _on_lang_change(self, selected_name: str) -> None:
        for name, code in IDIOMAS:
            if name == selected_name:
                self.lang_var.set(code)
                return

    def _pick_audio(self) -> None:
        path = filedialog.askopenfilename(
            title="Selecione o arquivo de áudio",
            filetypes=[
                ("Áudio", "*.mp3 *.wav *.m4a *.aac *.ogg *.flac"),
                ("Todos os arquivos", "*.*"),
            ],
        )
        if path:
            self.audio_path = path
            self.audio_label.config(text=os.path.basename(path), foreground="#000")

    def _log_msg(self, msg: str) -> None:
        self.log.config(state="normal")
        self.log.insert("end", msg + "\n")
        self.log.see("end")
        self.log.config(state="disabled")

    def _start_transcribe(self) -> None:
        if not self.audio_path:
            messagebox.showwarning("Atenção", "Selecione um arquivo de áudio primeiro.")
            return

        self.generate_btn.config(state="disabled")
        self.progress.start(12)
        self.log.config(state="normal")
        self.log.delete("1.0", "end")
        self.log.config(state="disabled")

        thread = threading.Thread(target=self._run_transcribe, daemon=True)
        thread.start()

    def _run_transcribe(self) -> None:
        try:
            payload = transcribe_audio(
                self.audio_path,
                model_name=self.model_var.get(),
                language=self.lang_var.get(),
                on_progress=lambda msg: self.after(0, self._log_msg, msg),
            )
        except Exception as exc:  # noqa: BLE001 — exibido ao usuario
            traceback.print_exc()
            self.after(0, self._on_error, str(exc))
            return

        self.after(0, self._on_success, payload)

    def _on_error(self, message: str) -> None:
        self.progress.stop()
        self.generate_btn.config(state="normal")
        messagebox.showerror("Erro ao transcrever", message)

    def _on_success(self, payload: dict) -> None:
        self.progress.stop()
        self.generate_btn.config(state="normal")

        base = os.path.splitext(os.path.basename(self.audio_path))[0]
        save_path = filedialog.asksaveasfilename(
            title="Salvar legenda como...",
            initialfile=f"{base}.captions.json",
            defaultextension=".json",
            filetypes=[("JSON", "*.json")],
        )
        if not save_path:
            self._log_msg("Transcrição concluída, mas não foi salva (cancelado).")
            return

        with open(save_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        self._log_msg(f"Salvo em: {save_path}")
        messagebox.showinfo(
            "Concluído",
            f"Legenda gerada com {len(payload['words'])} palavras.\n\n"
            f"Salva em:\n{save_path}\n\n"
            "Agora faça upload desse arquivo junto com o áudio no módulo "
            "Audio Visualizer do site.",
        )


def main() -> None:
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
