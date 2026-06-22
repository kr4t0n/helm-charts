{{/*
common.ingress — a single Ingress named after the release, using the
conventional schema:

  ingress:
    enabled: true
    className: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.tls.certresolver: dnspod
    hosts:
      - host: auth.example.com    # object form (paths optional, default "/")
      - other.example.com         # bare-string form also accepted
    tls:
      - hosts:
          - auth.example.com
        # secretName: auth-tls    # optional (omit when the controller manages certs)
    # path: /                     # default path when a host doesn't specify one
    # pathType: Prefix            # default pathType

Each `hosts` entry may be a bare hostname string, `{host: <name>}`, or
`{host: <name>, paths: [{path, pathType}, ...]}`. Renders nothing when
`ingress.enabled` is false.
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
    {{- $host := . -}}
    {{- $hostPaths := list (dict "path" $path "pathType" $pathType) -}}
    {{- if kindIs "map" . -}}
      {{- $host = .host -}}
      {{- with .paths }}{{- $hostPaths = . -}}{{- end -}}
    {{- end }}
    - host: {{ $host | quote }}
      http:
        paths:
          {{- range $hostPaths }}
          - path: {{ .path | default $path }}
            pathType: {{ .pathType | default $pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
