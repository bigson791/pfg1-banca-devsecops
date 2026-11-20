import os
import time
import uuid
from fastapi import FastAPI, HTTPException, Response
from pydantic import BaseModel, Field
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI(
    title="Core Bancario - API de Transferencias",
    version="1.0.0",
    docs_url=None,   # Deshabilita Swagger en producción por seguridad (hardening)
    redoc_url=None
)

# Métricas SRE para cálculo de SLI / SLO (Latencia y Tasa de Errores)
REQUEST_COUNT = Counter(
    "banca_http_requests_total",
    "Total de peticiones HTTP procesadas",
    ["method", "endpoint", "status"]
)
REQUEST_LATENCY = Histogram(
    "banca_http_request_duration_seconds",
    "Latencia de peticiones transaccionales en segundos",
    ["endpoint"]
)

# Secreto inyectado desde Azure Key Vault / Kubernetes Secrets (nunca en código)
DB_SIGNING_KEY = os.getenv("BANK_SIGNING_SECRET", "unconfigured-dev-key")
SIMULATE_FAILURE = os.getenv("SIMULATE_FAILURE", "false").lower() == "true"

class TransferRequest(BaseModel):
    cuenta_origen: str = Field(..., min_length=8, max_length=20, pattern="^[0-9]+$")
    cuenta_destino: str = Field(..., min_length=8, max_length=20, pattern="^[0-9]+$")
    monto: float = Field(..., gt=0, le=50000.0)
    moneda: str = Field(default="GTQ", pattern="^(GTQ|USD)$")

@app.get("/healthz")
def health_check():
    if SIMULATE_FAILURE:
        REQUEST_COUNT.labels("GET", "/healthz", "500").inc()
        raise HTTPException(status_code=500, detail="Degradación simulada en healthcheck")
    REQUEST_COUNT.labels("GET", "/healthz", "200").inc()
    return {"status": "healthy", "service": "banca-core-api", "version": "1.0.0"}

@app.post("/api/v1/transferencias")
def procesar_transferencia(tx: TransferRequest):
    inicio = time.perf_counter()

    # Simulación de fallo crítico para validar rollback automático en Canary
    if SIMULATE_FAILURE:
        REQUEST_COUNT.labels("POST", "/api/v1/transferencias", "500").inc()
        raise HTTPException(status_code=503, detail="Error transaccional simulado")

    if tx.cuenta_origen == tx.cuenta_destino:
        REQUEST_COUNT.labels("POST", "/api/v1/transferencias", "400").inc()
        raise HTTPException(status_code=400, detail="La cuenta origen y destino no pueden ser iguales")

    duracion = time.perf_counter() - inicio
    REQUEST_LATENCY.labels("/api/v1/transferencias").observe(duracion)
    REQUEST_COUNT.labels("POST", "/api/v1/transferencias", "200").inc()

    return {
        "estado": "APROBADA",
        "id_autorizacion": str(uuid.uuid4()),
        "monto": tx.monto,
        "moneda": tx.moneda,
        "firma_integridad_activa": DB_SIGNING_KEY != "unconfigured-dev-key"
    }
#test

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)