{{/*
Image reference: common.image ("<repository>:<tag or appVersion>"), plus
"@<digest>" when image.digest is set.
*/}}
{{- define "mariadb.image" -}}
{{- $ref := include "common.image" . -}}
{{- with .Values.image.digest -}}
{{- printf "%s@%s" $ref . -}}
{{- else -}}
{{- $ref -}}
{{- end -}}
{{- end }}

{{/*
Name of the Secret holding the passwords.
*/}}
{{- define "mariadb.secretName" -}}
{{- required "mariadb: set auth.existingSecret to a Secret holding the root password" .Values.auth.existingSecret -}}
{{- end }}
