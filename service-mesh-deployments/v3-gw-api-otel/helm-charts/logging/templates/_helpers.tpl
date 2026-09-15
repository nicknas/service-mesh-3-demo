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

{{- define "logging.lokiStack.gatewayCaConfigMap" -}}
{{- printf "%s-gateway-ca-bundle" .Values.lokiStack.name -}}
{{- end }}
