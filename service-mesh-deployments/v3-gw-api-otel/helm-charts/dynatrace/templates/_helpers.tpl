{{- define "dynatrace.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dynatrace.telemetryIngest.service" -}}
{{- if .Values.dynaKube.telemetryIngest.serviceName -}}
{{- .Values.dynaKube.telemetryIngest.serviceName -}}
{{- else -}}
{{- printf "%s-telemetry-ingest" .Values.dynaKube.name -}}
{{- end -}}
{{- end }}

{{- define "dynatrace.telemetryIngest.endpoint" -}}
{{- printf "http://%s.%s.svc.cluster.local:4318" (include "dynatrace.telemetryIngest.service" .) .Values.namespace -}}
{{- end }}
