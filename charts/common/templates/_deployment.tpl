{{/*
common.deployment — the standard single-container Deployment used by every
application chart. Per-app variation is driven entirely by values:

  image.{repository,tag,pullPolicy}   container image
  replicaCount                        replica count (default 1)
  service.port                        primary container port (named "http")
  service.hostPort                    when true, also bind http on the host
  extraPorts                          additional container ports (list)
  workingDir                          optional container workingDir
  resources                           optional resource requests/limits
  existingSecret.{enabled,name}       optional envFrom secretRef
  extraEnvs                           optional env list
  persistence.{enabled,volumes}       map of named PVC-backed volumes
  extraVolumes / extraVolumeMounts    free-form additions
  podAnnotations / imagePullSecrets   optional pod-level settings
  nodeSelector / tolerations / affinity
*/}}
{{- define "common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount | default 1 }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.labels" . | nindent 8 }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ include "common.name" . }}
          image: {{ include "common.image" . | quote }}
          imagePullPolicy: {{ .Values.image.pullPolicy | default .Values.imagePullPolicy | default "IfNotPresent" }}
          {{- with .Values.workingDir }}
          workingDir: {{ . }}
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
              {{- if .Values.service.hostPort }}
              hostPort: {{ .Values.service.port }}
              {{- end }}
            {{- with .Values.extraPorts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if and .Values.existingSecret .Values.existingSecret.enabled }}
          envFrom:
            - secretRef:
                name: {{ .Values.existingSecret.name }}
          {{- end }}
          {{- with .Values.extraEnvs }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if or (and .Values.persistence .Values.persistence.enabled .Values.persistence.volumes) .Values.extraVolumeMounts }}
          volumeMounts:
            {{- if and .Values.persistence .Values.persistence.enabled }}
            {{- range $key, $cfg := .Values.persistence.volumes }}
            - name: {{ $key }}-volume
              mountPath: {{ $cfg.mountPath }}
              {{- with $cfg.subPath }}
              subPath: {{ . }}
              {{- end }}
            {{- end }}
            {{- end }}
            {{- with .Values.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
      {{- if or (and .Values.persistence .Values.persistence.enabled .Values.persistence.volumes) .Values.extraVolumes }}
      volumes:
        {{- if and .Values.persistence .Values.persistence.enabled }}
        {{- range $key, $cfg := .Values.persistence.volumes }}
        - name: {{ $key }}-volume
          persistentVolumeClaim:
            claimName: {{ include "common.pvcName" (dict "ctx" $ "key" $key "cfg" $cfg) }}
        {{- end }}
        {{- end }}
        {{- with .Values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
