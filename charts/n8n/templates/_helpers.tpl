{{/*
Expand the name of the chart.
*/}}
{{- define "n8n.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
*/}}
{{- define "n8n.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "n8n" .Values.nameOverride }}
{{- if or (contains "n8n" .Release.Name) (eq .Release.Name "n8n") }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "n8n.labels" -}}
helm.sh/chart: {{ include "n8n.chart" . }}
{{ include "n8n.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "n8n.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Chart name and version
*/}}
{{- define "n8n.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "n8n.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "n8n.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- .Values.serviceAccount.name }}
{{- end }}
{{- end -}}

{{/*
Validate values — called once from deployment-main.yaml to fail fast on bad config.
*/}}
{{- define "n8n.validate" -}}

{{/* --- Queue mode infrastructure --- */}}
{{- if .Values.queueMode.enabled -}}
{{- if not .Values.database.useExternal -}}
{{- fail "database.useExternal must be true when queueMode.enabled=true. Queue mode requires external PostgreSQL." -}}
{{- end -}}
{{- if not .Values.database.host -}}
{{- fail "database.host is required when queueMode.enabled=true. Set it to your PostgreSQL hostname." -}}
{{- end -}}
{{- if not .Values.redis.enabled -}}
{{- fail "redis.enabled must be true when queueMode.enabled=true. Queue mode requires Redis." -}}
{{- end -}}
{{- if not .Values.redis.host -}}
{{- fail "redis.host is required when queueMode.enabled=true. Set it to your Redis hostname." -}}
{{- end -}}
{{- end -}}

{{/* --- Standalone mode constraints --- */}}
{{- if not .Values.queueMode.enabled -}}
{{- if not .Values.persistence.enabled -}}
{{- fail "persistence.enabled must be true when queueMode.enabled=false. Standalone mode uses SQLite which requires persistent storage." -}}
{{- end -}}
{{- if .Values.multiMain.enabled -}}
{{- fail "multiMain.enabled=true requires queueMode.enabled=true" -}}
{{- end -}}
{{- if .Values.webhookProcessor.enabled -}}
{{- fail "webhookProcessor.enabled=true requires queueMode.enabled=true" -}}
{{- end -}}
{{- end -}}

{{/* --- Webhook processor --- */}}
{{- if and .Values.ingress.webhookProcessor.enabled (not .Values.webhookProcessor.enabled) -}}
{{- fail "ingress.webhookProcessor.enabled=true requires webhookProcessor.enabled=true" -}}
{{- end -}}

{{/* --- Multi-main --- */}}
{{- if and .Values.multiMain.enabled (lt (int .Values.multiMain.replicas) 2) -}}
{{- fail "multiMain.enabled=true requires multiMain.replicas >= 2" -}}
{{- end -}}

{{/* --- Task runners --- */}}
{{- if and .Values.taskRunners.enabled (ne .Values.taskRunners.mode "external") -}}
{{- fail "taskRunners.mode must be 'external'. This chart only supports external task runner sidecars." -}}
{{- end -}}

{{/* --- S3 --- */}}
{{- if .Values.s3.enabled -}}
{{- if not .Values.s3.bucket.name -}}
{{- fail "s3.bucket.name is required when s3.enabled=true" -}}
{{- end -}}
{{- if not .Values.s3.bucket.region -}}
{{- fail "s3.bucket.region is required when s3.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.s3.auth.autoDetect) (not .Values.s3.auth.accessKeyId) -}}
{{- fail "s3.auth.accessKeyId is required when s3.enabled=true and s3.auth.autoDetect=false" -}}
{{- end -}}
{{- if and .Values.s3.auth.autoDetect (not .Values.serviceAccount.awsRoleArn) -}}
{{- fail "serviceAccount.awsRoleArn is required when s3.auth.autoDetect=true (for IRSA)" -}}
{{- end -}}
{{- end -}}

{{/* --- License --- */}}
{{- if and .Values.license.enabled .Values.license.activationKey .Values.license.existingSecret.name -}}
{{- fail "license.activationKey and license.existingSecret.name are mutually exclusive. Use one or the other." -}}
{{- end -}}

{{/* --- Encryption key --- */}}
{{- if and (not .Values.secretRefs.existingSecret) (eq .Values.secretRefs.env.N8N_ENCRYPTION_KEY "change-me-to-a-long-random-key") -}}
{{- fail "secretRefs.env.N8N_ENCRYPTION_KEY must be changed from the default placeholder value, or provide secretRefs.existingSecret with your own Secret" -}}
{{- end -}}

{{- end -}}
