# ==========================================
# ETAPA 1: Builder (Compilación de dependencias)
# ==========================================
FROM python:3.11-slim-bookworm AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --upgrade pip --no-cache-dir

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==========================================
# ETAPA 2: Runtime Hardened (Distroless Non-Root)
# ==========================================
FROM gcr.io/distroless/python3-debian12:nonroot

WORKDIR /app

ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages

COPY --from=builder /install /usr/local
COPY --chown=nonroot:nonroot main.py /app/main.py

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
