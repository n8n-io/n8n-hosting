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
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Pod template labels. podLabels intentionally wins over commonLabels for
user-defined keys on pods only; chart-managed selector/identity labels are
always set by the chart.
*/}}
{{- define "n8n.podLabels" -}}
{{- $root := .root -}}
{{- $component := .component -}}
{{- $labels := dict -}}
{{- range $k, $v := ($root.Values.commonLabels | default dict) -}}
{{- $_ := set $labels $k $v -}}
{{- end -}}
{{- $_ := set $labels "helm.sh/chart" (include "n8n.chart" $root) -}}
{{- $_ := set $labels "app.kubernetes.io/name" (include "n8n.name" $root) -}}
{{- $_ := set $labels "app.kubernetes.io/instance" $root.Release.Name -}}
{{- if $root.Chart.AppVersion -}}
{{- $_ := set $labels "app.kubernetes.io/version" $root.Chart.AppVersion -}}
{{- end -}}
{{- $_ := set $labels "app.kubernetes.io/managed-by" $root.Release.Service -}}
{{- $_ := set $labels "app.kubernetes.io/component" $component -}}
{{- range $k, $v := ($root.Values.podLabels | default dict) -}}
{{- $_ := set $labels $k $v -}}
{{- end -}}
{{- toYaml $labels -}}
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
n8n image tag. Falls back to the chart's appVersion when image.tag is unset,
so a chart release always pins the n8n version it was built against.
*/}}
{{- define "n8n.imageTag" -}}
{{- default .Chart.AppVersion .Values.image.tag -}}
{{- end -}}

{{/*
Task runner image tag. Resolves taskRunners.image.tag, then image.tag, then
appVersion, so the sidecar tracks the n8n image unless deliberately overridden.
*/}}
{{- define "n8n.taskRunnerImageTag" -}}
{{- default (include "n8n.imageTag" .) .Values.taskRunners.image.tag -}}
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
Validate values. Called once from deployment-main.yaml to fail on bad config.
Every check adds its message to $errs instead of failing on the spot, so one
render reports every problem rather than making the user fix and re-run once
per mistake.
*/}}
{{- define "n8n.validate" -}}
{{- $errs := list -}}

{{/* --- Queue mode infrastructure --- */}}
{{- if .Values.queueMode.enabled -}}
{{- if not .Values.database.useExternal -}}
{{- $errs = append $errs "database.useExternal must be true when queueMode.enabled=true. Queue mode requires external PostgreSQL." -}}
{{- end -}}
{{- if not .Values.database.host -}}
{{- $errs = append $errs "database.host is required when queueMode.enabled=true. Set it to your PostgreSQL hostname." -}}
{{- end -}}
{{- if not .Values.redis.enabled -}}
{{- $errs = append $errs "redis.enabled must be true when queueMode.enabled=true. Queue mode requires Redis." -}}
{{- end -}}
{{- if not .Values.redis.host -}}
{{- $errs = append $errs "redis.host is required when queueMode.enabled=true. Set it to your Redis hostname." -}}
{{- end -}}
{{- end -}}

{{/* --- Standalone mode constraints --- */}}
{{- if not .Values.queueMode.enabled -}}
{{- if and (not .Values.persistence.enabled) (not .Values.database.useExternal) -}}
{{- $errs = append $errs "persistence.enabled must be true when queueMode.enabled=false and database.useExternal=false. Standalone mode requires persistent storage when no external database." -}}
{{- end -}}
{{- if .Values.multiMain.enabled -}}
{{- $errs = append $errs "multiMain.enabled=true requires queueMode.enabled=true" -}}
{{- end -}}
{{- if .Values.webhookProcessor.enabled -}}
{{- $errs = append $errs "webhookProcessor.enabled=true requires queueMode.enabled=true" -}}
{{- end -}}
{{- end -}}

{{/* --- Webhook processor --- */}}
{{- if and .Values.ingress.webhookProcessor.enabled (not .Values.webhookProcessor.enabled) -}}
{{- $errs = append $errs "ingress.webhookProcessor.enabled=true requires webhookProcessor.enabled=true" -}}
{{- end -}}

