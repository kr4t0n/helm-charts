{{/*
common.pvc — one PersistentVolumeClaim per entry in `persistence.volumes`.
Each volume may override `storageClass`, `accessModes`, `size` and its claim
name (`claimNameSuffix` / `existingClaim`); otherwise the chart-level
`persistence` defaults apply. Volumes pointing at an `existingClaim` are skipped
(nothing to create). Renders nothing when persistence is disabled.

`storageClassName` is rendered unconditionally (empty -> null, i.e. use the
cluster default StorageClass) to stay byte-identical with the pre-library
charts. That matters for in-place upgrades: `storageClassName` is immutable on a
bound PVC, so emitting/omitting it differently than the live object would make
Helm attempt a forbidden patch. Set `persistence.storageClass` (or a per-volume
`storageClass`) to bind a specific class.
*/}}
{{- define "common.pvc" -}}
{{- if .Values.persistence.enabled -}}
{{- $top := . -}}
{{- range $key, $cfg := .Values.persistence.volumes }}
{{- if not $cfg.existingClaim }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "common.pvcName" (dict "ctx" $top "key" $key "cfg" $cfg) }}
  labels:
    {{- include "common.labels" $top | nindent 4 }}
  {{- with $cfg.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  storageClassName: {{ $cfg.storageClass | default $top.Values.persistence.storageClass }}
  accessModes:
    {{- toYaml ($cfg.accessModes | default $top.Values.persistence.accessModes) | nindent 4 }}
  resources:
    requests:
      storage: {{ required (printf "persistence.volumes.%s.size is required" $key) $cfg.size }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
