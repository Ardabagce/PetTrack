# PetTrack API. Build context = repository root (Coolify: Base Directory "/").
# Works with Dockerfile Location "/Dockerfile" or "/server/Dockerfile".
FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      tesseract-ocr tesseract-ocr-eng tesseract-ocr-deu tesseract-ocr-fra tesseract-ocr-spa tesseract-ocr-nld \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server/app.py .
COPY server/site ./site
ENV DATA_DIR=/data \
    CONTACT_EMAIL="arda@bagce.dev" \
    OPERATOR="Arda Bagce" \
    HOSTING="Hetzner, Germany (EU)"
VOLUME ["/data"]
EXPOSE 8000
HEALTHCHECK CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8000/health')"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--forwarded-allow-ips", "*"]
