#!/usr/bin/env bash
# Valida Dynatrace como destino OTLP (fan-out OTel Collector → Tempo + Dynatrace SaaS).
#
# Uso:
#   ./utils/validate-dynatrace-otlp.sh              # estático + cluster si hay oc
#   ./utils/validate-dynatrace-otlp.sh --static     # solo helm/manifests
#   DT_ENV_ID=abc12345 ./utils/validate-dynatrace-otlp.sh --egress  # prueba HTTPS al tenant
#
# Requiere en cluster (modo saas):
#   - Secret otel-dynatrace-ingest (key apiToken) en istio-system
#   - OpenTelemetryCollector otel con exporter otlphttp/dynatrace
#   - values con environmentId real (no YOUR_ENV_ID)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SCRIPT_DIR}/.."
CHART="${ROOT}/helm-charts/observability"
VALUES="${CHART}/values-cluster-bbgmb-dynatrace.yaml"
NS="istio-system"
COLLECTOR_NAME="otel"
STATIC_ONLY=false
EGRESS_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --static) STATIC_ONLY=true ;;
    --egress) EGRESS_ONLY=true ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

pass() { echo "[OK]   $*"; }
fail() { echo "[FAIL] $*" >&2; FAILURES=$((FAILURES + 1)); }
warn() { echo "[WARN] $*"; }
info() { echo "[INFO] $*"; }

FAILURES=0

