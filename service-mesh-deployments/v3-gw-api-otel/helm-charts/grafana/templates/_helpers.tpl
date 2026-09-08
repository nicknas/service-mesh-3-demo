{{- define "grafana.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "grafana.fullname" -}}
{{- printf "%s" (include "grafana.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "grafana.labels" -}}
app.kubernetes.io/name: {{ include "grafana.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "grafana.tempo.gatewayService" -}}
{{- printf "%s-%s-gateway" .Values.datasources.tempo.tempoStack.name .Values.datasources.tempo.tempoStack.name -}}
{{- end }}

{{- define "grafana.tempo.url" -}}
{{- printf "https://%s.%s.svc.cluster.local:8080/api/traces/v1/%s" (include "grafana.tempo.gatewayService" .) .Values.datasources.tempo.tempoStack.namespace .Values.datasources.tempo.tempoStack.tenant -}}
{{- end }}

{{- define "grafana.loki.url" -}}
{{- printf "http://%s.%s.svc.cluster.local:%d" .Values.datasources.loki.service .Values.datasources.loki.namespace (.Values.datasources.loki.port | int) -}}
{{- end }}
