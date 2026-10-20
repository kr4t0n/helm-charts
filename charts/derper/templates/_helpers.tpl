{{/*
Name of the kubernetes.io/tls Secret holding the certificate for `hostname`.
*/}}
{{- define "derper.certSecretName" -}}
{{- if .Values.certificate.create -}}
{{- printf "%s-tls" (include "common.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- else -}}
{{- required "derper: set certificate.existingSecret when certificate.create is false" .Values.certificate.existingSecret }}
{{- end -}}
{{- end }}

{{/*
Base name derper uses for <certdir>/<name>.crt and .key: the hostname with
everything but letters, digits, '-' and '.' removed (cmd/derper/cert.go).
*/}}
{{- define "derper.certFileName" -}}
{{- regexReplaceAll "[^a-zA-Z0-9.-]" .Values.hostname "" }}
{{- end }}
