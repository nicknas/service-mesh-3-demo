#!/usr/bin/env bash
# Despliega Dynatrace en cluster-bbgmb (mismo patrón que aso1-es-dev).
#
# Uso:
#   export DYNATRACE_API_TOKEN='dt0c01.XXXXXXXX'
#   ./utils/deploy-dynatrace-cluster-bbgmb.sh
#
# Opcional — copiar CA desde aso1 (con sesión oc apuntando a aso1):
#   COPY_CA_FROM_ASO1=true ./utils/deploy-dynatrace-cluster-bbgmb.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="${SCRIPT_DIR}/../helm-charts/dynatrace"
OPERATOR_CHART="${SCRIPT_DIR}/../helm-charts/dynatrace-operator"
VALUES_FILE="${CHART_DIR}/values-cluster-bbgmb.yaml"
NS="dynatrace-operator"
DYNKUBE_NAME="cluster-bbgmb-ch-es-work"

msg() { echo "[dynatrace] $*"; }
err() { echo "[dynatrace] ERROR: $*" >&2; exit 1; }

if ! command -v oc >/dev/null 2>&1; then
  err "oc no encontrado en PATH"
fi

if ! oc whoami >/dev/null 2>&1; then
  err "No hay sesión oc. Ejecuta primero:\n  oc login https://api.cluster-bbgmb.dyn.redhatworkshops.io:6443 -u admin -p '...' --insecure-skip-tls-verify=true"
fi

SERVER="$(oc whoami --show-server)"
if [[ "${SERVER}" != *"cluster-bbgmb"* ]]; then
  err "La sesión oc no apunta a cluster-bbgmb (actual: ${SERVER})"
fi

msg "Cluster: ${SERVER}"

# --- Operador ---
if ! oc get subscription dynatrace-operator -n "${NS}" >/dev/null 2>&1; then
  msg "Instalando Dynatrace Operator (certified-operators)..."
  helm upgrade --install dynatrace-operator "${OPERATOR_CHART}" -n "${NS}" --create-namespace
  msg "Esperando CSV Succeeded..."
  for i in $(seq 1 60); do
    PHASE="$(oc get csv -n "${NS}" -o jsonpath='{.items[?(@.spec.displayName=="Dynatrace Operator")].status.phase}' 2>/dev/null || true)"
    if [[ "${PHASE}" == "Succeeded" ]]; then
      break
    fi
    sleep 10
  done
else
  msg "Operador ya instalado en ${NS}"
fi

# --- Secret apiToken ---
if [[ -z "${DYNATRACE_API_TOKEN:-}" ]]; then
  err "Define DYNATRACE_API_TOKEN con el apiToken del tenant Managed BBVA"
fi

if oc get secret dynakube -n "${NS}" >/dev/null 2>&1; then
  msg "Secret dynakube ya existe — no se sobrescribe"
else
  msg "Creando Secret dynakube..."
  oc create secret generic dynakube -n "${NS}" \
    --from-literal=apiToken="${DYNATRACE_API_TOKEN}"
fi

# --- CA corporativa ---
if oc get configmap ca-dynatrace -n "${NS}" >/dev/null 2>&1; then
  msg "ConfigMap ca-dynatrace ya existe"
elif [[ "${COPY_CA_FROM_ASO1:-false}" == "true" ]]; then
  msg "Copiando ca-dynatrace desde contexto aso1 (debes tener kubeconfig/contexto aso1 disponible)..."
  ASO1_CTX="${ASO1_CONTEXT:-}"
  if [[ -n "${ASO1_CTX}" ]]; then
    oc --context="${ASO1_CTX}" get configmap ca-dynatrace -n "${NS}" -o yaml \
      | oc apply -f -
  else
    err "COPY_CA_FROM_ASO1=true requiere ASO1_CONTEXT en kubeconfig"
  fi
else
  msg "AVISO: falta ConfigMap ca-dynatrace. Créalo manualmente o usa COPY_CA_FROM_ASO1=true"
  msg "  oc create configmap ca-dynatrace -n ${NS} --from-file=certs=/ruta/a/ca.pem"
fi

# --- Etiquetar nodos para OneAgent ---
msg "Etiquetando nodos worker para OneAgent..."
for node in $(oc get nodes -l node-role.kubernetes.io/worker -o name); do
  oc label "${node}" dynatraceOneAgent=enabled --overwrite
done

# --- DynaKube ---
msg "Aplicando DynaKube (${DYNKUBE_NAME})..."
helm upgrade --install dynatrace "${CHART_DIR}" -n "${NS}" -f "${VALUES_FILE}"

msg "Estado:"
oc get dynakube -n "${NS}"
oc get pods -n "${NS}" | grep -E 'NAME|oneagent|activegate|dynatrace-operator' || true

msg "Listo. Comprueba en Dynatrace Managed el cluster '${DYNKUBE_NAME}'."
