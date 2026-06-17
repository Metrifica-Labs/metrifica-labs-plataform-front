"""
Servico HTTP que expõe o Whisper (baseado em meal-video/scripts/transcribe.py)
via FastAPI, para ser chamado por trás da Supabase Edge Function transcribe-audio.
"""
import os
import tempfile

import whisper
from fastapi import FastAPI, Header, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse

API_KEY = os.environ["API_KEY"]
MODEL_NAME = os.environ.get("MODEL_NAME", "small")

app = FastAPI()
model = whisper.load_model(MODEL_NAME)


def _check_api_key(x_api_key: str | None) -> None:
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="API key invalida")


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME}


@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
):
    _check_api_key(x_api_key)

    suffix = os.path.splitext(file.filename or "")[1] or ".audio"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await file.read())
        tmp_path = tmp.name

    try:
        result = model.transcribe(
            tmp_path,
            language="pt",
            verbose=False,
            word_timestamps=True,
        )
    finally:
        os.remove(tmp_path)

    segments = []
    all_words = []

    for i, s in enumerate(result["segments"]):
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

        segments.append({
            "id": i,
            "start": round(s["start"], 3),
            "end": round(s["end"], 3),
            "text": s["text"].strip(),
            "words": words,
        })

    return JSONResponse({"segments": segments, "words": all_words})
