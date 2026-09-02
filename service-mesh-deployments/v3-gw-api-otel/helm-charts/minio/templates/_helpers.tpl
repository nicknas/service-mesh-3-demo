{{- define "minio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "minio.fullname" -}}
{{- printf "%s" (include "minio.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "minio.endpoint" -}}
{{- printf "http://%s.%s.svc.cluster.local:%d" (include "minio.fullname" .) .Values.namespace (.Values.service.port | int) }}
{{- end }}
