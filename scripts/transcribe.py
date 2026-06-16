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

Alternativa sem linha de comando: scripts/transcribe_gui.py (app com interface
grafica, ver scripts/README_GUI.md).
"""
import sys
import json
import argparse

from transcribe_core import transcribe_audio

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

    payload = transcribe_audio(
        args.audio,
        model_name=args.model,
        language=args.language,
        on_progress=lambda msg: print(msg, file=sys.stderr),
    )

    output_path = args.output
    if output_path is None:
        base = args.audio.rsplit(".", 1)[0]
        output_path = f"{base}.captions.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"OK: {len(payload['words'])} palavras -> {output_path}", file=sys.stderr)
    # Tambem ecoa o JSON no stdout para pipelines.
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
