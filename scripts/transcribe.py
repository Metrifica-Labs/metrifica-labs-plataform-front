"""
Transcreve um arquivo de audio com Whisper e gera as legendas usadas pelo
modulo Audio Visualizer (web).

Uso:
    python scripts/transcribe.py <audio.(wav|mp3|m4a|...)> [modelo] [-o saida.json]

- modelo: tiny | base | small | medium | large  (default: small)
- saida:  caminho do JSON (default: <audio>.captions.json)

Saida: JSON { language, duration, segments, words } com timestamps por palavra.
Esse JSON e o arquivo que voce faz upload no modulo Audio Visualizer junto
com o audio para gerar a legenda sincronizada (karaoke) no video.
"""
import sys
import json
import argparse

import whisper

# Forca UTF-8 no stdout independente do terminal (Windows etc.)
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def main():
    parser = argparse.ArgumentParser(
        description="Transcreve audio com Whisper (timestamps por palavra)."
    )
    parser.add_argument("audio", help="Caminho do arquivo de audio")
    parser.add_argument(
        "model",
        nargs="?",
        default="small",
        help="Modelo Whisper (tiny|base|small|medium|large). Default: small",
    )
    parser.add_argument(
        "-l",
        "--language",
        default="pt",
        help="Idioma do audio (default: pt). Use 'auto' para detectar.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Arquivo JSON de saida (default: <audio>.captions.json)",
    )
    args = parser.parse_args()

    language = None if args.language == "auto" else args.language

    print(f"Carregando modelo '{args.model}'...", file=sys.stderr)
    model = whisper.load_model(args.model)

    print(f"Transcrevendo {args.audio}...", file=sys.stderr)
    result = model.transcribe(
        args.audio,
        language=language,
        verbose=False,
        word_timestamps=True,  # timestamps por palavra (karaoke)
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

    payload = {
        "language": result.get("language", args.language),
        "duration": round(duration, 3),
        "segments": segments,
        "words": all_words,
    }

    output_path = args.output
    if output_path is None:
        base = args.audio.rsplit(".", 1)[0]
        output_path = f"{base}.captions.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"OK: {len(all_words)} palavras -> {output_path}", file=sys.stderr)
    # Tambem ecoa o JSON no stdout para pipelines.
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
