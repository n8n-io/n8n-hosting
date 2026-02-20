{{/*
Environment variables from ConfigMap for all components
*/}}
{{- define "n8n.sharedConfigMapEnv" -}}
# Shared configuration from ConfigMap
- name: TZ
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: TZ
- name: DB_TYPE
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_TYPE
{{- if .Values.database.useExternal }}
- name: DB_POSTGRESDB_DATABASE
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_DATABASE
- name: DB_POSTGRESDB_HOST
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_HOST
- name: DB_POSTGRESDB_PORT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_PORT
- name: DB_POSTGRESDB_USER
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_USER
{{- if .Values.database.schema }}
- name: DB_POSTGRESDB_SCHEMA
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_SCHEMA
{{- end }}
{{- if .Values.database.ssl.enabled }}
- name: DB_POSTGRESDB_SSL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_SSL
{{- if .Values.database.ssl.ca }}
- name: DB_POSTGRESDB_SSL_CA
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_SSL_CA
{{- end }}
{{- if .Values.database.ssl.cert }}
- name: DB_POSTGRESDB_SSL_CERT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_SSL_CERT
{{- end }}
# DB_POSTGRESDB_SSL_KEY is not sourced from the ConfigMap because TLS private keys
# must not be stored unencrypted. Provide it via config.extraEnv from a Secret.
{{- if not .Values.database.ssl.rejectUnauthorized }}
- name: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.queueMode.enabled }}
- name: EXECUTIONS_MODE
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: EXECUTIONS_MODE
- name: OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS
{{- end }}
- name: N8N_RUNNERS_MODE
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_RUNNERS_MODE
- name: N8N_RUNNERS_AUTH_TOKEN
  valueFrom:
    secretKeyRef:
      {{- if .Values.taskRunners.authToken.existingSecret }}
      name: {{ .Values.taskRunners.authToken.existingSecret }}
      key: {{ .Values.taskRunners.authToken.existingSecretKey | default "N8N_RUNNERS_AUTH_TOKEN" }}
      {{- else }}
      name: {{ include "n8n.fullname" . }}-task-runners
      key: N8N_RUNNERS_AUTH_TOKEN
      {{- end }}
{{- if .Values.queueMode.enabled }}
{{- if .Values.redis.clusterNodes }}
- name: QUEUE_BULL_REDIS_CLUSTER_NODES
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_CLUSTER_NODES
{{- else }}
- name: QUEUE_BULL_REDIS_HOST
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_HOST
- name: QUEUE_BULL_REDIS_PORT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_PORT
{{- end }}
{{- if .Values.redis.username }}
- name: QUEUE_BULL_REDIS_USERNAME
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_USERNAME
{{- end }}
{{- if and .Values.redis.database (ne (.Values.redis.database | int) 0) }}
- name: QUEUE_BULL_REDIS_DB
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_DB
{{- end }}
{{- if .Values.redis.timeout }}
- name: QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD
{{- end }}
{{- if .Values.redis.prefix }}
- name: QUEUE_BULL_PREFIX
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_PREFIX
{{- end }}
{{- if .Values.redis.tls }}
- name: QUEUE_BULL_REDIS_TLS
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_TLS
{{- end }}
{{- if .Values.redis.dualstack }}
- name: QUEUE_BULL_REDIS_DUALSTACK
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_BULL_REDIS_DUALSTACK
{{- end }}
{{- if .Values.redis.worker.lockDuration }}
- name: QUEUE_WORKER_LOCK_DURATION
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_WORKER_LOCK_DURATION
{{- end }}
{{- if .Values.redis.worker.lockRenewTime }}
- name: QUEUE_WORKER_LOCK_RENEW_TIME
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_WORKER_LOCK_RENEW_TIME
{{- end }}
{{- if .Values.redis.worker.stalledInterval }}
- name: QUEUE_WORKER_STALLED_INTERVAL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_WORKER_STALLED_INTERVAL
{{- end }}
{{- if .Values.redis.worker.maxStalledCount }}
- name: QUEUE_WORKER_MAX_STALLED_COUNT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: QUEUE_WORKER_MAX_STALLED_COUNT
{{- end }}
- name: N8N_GRACEFUL_SHUTDOWN_TIMEOUT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_GRACEFUL_SHUTDOWN_TIMEOUT
{{- end }}
{{- end }}

