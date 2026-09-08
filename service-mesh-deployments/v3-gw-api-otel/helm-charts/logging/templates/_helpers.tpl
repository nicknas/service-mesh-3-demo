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

{{- define "logging.loki.endpoint" -}}
{{- printf "http://%s.%s.svc.cluster.local:%d/loki/api/v1/push" (include "logging.fullname" .) .Values.namespace (.Values.loki.service.port | int) }}
{{- end }}

{{- define "logging.bookinfoAppSelector" -}}
{{- join ", " .Values.alloy.bookinfo.apps }}
{{- end }}
