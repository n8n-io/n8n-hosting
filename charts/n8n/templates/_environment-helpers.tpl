{{/*
S3 External Storage environment variables
*/}}
{{- define "n8n.s3Env" -}}
{{- if .Values.s3.enabled }}
# S3 External Storage Configuration
- name: N8N_DEFAULT_BINARY_DATA_MODE
  value: {{ .Values.s3.storage.mode | quote }}
- name: N8N_AVAILABLE_BINARY_DATA_MODES
  value: {{ .Values.s3.storage.availableModes | quote }}
- name: N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME
  value: {{ .Values.s3.bucket.name | quote }}
- name: N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION
  value: {{ .Values.s3.bucket.region | quote }}
{{- if .Values.s3.bucket.host }}
- name: N8N_EXTERNAL_STORAGE_S3_HOST
  value: {{ .Values.s3.bucket.host | quote }}
{{- end }}
{{- if .Values.s3.auth.autoDetect }}
- name: N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT
  value: "true"
{{- else }}
{{- if .Values.s3.auth.accessKeyId }}
- name: N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY
  value: {{ .Values.s3.auth.accessKeyId | quote }}
- name: AWS_ACCESS_KEY_ID
  value: {{ .Values.s3.auth.accessKeyId | quote }}
{{- end }}
{{- if .Values.s3.auth.secretAccessKeySecret.name }}
- name: N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.secretAccessKeySecret.name }}
      key: {{ .Values.s3.auth.secretAccessKeySecret.key }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.s3.auth.secretAccessKeySecret.name }}
      key: {{ .Values.s3.auth.secretAccessKeySecret.key }}
{{- end }}
{{- end }}
{{- if .Values.s3.storage.forcePathStyle }}
- name: N8N_EXTERNAL_STORAGE_S3_FORCE_PATH_STYLE
  value: "true"
{{- end }}
{{- with .Values.s3.storage.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Executions Configuration environment variables
*/}}
{{- define "n8n.executionsEnv" -}}
# Executions Configuration
{{- if and .Values.executions.timeout (ne (.Values.executions.timeout | int) -1) }}
- name: EXECUTIONS_TIMEOUT
  value: "{{ .Values.executions.timeout }}"
{{- end }}
{{- if .Values.executions.timeoutMax }}
- name: EXECUTIONS_TIMEOUT_MAX
  value: "{{ .Values.executions.timeoutMax }}"
{{- end }}
- name: EXECUTIONS_DATA_SAVE_ON_ERROR
  value: {{ .Values.executions.data.saveOnError | quote }}
- name: EXECUTIONS_DATA_SAVE_ON_SUCCESS
  value: {{ .Values.executions.data.saveOnSuccess | quote }}
- name: EXECUTIONS_DATA_SAVE_ON_PROGRESS
  value: "{{ .Values.executions.data.saveOnProgress }}"
- name: EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS
  value: "{{ .Values.executions.data.saveManualExecutions }}"
- name: EXECUTIONS_DATA_PRUNE
  value: "{{ .Values.executions.pruning.enabled }}"
{{- if .Values.executions.pruning.maxAge }}
- name: EXECUTIONS_DATA_MAX_AGE
  value: "{{ .Values.executions.pruning.maxAge }}"
{{- end }}
{{- if .Values.executions.pruning.maxCount }}
- name: EXECUTIONS_DATA_PRUNE_MAX_COUNT
  value: "{{ .Values.executions.pruning.maxCount }}"
{{- end }}
{{- if .Values.executions.pruning.hardDeleteBuffer }}
- name: EXECUTIONS_DATA_HARD_DELETE_BUFFER
  value: "{{ .Values.executions.pruning.hardDeleteBuffer }}"
{{- end }}
{{- if .Values.executions.pruning.hardDeleteInterval }}
- name: EXECUTIONS_DATA_PRUNE_HARD_DELETE_INTERVAL
  value: "{{ .Values.executions.pruning.hardDeleteInterval }}"
{{- end }}
{{- if .Values.executions.pruning.softDeleteInterval }}
- name: EXECUTIONS_DATA_PRUNE_SOFT_DELETE_INTERVAL
  value: "{{ .Values.executions.pruning.softDeleteInterval }}"
{{- end }}
{{- if and .Values.executions.concurrency.productionLimit (ne (.Values.executions.concurrency.productionLimit | int) -1) }}
- name: N8N_CONCURRENCY_PRODUCTION_LIMIT
  value: "{{ .Values.executions.concurrency.productionLimit }}"
{{- end }}
{{- with .Values.executions.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}

{{/*
License Configuration environment variables
*/}}
{{- define "n8n.licenseEnv" -}}
{{- if .Values.license.enabled }}
# License Configuration
{{- if .Values.license.activationKey }}
- name: N8N_LICENSE_ACTIVATION_KEY
  value: {{ .Values.license.activationKey | quote }}
{{- else if .Values.license.existingSecret.name }}
- name: N8N_LICENSE_ACTIVATION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.license.existingSecret.name }}
      key: {{ .Values.license.existingSecret.key }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Core n8n secrets environment variables
*/}}
{{- define "n8n.coreSecretsEnv" -}}
# Core n8n secrets
- name: N8N_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.secretRefs.existingSecret }}{{ .Values.secretRefs.existingSecret }}{{ else }}{{ include "n8n.fullname" . }}{{ end }}
      key: N8N_ENCRYPTION_KEY
- name: N8N_HOST
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.secretRefs.existingSecret }}{{ .Values.secretRefs.existingSecret }}{{ else }}{{ include "n8n.fullname" . }}{{ end }}
      key: N8N_HOST
- name: N8N_PORT
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.secretRefs.existingSecret }}{{ .Values.secretRefs.existingSecret }}{{ else }}{{ include "n8n.fullname" . }}{{ end }}
      key: N8N_PORT
- name: N8N_PROTOCOL
  valueFrom:
    secretKeyRef:
      name: {{ if .Values.secretRefs.existingSecret }}{{ .Values.secretRefs.existingSecret }}{{ else }}{{ include "n8n.fullname" . }}{{ end }}
      key: N8N_PROTOCOL
{{- end }}