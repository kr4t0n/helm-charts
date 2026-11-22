{{/*
Name of the Secret rendered from `config`.
*/}}
{{- define "cliproxyapi.configSecretName" -}}
{{- printf "%s-config" (include "common.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Directory holding config.yaml and every file the app writes: the data volume's
mount path. Also the container's working directory and HOME.
*/}}
{{- define "cliproxyapi.dataDir" -}}
{{- (dig "volumes" "data" "mountPath" "" (.Values.persistence | default dict)) | default "/data" }}
{{- end }}

{{/*
The config seeded into the data volume: `config`, with server.port defaulted to
service.port so the probes and the Service hit the port the app listens on.
*/}}
{{- define "cliproxyapi.config" -}}
{{- $config := deepCopy (.Values.config | default dict) -}}
{{- $server := get $config "server" | default dict -}}
{{- if and (hasKey $server "port") (ne (toString $server.port) (toString .Values.service.port)) -}}
{{- fail (printf "cliproxyapi: config.server.port (%v) must equal service.port (%v)" $server.port .Values.service.port) -}}
{{- end -}}
{{- $_ := set $server "port" .Values.service.port -}}
{{- $_ = set $config "server" $server -}}
{{- toYaml $config }}
{{- end }}
