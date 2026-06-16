"""
Logica de transcricao (Whisper) compartilhada entre a CLI (transcribe.py) e a
UI desktop (transcribe_gui.py) do modulo Audio Visualizer.
"""
from __future__ import annotations

from typing import Callable, Optional

ProgressCallback = Optional[Callable[[str], None]]


def transcribe_audio(
    audio_path: str,
    model_name: str = "small",
    language: Optional[str] = "pt",
    on_progress: ProgressCallback = None,
) -> dict:
    """Transcreve um audio com Whisper e retorna o payload de legendas.

    Payload: { language, duration, segments, words }, com timestamps por
    palavra (usado pelo modo karaoke do modulo Audio Visualizer).
    """
    import whisper  # import tardio: pesado, so carrega quando necessario

    def report(msg: str) -> None:
        if on_progress:
            on_progress(msg)

    report(f"Carregando modelo '{model_name}'...")
    model = whisper.load_model(model_name)

    report(f"Transcrevendo {audio_path}...")
    result = model.transcribe(
        audio_path,
        language=None if language in (None, "auto") else language,
        verbose=False,
        word_timestamps=True,
    )

    segments = []
    all_words = []
    duration = 0.0

    for i, s in enumerate(result.get("segments", [])):
        words = []
        for w in (s.get("words") or []):
            word = w.get("word", "").strip()
            if not word:
                continue
            entry = {
                "word": word,
                "start": round(w["start"], 3),
                "end": round(w["end"], 3),
            }
            words.append(entry)
            all_words.append(entry)
            duration = max(duration, entry["end"])

        seg_end = round(s["end"], 3)
        duration = max(duration, seg_end)
        segments.append(
            {
                "id": i,
                "start": round(s["start"], 3),
                "end": seg_end,
                "text": s["text"].strip(),
                "words": words,
            }
        )

    report(f"OK: {len(all_words)} palavras transcritas.")

    return {
        "language": result.get("language", language),
        "duration": round(duration, 3),
        "segments": segments,
        "words": all_words,
    }
