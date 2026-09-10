{{- define "otel-collector.dynatrace.endpoint" -}}
{{- if .Values.dynatrace.endpoint -}}
{{- .Values.dynatrace.endpoint -}}
{{- else -}}
{{- printf "https://%s.live.dynatrace.com/api/v2/otlp" .Values.dynatrace.environmentId -}}
{{- end -}}
{{- end }}

{{- define "otel-collector.traces.exporters" -}}
debug, otlp/tempo{{- if .Values.dynatrace.enabled }}, otlphttp/dynatrace{{- end }}
{{- end }}
