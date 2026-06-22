{{/*
common._helpers — name / label / image helpers shared by all application
charts. Every template here is evaluated with the *consuming* chart's context,
so `.Chart`, `.Values` and `.Release` refer to the application chart, not to
this library.

Naming and the selector label are kept identical to the pre-library charts
(resource name == `.Release.Name`, selector == `app: <release>`) so that
existing releases can be upgraded in place without renaming PVCs or hitting the
immutable-selector error. Standard `app.kubernetes.io/*` labels are layered on
top additively.
*/}}

{{/*
Application name (used for the app.kubernetes.io/name label and the container
name). Defaults to the chart name.
*/}}
{{- define "common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified name used for every rendered object. Defaults to the release
name to match the legacy charts; `fullnameOverride` wins when set.
*/}}
{{- define "common.fullname" -}}
{{- default .Release.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart label value ("<name>-<version>").
*/}}
{{- define "common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Selector labels — the immutable subset used for Deployment/Service matching.
Intentionally just `app: <release>` to stay compatible with already-deployed
releases.
*/}}
{{- define "common.selectorLabels" -}}
app: {{ include "common.fullname" . }}
{{- end }}

{{/*
Common metadata labels: the selector label plus the standard recommended set.
Added additively, so they never change the selector.
*/}}
{{- define "common.labels" -}}
helm.sh/chart: {{ include "common.chart" . }}
{{ include "common.selectorLabels" . }}
app.kubernetes.io/name: {{ include "common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Image reference. `image.tag` wins; falls back to the chart's appVersion when
empty. (Charts that still want the mutable `latest` tag simply set
`image.tag: latest`.)
*/}}
{{- define "common.image" -}}
{{- $tag := default .Chart.AppVersion .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
PVC name for a persistence volume. Resolution order:
  1. an explicit `existingClaim`
  2. "<fullname>-<claimNameSuffix>" when `claimNameSuffix` is set non-empty
  3. "<fullname>"                    when `claimNameSuffix` is set empty ("")
  4. "<fullname>-<key>"              (default — the map key is the suffix)
Set `claimNameSuffix: ""` for a chart whose legacy single PVC was named exactly
after the release (e.g. tautulli); omit it for the suffixed multi-PVC charts.
Call with: {{ include "common.pvcName" (dict "ctx" . "key" $key "cfg" $cfg) }}
*/}}
{{- define "common.pvcName" -}}
{{- $suffix := .key -}}
{{- if hasKey .cfg "claimNameSuffix" -}}{{- $suffix = .cfg.claimNameSuffix -}}{{- end -}}
{{- if .cfg.existingClaim -}}
{{- .cfg.existingClaim -}}
{{- else if $suffix -}}
{{- printf "%s-%s" (include "common.fullname" .ctx) $suffix -}}
{{- else -}}
{{- include "common.fullname" .ctx -}}
{{- end -}}
{{- end }}
