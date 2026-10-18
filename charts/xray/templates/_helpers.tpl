{{/*
Name of the Secret rendered from `config`.
*/}}
{{- define "xray.configSecretName" -}}
{{- printf "%s-config" (include "common.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