{{/*
Environment variables from ConfigMap for main pods only
*/}}
{{- define "n8n.mainConfigMapEnv" -}}
{{- if .Values.webhook.enabled }}
{{- if or .Values.webhook.url (and .Values.ingress .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0)) }}
- name: WEBHOOK_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: WEBHOOK_URL
{{- end }}
{{- if .Values.webhook.timeout }}
- name: N8N_WEBHOOK_TIMEOUT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_WEBHOOK_TIMEOUT
{{- end }}
{{- end }}
{{- if and .Values.multiMain.enabled .Values.license.enabled }}
- name: N8N_MULTI_MAIN_SETUP_ENABLED
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_MULTI_MAIN_SETUP_ENABLED
{{- if .Values.multiMain.setup.keyTtl }}
- name: N8N_MULTI_MAIN_SETUP_KEY_TTL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_MULTI_MAIN_SETUP_KEY_TTL
{{- end }}
{{- if .Values.multiMain.setup.checkInterval }}
- name: N8N_MULTI_MAIN_SETUP_CHECK_INTERVAL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_MULTI_MAIN_SETUP_CHECK_INTERVAL
{{- end }}
{{- end }}
{{- if and .Values.webhookProcessor.enabled .Values.webhookProcessor.disableProductionWebhooksOnMainProcess }}
- name: N8N_DISABLE_PRODUCTION_MAIN_PROCESS
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_DISABLE_PRODUCTION_MAIN_PROCESS
{{- end }}
{{- end }}

{{/*
Environment variables from ConfigMap for webhook processor pods (similar to main but webhook-focused)
*/}}
{{- define "n8n.webhookProcessorConfigMapEnv" -}}
{{- if .Values.webhook.enabled }}
{{- if or .Values.webhook.url (and .Values.ingress .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0)) }}
- name: WEBHOOK_URL
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: WEBHOOK_URL
{{- end }}
{{- if .Values.webhook.timeout }}
- name: N8N_WEBHOOK_TIMEOUT
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_WEBHOOK_TIMEOUT
{{- end }}
{{- end }}
{{- end }}

{{/*
Task Runners environment variables for n8n broker (main and worker pods)
*/}}
{{- define "n8n.taskRunnerBrokerEnv" -}}
{{- if .Values.taskRunners.enabled }}
# Task runner broker configuration
- name: N8N_RUNNERS_BROKER_LISTEN_ADDRESS
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_RUNNERS_BROKER_LISTEN_ADDRESS
- name: N8N_NATIVE_PYTHON_RUNNER
  valueFrom:
    configMapKeyRef:
      name: {{ include "n8n.fullname" . }}
      key: N8N_NATIVE_PYTHON_RUNNER
{{- end }}
{{- end }}

{{/*
Task Runners environment variables for runner sidecar containers
*/}}
{{- define "n8n.taskRunnerSidecarEnv" -}}
{{- if .Values.taskRunners.enabled }}
# Task runner configuration
- name: N8N_RUNNERS_TASK_BROKER_URI
  value: "http://localhost:{{ .Values.taskRunners.broker.port }}"
- name: N8N_RUNNERS_AUTH_TOKEN
  valueFrom:
    secretKeyRef:
      {{- if .Values.taskRunners.authToken.existingSecret }}
      name: {{ .Values.taskRunners.authToken.existingSecret }}
      key: {{ .Values.taskRunners.authToken.existingSecretKey | default "N8N_RUNNERS_AUTH_TOKEN" }}
      {{- else }}
      name: {{ include "n8n.fullname" . }}-task-runners
      key: N8N_RUNNERS_AUTH_TOKEN
      {{- end }}
- name: N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT
  value: "{{ .Values.taskRunners.launcher.autoShutdownTimeout }}"
- name: N8N_RUNNERS_LAUNCHER_LOG_LEVEL
  value: "{{ .Values.taskRunners.launcher.logLevel }}"
{{- with .Values.taskRunners.extraEnv }}
{{- toYaml . | nindent 0 }}
{{- end }}
{{- end }}
{{- end }}