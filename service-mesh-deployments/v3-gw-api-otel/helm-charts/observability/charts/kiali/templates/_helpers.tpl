{{- define "kiali.tempo.gatewayService" -}}
{{- printf "%s-%s-gateway" .Values.tracing.tempoStack.name .Values.tracing.tempoStack.name -}}
{{- end }}

{{- define "kiali.tempo.internalUrl" -}}
{{- printf "https://%s.%s.svc.cluster.local:8080/api/traces/v1/%s/tempo" (include "kiali.tempo.gatewayService" .) .Values.tracing.tempoStack.namespace .Values.tracing.tempoStack.tenant -}}
{{- end }}

{{- define "kiali.tempo.healthCheckUrl" -}}
{{- printf "https://%s.%s.svc.cluster.local:8080/api/traces/v1/%s/tempo/api/echo" (include "kiali.tempo.gatewayService" .) .Values.tracing.tempoStack.namespace .Values.tracing.tempoStack.tenant -}}
{{- end }}

{{- define "kiali.tempo.externalUrl" -}}
{{- printf "https://%s-%s.%s/api/traces/v1/%s/search" (include "kiali.tempo.gatewayService" .) .Values.tracing.tempoStack.namespace .Values.tracing.clusterDomain .Values.tracing.tempoStack.tenant -}}
{{- end }}
