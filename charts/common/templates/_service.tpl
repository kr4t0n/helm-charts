{{/*
common.service — Service exposing the primary "http" port, plus any entries in
`service.extraPorts`. Selector is the legacy `app: <release>` label.
*/}}
{{- define "common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
    {{- with .Values.service.extraPorts }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  selector:
    {{- include "common.selectorLabels" . | nindent 4 }}
{{- end }}
