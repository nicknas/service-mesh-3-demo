{{- define "otel-collector.dynatrace.endpoint" -}}
{{- if .Values.dynatrace.endpoint -}}
{{- .Values.dynatrace.endpoint -}}
{{- else if eq .Values.dynatrace.mode "ingest" -}}
{{- printf "http://%s:%d" .Values.dynatrace.ingest.service (.Values.dynatrace.ingest.port | int) -}}
{{- else -}}
{{- printf "https://%s.live.dynatrace.com/api/v2/otlp" .Values.dynatrace.environmentId -}}
{{- end -}}
{{- end }}

{{- define "otel-collector.dynatrace.saas" -}}
{{- if .Values.dynatrace.endpoint -}}
true
{{- else if eq .Values.dynatrace.mode "saas" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{- define "otel-collector.traces.exporters" -}}
debug, otlp/tempo{{- if .Values.dynatrace.enabled }}, otlphttp/dynatrace{{- end }}
{{- end }}
