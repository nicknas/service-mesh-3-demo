{{- define "logging.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "logging.fullname" -}}
{{- printf "%s" (include "logging.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "logging.labels" -}}
app.kubernetes.io/name: {{ include "logging.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "logging.lokiStack.gatewayService" -}}
{{- printf "%s-gateway-http" .Values.lokiStack.name -}}
{{- end }}

{{- define "logging.lokiStack.pushUrl" -}}
{{- printf "https://%s.%s.svc.cluster.local:8080/api/logs/v1/%s/loki/api/v1/push" (include "logging.lokiStack.gatewayService" .) .Values.lokiStack.namespace .Values.lokiStack.tenant -}}
{{- end }}

{{- define "logging.bookinfoAppSelector" -}}
{{- join ", " .Values.alloy.bookinfo.apps }}
{{- end }}
