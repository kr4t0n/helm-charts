{{/*
common.deployment — the standard single-container Deployment used by every
application chart. Per-app variation is driven entirely by values:

  image.{repository,tag,pullPolicy}   container image
  replicaCount                        replica count (default 1)
  strategy                            verbatim update strategy (see below)
  service.port                        primary container port (named "http")
  service.hostPort                    when true, also bind http on the host
  extraPorts                          additional container ports (list)
  workingDir                          optional container workingDir
  resources                           optional resource requests/limits
  existingSecret.{enabled,name}       optional envFrom secretRef
  extraEnvs                           optional env list
  probes.{startup,liveness,readiness} verbatim container probes (see below)
  persistence.{enabled,volumes}       map of named PVC-backed volumes
  extraVolumes / extraVolumeMounts    free-form additions
  extraInitContainers                 free-form initContainers (list)
  podAnnotations / imagePullSecrets   optional pod-level settings
  nodeSelector / tolerations / affinity

Probes are passed through verbatim, so any probe kind works (httpGet, exec,
tcpSocket, grpc) without this template knowing about it. Each of the three is
independently optional; a chart that sets no `probes` renders exactly as before
they existed.

`strategy` is likewise verbatim. Leave it unset for the Kubernetes default
(RollingUpdate 25%/25%); set `type: Recreate` for a singleton app on a
ReadWriteOnce volume or a hostPort. At replicaCount 1 the default rounds to
maxSurge 1 / maxUnavailable 0, i.e. "create the replacement before retiring the
old pod" — which deadlocks against a volume the old pod still holds, or silently
runs two instances against the same state if both land on one node.

Define `startup` whenever `liveness` is set on an app with a slow first boot.
Without it, liveness starts counting immediately and will kill a container that
is still migrating a database or building an index — turning a slow start into
a crash loop against half-applied state.
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
  {{- with .Values.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
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
      {{- with .Values.extraInitContainers }}
      initContainers:
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
          {{- with .Values.probes }}
          {{- with .startup }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .liveness }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .readiness }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
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
