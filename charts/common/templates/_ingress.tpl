{{/*
common.ingress — reproduces the pre-library `ingress.classes` schema: one
Ingress per entry in `ingress.classes`, named "<release>-<className>", each with
its own className / hosts / tls / annotations. Renders nothing when
`ingress.enabled` is false. Kept identical to the legacy charts so existing
ingress values (and the resulting objects) are preserved on upgrade.
*/}}
{{- define "common.ingress" -}}
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "common.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
{{- $namespace := .Release.Namespace -}}
{{- $labels := include "common.labels" . -}}
{{- range $ingressConfig := .Values.ingress.classes }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}-{{ $ingressConfig.className }}
  namespace: {{ $namespace }}
  labels:
    {{- $labels | nindent 4 }}
  {{- with $ingressConfig.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  ingressClassName: {{ $ingressConfig.className }}
  {{- if $ingressConfig.tls }}
  tls:
    {{- range $ingressConfig.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      {{- if .secretName }}
      secretName: {{ .secretName | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
  rules:
    {{- range $ingressConfig.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- with .pathType }}
            pathType: {{ . }}
            {{- end }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end }}