validate_static() {
  info "Validación estática (Helm / manifiestos)..."

  if ! command -v helm >/dev/null 2>&1; then
    fail "helm no encontrado"
    return
  fi

  local rendered
  rendered="$(helm template observability "$CHART" -f "$VALUES" \
    --show-only charts/otel-collector/templates/open-telemetry-collector.yaml 2>/dev/null)" || {
    fail "helm template observability falló"
    return
  }

  if grep -q 'otlphttp/dynatrace' <<<"$rendered"; then
    pass "Exporter otlphttp/dynatrace presente (HTTP, no gRPC)"
  else
    fail "Falta exporter otlphttp/dynatrace"
  fi

  if grep -q 'exporters: \[debug, otlp/tempo, otlphttp/dynatrace\]' <<<"$rendered"; then
    pass "Pipeline traces con fan-out: debug + Tempo + Dynatrace"
  else
    fail "Pipeline traces no tiene los tres exporters esperados"
  fi

  if grep -q 'DT_API_TOKEN' <<<"$rendered"; then
    pass "Token Dynatrace inyectado vía env DT_API_TOKEN"
  else
    fail "Falta env DT_API_TOKEN en el collector"
  fi

  local endpoint
  endpoint="$(grep -A3 'otlphttp/dynatrace:' <<<"$rendered" | grep 'endpoint:' | head -1 | awk -F'"' '{print $2}')"
  if [[ "$endpoint" == *"YOUR_ENV_ID"* ]]; then
    warn "environmentId sigue siendo YOUR_ENV_ID — sustituye en values-cluster-bbgmb-dynatrace.yaml o usa setup-dynatrace-saas-bbgmb.sh"
  elif [[ "$endpoint" =~ ^https://[a-zA-Z0-9-]+\.live\.dynatrace\.com/api/v2/otlp$ ]]; then
    pass "Endpoint OTLP SaaS: $endpoint"
  else
    warn "Endpoint inesperado: ${endpoint:-<vacío>}"
  fi

  if ! grep -q 'exporters: \[debug, otlp/tempo, otlphttp/dynatrace\]' <<<"$rendered"; then
    :
  fi

  # Métricas/logs no deben ir a Dynatrace (solo trazas)
  if grep -A2 'metrics:' <<<"$rendered" | grep -q 'otlphttp/dynatrace'; then
    fail "Pipeline metrics exporta a Dynatrace (solo traces debe hacer fan-out)"
  else
    pass "Pipeline metrics no envía a Dynatrace"
  fi
}

validate_cluster() {
  info "Validación en cluster..."

  if ! command -v oc >/dev/null 2>&1; then
    warn "oc no disponible — omitiendo checks de cluster"
    return
  fi

  if ! oc whoami >/dev/null 2>&1; then
    warn "Sin sesión oc — ejecuta: oc login https://api.cluster-bbgmb.dyn.redhatworkshops.io:6443"
    return
  fi

  pass "Sesión oc: $(oc whoami) @ $(oc whoami --show-server)"

  if oc get secret otel-dynatrace-ingest -n "$NS" >/dev/null 2>&1; then
    pass "Secret otel-dynatrace-ingest existe en $NS"
  else
    fail "Secret otel-dynatrace-ingest no encontrado en $NS"
  fi

  if ! oc get opentelemetrycollector "$COLLECTOR_NAME" -n "$NS" >/dev/null 2>&1; then
    fail "OpenTelemetryCollector $COLLECTOR_NAME no existe en $NS"
    return
  fi

  local exporters traces_endpoint
  exporters="$(oc get opentelemetrycollector "$COLLECTOR_NAME" -n "$NS" -o jsonpath='{.spec.config.exporters}' 2>/dev/null)"
  if [[ "$exporters" == *"otlphttp/dynatrace"* ]]; then
    pass "CR otel incluye exporter otlphttp/dynatrace"
  else
    fail "CR otel sin exporter otlphttp/dynatrace (¿Argo sincronizado con values Dynatrace?)"
  fi

  traces_endpoint="$(oc get opentelemetrycollector "$COLLECTOR_NAME" -n "$NS" \
    -o jsonpath='{.spec.config.exporters.otlphttp/dynatrace.endpoint}' 2>/dev/null)"
  if [[ -n "$traces_endpoint" && "$traces_endpoint" != *"YOUR_ENV_ID"* ]]; then
    pass "Endpoint en cluster: $traces_endpoint"
  else
    fail "Endpoint inválido o placeholder en cluster: ${traces_endpoint:-vacío}"
  fi

  local ready
  ready="$(oc get pods -n "$NS" -l app.kubernetes.io/name=opentelemetry-collector \
    -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || true)"
  if [[ "$ready" == "true" ]]; then
    pass "Pod del collector Running/Ready"
  else
    fail "Collector no Ready en $NS"
    oc get pods -n "$NS" -l app.kubernetes.io/name=opentelemetry-collector 2>/dev/null || true
  fi

  info "Últimas líneas del collector (buscar errores otlphttp/export)..."
  local log_tail
  log_tail="$(oc logs -n "$NS" -l app.kubernetes.io/name=opentelemetry-collector --tail=80 2>/dev/null || true)"
  if [[ -z "$log_tail" ]]; then
    warn "No se pudieron leer logs del collector"
  elif grep -qiE 'otlphttp/dynatrace.*(error|failed|401|403|refused)' <<<"$log_tail"; then
    fail "Logs del collector muestran errores hacia Dynatrace"
    grep -iE 'otlphttp|dynatrace|export.*fail|401|403' <<<"$log_tail" | tail -5 >&2 || true
  else
    pass "Sin errores obvios de export Dynatrace en logs recientes"
  fi

  validate_egress_from_cluster "$traces_endpoint"
}

validate_egress_from_cluster() {
  local endpoint="${1:-}"
  [[ -n "${DT_ENV_ID:-}" ]] || endpoint="${endpoint:-}"
  validate_egress "$endpoint"
}

validate_egress() {
  local endpoint="${1:-}"
  local env_id="${DT_ENV_ID:-}"

  if [[ -z "$endpoint" && -n "$env_id" ]]; then
    endpoint="https://${env_id}.live.dynatrace.com/api/v2/otlp"
  fi

  [[ -n "$endpoint" ]] || {
    warn "Sin endpoint para prueba egress (define DT_ENV_ID o despliega collector)"
    return
  }

  if [[ "$endpoint" == *"YOUR_ENV_ID"* ]]; then
    fail "No se puede probar egress con placeholder YOUR_ENV_ID"
    return
  fi

  info "Prueba egress HTTPS → $endpoint"

  local token=""
  if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
    token="$(oc get secret otel-dynatrace-ingest -n "$NS" -o jsonpath='{.data.apiToken}' 2>/dev/null | base64 -d 2>/dev/null || true)"
  fi
  [[ -n "${DT_API_TOKEN:-}" ]] && token="$DT_API_TOKEN"

  if [[ -z "$token" ]]; then
    warn "Sin token (Secret o DT_API_TOKEN) — solo comprobación TCP/TLS"
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "$endpoint" 2>/dev/null || echo "000")"
    if [[ "$code" =~ ^(200|400|405|415|404)$ ]]; then
      pass "Egress alcanza el endpoint Dynatrace (HTTP $code)"
    else
      fail "Egress falló o código inesperado: HTTP $code"
    fi
    return
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 15 \
    -X POST \
    -H "Authorization: Api-Token ${token}" \
    -H "Content-Type: application/x-protobuf" \
    --data-binary '' \
    "$endpoint/v1/traces" 2>/dev/null || echo "000")"

  case "$code" in
    200|204|400|415)
      pass "Token y egress OK hacia Dynatrace OTLP (HTTP $code en POST vacío es esperable)"
      ;;
    401|403)
      fail "Dynatrace rechazó el token (HTTP $code) — revisa scope openTelemetryTrace.ingest"
      ;;
    000)
      fail "Sin conectividad HTTPS al tenant (firewall/proxy/DNS)"
      ;;
    *)
      warn "Respuesta HTTP $code — revisar manualmente en Dynatrace UI"
      ;;
  esac
}

main() {
  if [[ "$EGRESS_ONLY" == true ]]; then
    validate_egress
    exit "$FAILURES"
  fi

  validate_static

  if [[ "$STATIC_ONLY" != true ]]; then
    validate_cluster
  fi

  echo ""
  if [[ "$FAILURES" -eq 0 ]]; then
    info "Validación completada sin fallos."
    info "Siguiente: ./utils/generate-traffic.sh 30 y en Dynatrace → Distributed traces → service.name=productpage.bookinfo"
    exit 0
  fi

  fail "Validación con $FAILURES error(es)."
  exit 1
}

main
