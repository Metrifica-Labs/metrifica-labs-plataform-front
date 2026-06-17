FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir "setuptools<81" wheel \
    && pip install --no-cache-dir --no-build-isolation -r requirements.txt

ARG MODEL_NAME=small
ENV MODEL_NAME=${MODEL_NAME}
# Baixa o modelo no build para nao depender de rede na primeira requisicao.
RUN python -c "import whisper; whisper.load_model('${MODEL_NAME}')"

COPY app.py .

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