{{/* --- KEDA --- */}}
{{- if and .Values.keda.enabled .Values.queueMode.enabled .Values.keda.webhookProcessor.enabled .Values.webhookProcessor.enabled (not .Values.keda.webhookProcessor.triggers) -}}
{{- $errs = append $errs "keda.webhookProcessor.triggers is required when keda.webhookProcessor.enabled=true. KEDA rejects a ScaledObject with no triggers, so nothing would autoscale webhook processors. Add a trigger, or set keda.webhookProcessor.enabled=false to hold them at webhookProcessor.replicaCount." -}}
{{- end -}}

{{/* --- Multi-main --- */}}
{{- if and .Values.multiMain.enabled (lt (int .Values.multiMain.replicas) 2) -}}
{{- $errs = append $errs "multiMain.enabled=true requires multiMain.replicas >= 2" -}}
{{- end -}}

{{/* --- Task runners --- */}}
{{- if and .Values.taskRunners.enabled (ne .Values.taskRunners.mode "external") -}}
{{- $errs = append $errs "taskRunners.mode must be 'external'. This chart only supports external task runner sidecars." -}}
{{- end -}}

{{/* --- S3 --- */}}
{{- if .Values.s3.enabled -}}
{{- if not .Values.s3.bucket.name -}}
{{- $errs = append $errs "s3.bucket.name is required when s3.enabled=true" -}}
{{- end -}}
{{- if not .Values.s3.bucket.region -}}
{{- $errs = append $errs "s3.bucket.region is required when s3.enabled=true" -}}
{{- end -}}
{{- if and (not .Values.s3.auth.autoDetect) (not .Values.s3.auth.accessKeyId) -}}
{{- $errs = append $errs "s3.auth.accessKeyId is required when s3.enabled=true and s3.auth.autoDetect=false" -}}
{{- end -}}
{{- if and .Values.s3.auth.autoDetect (not .Values.serviceAccount.awsRoleArn) -}}
{{- $errs = append $errs "serviceAccount.awsRoleArn is required when s3.auth.autoDetect=true (for IRSA)" -}}
{{- end -}}
{{- end -}}

{{/* --- License --- */}}
{{- if and .Values.license.enabled .Values.license.activationKey .Values.license.existingSecret.name -}}
{{- $errs = append $errs "license.activationKey and license.existingSecret.name are mutually exclusive. Use one or the other." -}}
{{- end -}}

{{/* --- Encryption key --- */}}
{{- if and (not .Values.secretRefs.existingSecret) (eq .Values.secretRefs.env.N8N_ENCRYPTION_KEY "change-me-to-a-long-random-key") -}}
{{- $errs = append $errs "secretRefs.env.N8N_ENCRYPTION_KEY must be changed from the default placeholder value, or provide secretRefs.existingSecret with your own Secret" -}}
{{- end -}}

{{/* --- Service account --- */}}
{{- if and (not .Values.serviceAccount.create) (eq .Values.serviceAccount.name "n8n") -}}
{{- $errs = append $errs "serviceAccount.create=false but serviceAccount.name is still the chart default \"n8n\". Set serviceAccount.name to your pre-existing ServiceAccount, or to \"\" to use the namespace's default ServiceAccount." -}}
{{- end -}}

{{/* --- Pod labels --- */}}
{{- $reservedPodLabels := list "app.kubernetes.io/name" "app.kubernetes.io/instance" "app.kubernetes.io/component" "app.kubernetes.io/version" "app.kubernetes.io/managed-by" "helm.sh/chart" -}}
{{- range $k, $v := (.Values.podLabels | default dict) -}}
{{- if has $k $reservedPodLabels -}}
{{- $errs = append $errs (printf "podLabels.%q is a chart-managed selector/identity label and cannot be overridden. Reserved keys: %s" $k (join ", " $reservedPodLabels)) -}}
{{- end -}}
{{- if not (kindIs "string" $v) -}}
{{- $errs = append $errs (printf "podLabels.%q must be a string (got %s). Kubernetes labels are map[string]string; quote numeric or boolean values, e.g. %q: \"true\"." $k (kindOf $v) $k) -}}
{{- end -}}
{{- end -}}

