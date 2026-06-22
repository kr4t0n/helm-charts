{{/*
common.ingress — a single Ingress named after the release, using the
conventional schema:

  ingress:
    enabled: true
    className: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.tls.certresolver: dnspod
    hosts:
      - auth.example.com          # list of hostnames; each gets one rule
    tls:
      - hosts:
          - auth.example.com
        # secretName: auth-tls    # optional (omit when the controller manages certs)
    # path: /                     # optional, default "/"
    # pathType: Prefix            # optional, default "Prefix"

Renders nothing when `ingress.enabled` is false.
*/}}
{{- define "common.ingress" -}}
{{- if .Values.ingress.enabled -}}
{{- $fullName := include "common.fullname" . -}}
{{- $svcPort := .Values.service.port -}}
{{- $path := .Values.ingress.path | default "/" -}}
{{- $pathType := .Values.ingress.pathType | default "Prefix" -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $fullName }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- with .Values.ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ . | quote }}
      http:
        paths:
          - path: {{ $path }}
            pathType: {{ $pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
    {{- end }}
{{- end }}
{{- end }}
