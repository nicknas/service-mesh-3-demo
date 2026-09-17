#!/usr/bin/env bash
# Activa Dynatrace SaaS en cluster-bbgmb (fan-out OTel → Tempo + Dynatrace).
#
# Requisitos:
#   - Tenant Dynatrace SaaS (trial o corporativo público)
#   - Token con scope openTelemetryTrace.ingest
#
# Uso:
#   export DT_ENV_ID='abc12345'
#   export DT_API_TOKEN='dt0c01.XXXXXXXX'
#   ./utils/setup-dynatrace-saas-bbgmb.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART="$SCRIPT_DIR/../helm-charts/observability"
VALUES="$CHART/values-cluster-bbgmb-dynatrace.yaml"
NS="istio-system"

err() { echo "[dynatrace-saas] ERROR: $*" >&2; exit 1; }

[[ -n "${DT_ENV_ID:-}" ]] || err "Define DT_ENV_ID (tenant SaaS, sin .live.dynatrace.com)"
[[ -n "${DT_API_TOKEN:-}" ]] || err "Define DT_API_TOKEN (scope openTelemetryTrace.ingest)"

if ! oc whoami >/dev/null 2>&1; then
  err "No hay sesión oc en cluster-bbgmb"
fi
[[ "$(oc whoami --show-server)" == *"cluster-bbgmb"* ]] || err "La sesión oc no apunta a cluster-bbgmb"

echo "[dynatrace-saas] Creando Secret otel-dynatrace-ingest..."
oc create secret generic otel-dynatrace-ingest -n "$NS" \
  --from-literal=apiToken="${DT_API_TOKEN}" \
  --dry-run=client -o yaml | oc apply -f -

TMP_VALUES="$(mktemp)"
sed "s/YOUR_ENV_ID/${DT_ENV_ID}/g" "$VALUES" > "$TMP_VALUES"

echo "[dynatrace-saas] Aplicando OpenTelemetryCollector con fan-out Dynatrace..."
helm template observability "$CHART" -f "$TMP_VALUES" \
  --show-only charts/otel-collector/templates/open-telemetry-collector.yaml \
  | oc apply -f -

rm -f "$TMP_VALUES"

echo "[dynatrace-saas] Esperando rollout del collector..."
oc rollout status deployment -n "$NS" -l app.kubernetes.io/name=opentelemetry-collector --timeout=120s 2>/dev/null \
  || oc get pods -n "$NS" -l app.kubernetes.io/name=opentelemetry-collector

echo "[dynatrace-saas] Validación OTLP..."
"${SCRIPT_DIR}/validate-dynatrace-otlp.sh" || true

echo "[dynatrace-saas] Genera tráfico: ./utils/generate-traffic.sh 30"
echo "[dynatrace-saas] En Dynatrace SaaS: Distributed traces → filtrar por service.name"
