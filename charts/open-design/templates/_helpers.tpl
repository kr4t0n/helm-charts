{{/*
Expand the name of the chart.
*/}}
{{- define "open-design.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "open-design.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "open-design.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels injected into all resources.
*/}}
{{- define "open-design.labels" -}}
helm.sh/chart: {{ include "open-design.chart" . }}
{{ include "open-design.selectorLabels" . }}
{{- if .Values.image.tag }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels used by Services and HPAs.
*/}}
{{- define "open-design.selectorLabels" -}}
app.kubernetes.io/name: {{ include "open-design.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
"true" when the API token comes from an existing Secret (local addition).
*/}}
{{- define "open-design.useExistingSecret" -}}
{{- if and .Values.existingSecret .Values.existingSecret.enabled }}true{{ end }}
{{- end }}

{{/*
Name and key of the Secret that the app and the auth-proxy init container read
the API token from: the existing Secret when enabled, otherwise the chart's own.
*/}}
{{- define "open-design.apiTokenSecretName" -}}
{{- if include "open-design.useExistingSecret" . }}
{{- required "existingSecret.name is required when existingSecret.enabled is true" .Values.existingSecret.name }}
{{- else }}
{{- include "open-design.fullname" . }}
{{- end }}
{{- end }}

{{- define "open-design.apiTokenSecretKey" -}}
{{- if include "open-design.useExistingSecret" . }}
{{- .Values.existingSecret.key | default "OD_API_TOKEN" }}
{{- else }}
{{- "OD_API_TOKEN" }}
{{- end }}
{{- end }}