{{/* A single problem is reported as-is, so its message reads the same as the check wrote it. */}}
{{- if eq (len $errs) 1 -}}
{{- fail (first $errs) -}}
{{- else if $errs -}}
{{- fail (printf "%d problems in your values:\n- %s" (len $errs) (join "\n- " $errs)) -}}
{{- end -}}

{{- end -}}

{{/*
Task runners on main pods: only in standalone mode.
In queue mode, manual executions are offloaded to workers (OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS),
so workers handle code execution and main pods do not need runner sidecars.
*/}}
{{- define "n8n.mainTaskRunnersEnabled" -}}
{{- if and .Values.taskRunners.enabled (not .Values.queueMode.enabled) -}}true{{- end -}}
{{- end -}}

{{/*
Whether KEDA will actually scale a component, and so whether a ScaledObject
renders for it. Empty triggers mean no scaler: KEDA requires spec.triggers and
rejects an object without them, so the chart renders none and the component
keeps the replica count it was given. That makes an empty trigger list the way
to run KEDA for one component and not the other.

Call with the root context and the component name, e.g.
  (dict "root" . "component" "worker")
*/}}
{{- define "n8n.kedaScalerEnabled" -}}
{{- $root := .root -}}
{{- if and $root.Values.keda.enabled $root.Values.queueMode.enabled -}}
{{- if eq .component "worker" -}}
{{- if and $root.Values.keda.worker.triggers (gt (int $root.Values.queueMode.workerReplicaCount) 0) -}}true{{- end -}}
{{- else if eq .component "webhook-processor" -}}
{{- if and $root.Values.keda.webhookProcessor.enabled $root.Values.webhookProcessor.enabled $root.Values.keda.webhookProcessor.triggers -}}true{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Whether an autoscaler owns a component's replica count, and so whether the
chart leaves spec.replicas off its Deployment and lets Kubernetes default it
to 1 on first create. KEDA owns the count wherever a ScaledObject renders,
and the built-in HPA owns it only whilst KEDA is off, since keda.enabled
replaces the worker and webhook HPAs.

Call with the root context and the component name, e.g.
  (dict "root" . "component" "worker")
*/}}
{{- define "n8n.autoscalerOwnsReplicas" -}}
{{- $root := .root -}}
{{- $hpaEnabled := ternary $root.Values.hpa.worker.enabled $root.Values.hpa.webhookProcessor.enabled (eq .component "worker") -}}
{{- if or (include "n8n.kedaScalerEnabled" .) (and $hpaEnabled (not $root.Values.keda.enabled)) -}}true{{- end -}}
{{- end -}}

{{/*
Annotation mapping for a KEDA ScaledObject: commonAnnotations with the
chart-managed pause annotations set over the top, so a user key can never
render twice. Renders nothing when there is nothing to annotate, so the
caller wraps it in `with` and writes the `annotations:` key itself.

Call with the root context and the keda.<component> values, e.g.
  (dict "root" . "componentValues" .Values.keda.worker)
*/}}
{{- define "n8n.kedaAnnotations" -}}
{{- $root := .root -}}
{{- $componentValues := .componentValues -}}
{{- $annotations := deepCopy ($root.Values.commonAnnotations | default dict) -}}
{{- if $componentValues.pause -}}
{{- $_ := set $annotations "autoscaling.keda.sh/paused" "true" -}}
{{/* 0 is falsy in Go templates, so unset has to be tested for by kind. */}}
{{- if not (kindIs "invalid" $componentValues.pausedReplicaCount) -}}
{{- $_ := set $annotations "autoscaling.keda.sh/paused-replicas" ($componentValues.pausedReplicaCount | toString) -}}
{{- end -}}
{{- end -}}
{{- if $annotations -}}
{{- toYaml $annotations -}}
{{- end -}}
{{- end -}}
