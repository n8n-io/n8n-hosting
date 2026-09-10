{{/*
Pod template shared by the default worker deployment and by every entry in
queueMode.workerGroups, so the two cannot drift.

Takes a dict:
  root  - the chart context ($)
  group - a queueMode.workerGroups entry, or an empty dict for the default
          worker deployment

Everything a group can override (concurrency, resources, extra env, node
placement) falls back to the corresponding top-level worker value when the
group does not set it, so rendering with an empty group reproduces the default
worker exactly.
*/}}
{{- define "n8n.workerPodTemplate" -}}
{{- $ := .root -}}
{{- $group := .group | default dict -}}
{{- $isGroup := ne (len $group) 0 -}}
{{- /* Group pods must fall outside the default worker Deployment's selector.
       That selector is {name, instance, component: worker} and cannot be
       narrowed, because spec.selector is immutable on a Deployment that is
       already installed. Left on `worker`, every group pod would match it, and
       the worker HPA would average CPU over pods it does not scale. */ -}}
{{- $component := ternary "worker-group" "worker" $isGroup -}}
{{- $concurrency := $group.concurrency | default $.Values.queueMode.workerConcurrency -}}
{{- $resources := $group.resources | default $.Values.resources.worker -}}
metadata:
  {{- $podAnns := merge (dict "checksum/config" (include (print $.Template.BasePath "/configmap.yaml") $ | sha256sum) "checksum/secret" (include (print $.Template.BasePath "/secrets.yaml") $ | sha256sum)) ($.Values.podAnnotations | default dict) ($.Values.commonAnnotations | default dict) }}
  annotations:
    {{- toYaml $podAnns | nindent 4 }}
  labels:
    {{- include "n8n.podLabels" (dict "root" $ "component" $component) | nindent 4 }}
    {{- if $isGroup }}
    n8n.io/worker-group: {{ $group.name | quote }}
    {{- with $group.poolName }}
    n8n.io/worker-pool: {{ . | quote }}
    {{- end }}
    {{- end }}
spec:
  {{- with include "n8n.serviceAccountName" $ }}
  serviceAccountName: {{ . }}
  {{- end }}
  {{- if hasKey $.Values.serviceAccount "automountServiceAccountToken" }}
  automountServiceAccountToken: {{ $.Values.serviceAccount.automountServiceAccountToken }}
  {{- end }}

  {{- if $.Values.securityContext.enabled }}
  securityContext:
    fsGroup: {{ $.Values.securityContext.fsGroup }}
    runAsUser: {{ $.Values.securityContext.runAsUser }}
    runAsGroup: {{ $.Values.securityContext.runAsGroup }}
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  {{- end }}

  {{- with $.Values.dnsPolicy }}
  dnsPolicy: {{ . }}
  {{- end }}
  {{- with $.Values.dnsConfig }}
  dnsConfig:
    {{- toYaml . | nindent 4 }}
  {{- end }}

  {{- with $.Values.lifecycle.worker.terminationGracePeriodSeconds }}
  terminationGracePeriodSeconds: {{ . }}
  {{- end }}

  {{- with $.Values.extraInitContainers }}
  initContainers:
    {{- tpl (toYaml .) $ | nindent 4 }}
  {{- end }}

  containers:
    - name: n8n-worker
      image: "{{ $.Values.image.repository }}:{{ $.Values.image.tag }}"
      imagePullPolicy: {{ $.Values.image.pullPolicy }}
      command: ["n8n"]
      args:
        - "worker"
        - "--concurrency={{ $concurrency }}"
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL

      {{- if $.Values.lifecycle.worker.preStop.enabled }}
      lifecycle:
        preStop:
          exec:
            command:
              {{- toYaml $.Values.lifecycle.worker.preStop.command | nindent 14 }}
      {{- end }}

      env:
        # Shared configuration from ConfigMap
        {{- include "n8n.sharedConfigMapEnv" $ | nindent 8 }}

        # Webhook URL for resume/waiting URLs
        {{- include "n8n.workerConfigMapEnv" $ | nindent 8 }}

        # Database password (secret)
        - name: DB_POSTGRESDB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ $.Values.database.passwordSecret.name }}
              key: {{ $.Values.database.passwordSecret.key }}

        # Redis password (secret)
        {{- with $.Values.redis.passwordSecret }}
        {{- if and .name .key }}
        - name: QUEUE_BULL_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .name }}
              key: {{ .key }}
        {{- end }}
        {{- end }}

        # Health check settings (not in ConfigMap as it's optional)
        {{- if $.Values.redis.healthCheck.enabled }}
        - name: QUEUE_HEALTH_CHECK_ACTIVE
          value: "true"
        - name: QUEUE_HEALTH_CHECK_PORT
          value: "{{ $.Values.redis.healthCheck.port }}"
        {{- end }}

        # Redis-specific extra environment variables
        {{- with $.Values.redis.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

        # S3 External Storage
        {{- include "n8n.s3Env" $ | nindent 8 }}

        # Executions Configuration
        {{- include "n8n.executionsEnv" $ | nindent 8 }}

        # License Configuration
        {{- include "n8n.licenseEnv" $ | nindent 8 }}

        # N8N encryption key
        - name: N8N_ENCRYPTION_KEY
          valueFrom:
            secretKeyRef:
              name: {{ if $.Values.secretRefs.existingSecret }}{{ $.Values.secretRefs.existingSecret }}{{ else }}{{ include "n8n.fullname" $ }}{{ end }}
              key: N8N_ENCRYPTION_KEY

        # Task Runners Configuration
        {{- include "n8n.taskRunnerBrokerEnv" $ | nindent 8 }}

        {{- with $.Values.config.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

        {{- with $.Values.queueMode.workerExtraEnv }}
        # Worker-specific extra environment variables
        {{- toYaml . | nindent 8 }}
        {{- end }}

        {{- with $group.extraEnv }}
        # Worker-group-specific extra environment variables
        {{- toYaml . | nindent 8 }}
        {{- end }}

        {{- with $group.poolName }}
        # Pins this group's workers to a named pool, so they consume the
        # jobs-<pool> queue instead of the default jobs queue. Last, so nothing
        # above can shadow the group's own identity.
        - name: N8N_WORKER_POOL_NAME
          value: {{ . | quote }}
        {{- end }}

      {{- with $.Values.config.extraEnvFrom }}
      envFrom:
        {{- toYaml . | nindent 8 }}
      {{- end }}

      # Worker Health Probes
      {{- if $.Values.probes.worker.readiness.enabled }}
      readinessProbe:
        {{- if and $.Values.redis.healthCheck.enabled (eq $.Values.probes.worker.readiness.type "httpGet") }}
        httpGet:
          path: {{ $.Values.probes.worker.readiness.path | default "/healthz" }}
          port: {{ $.Values.redis.healthCheck.port | default 5678 }}
        {{- else }}
        exec:
          command:
            {{- toYaml $.Values.probes.worker.readiness.command | nindent 12 }}
        {{- end }}
        initialDelaySeconds: {{ $.Values.probes.worker.readiness.initialDelaySeconds }}
        periodSeconds: {{ $.Values.probes.worker.readiness.periodSeconds }}
        timeoutSeconds: {{ $.Values.probes.worker.readiness.timeoutSeconds }}
        failureThreshold: {{ $.Values.probes.worker.readiness.failureThreshold }}
      {{- end }}

      {{- if $.Values.probes.worker.liveness.enabled }}
      livenessProbe:
        # Workers don't expose an HTTP endpoint; only exec probes are supported here.
        exec:
          command:
            {{- toYaml $.Values.probes.worker.liveness.command | nindent 12 }}
        initialDelaySeconds: {{ $.Values.probes.worker.liveness.initialDelaySeconds }}
        periodSeconds: {{ $.Values.probes.worker.liveness.periodSeconds }}
        timeoutSeconds: {{ $.Values.probes.worker.liveness.timeoutSeconds }}
        failureThreshold: {{ $.Values.probes.worker.liveness.failureThreshold }}
      {{- end }}

      resources:
        {{- toYaml $resources | nindent 8 }}

      # Volume mounts for external volumes
      volumeMounts:
        {{- with $.Values.extraVolumeMounts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

    {{- if $.Values.taskRunners.enabled }}
    # Task Runner sidecar container
    - name: task-runner
      image: "{{ $.Values.taskRunners.image.repository }}:{{ default $.Values.image.tag $.Values.taskRunners.image.tag }}"
      imagePullPolicy: {{ $.Values.taskRunners.image.pullPolicy }}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL

      env:
        {{- include "n8n.taskRunnerSidecarEnv" $ | nindent 8 }}

      resources:
        {{- toYaml $.Values.taskRunners.resources | nindent 8 }}

      {{- if $.Values.taskRunners.customConfig.enabled }}
      volumeMounts:
        - name: task-runner-config
          mountPath: /etc/n8n-task-runners.json
          subPath: {{ $.Values.taskRunners.customConfig.configMapKey }}
          readOnly: true
      {{- end }}
    {{- end }}

    {{- with $.Values.extraContainers }}
    {{- tpl (toYaml .) $ | nindent 4 }}
    {{- end }}

  # External volumes
  volumes:
    {{- if and $.Values.taskRunners.enabled $.Values.taskRunners.customConfig.enabled }}
    - name: task-runner-config
      configMap:
        name: {{ $.Values.taskRunners.customConfig.configMapName }}
    {{- end }}
    {{- with $.Values.extraVolumes }}
    {{- toYaml . | nindent 4 }}
    {{- end }}

  {{- $nodePlacement := $.Values.nodePlacement | default dict }}
  {{- $componentPlacement := $nodePlacement.worker | default dict }}
  {{- if $group.nodeSelector }}
  nodeSelector: {{- toYaml $group.nodeSelector | nindent 4 }}
  {{- else if $componentPlacement.nodeSelector }}
  nodeSelector: {{- toYaml $componentPlacement.nodeSelector | nindent 4 }}
  {{- else if $.Values.nodeSelector }}
  nodeSelector: {{- toYaml $.Values.nodeSelector | nindent 4 }}
  {{- end }}
  {{- if $group.tolerations }}
  tolerations: {{- toYaml $group.tolerations | nindent 4 }}
  {{- else if $componentPlacement.tolerations }}
  tolerations: {{- toYaml $componentPlacement.tolerations | nindent 4 }}
  {{- else if $.Values.tolerations }}
  tolerations: {{- toYaml $.Values.tolerations | nindent 4 }}
  {{- end }}
  {{- if $group.affinity }}
  affinity: {{- toYaml $group.affinity | nindent 4 }}
  {{- else if $componentPlacement.affinity }}
  affinity: {{- toYaml $componentPlacement.affinity | nindent 4 }}
  {{- else if $.Values.affinity }}
  affinity: {{- toYaml $.Values.affinity | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
Whether a worker group gets a ScaledObject of its own. Returns "true" or "".

Both the Deployment and the ScaledObject have to agree on this: the Deployment
omits `replicas` when KEDA owns the count, so if the two disagreed a group would
end up with neither a replica count nor a scaler, and sit at zero pods forever.
Hence one helper rather than the same condition written twice.

A group with no poolName consumes the default `jobs` queue, which the chart's
own worker ScaledObject already watches. Generating a second scaler on that same
backlog would have both of them scale to cover all of it, roughly doubling the
workers for one queue, so a poolless group is left on its static replicaCount
instead. Supplying explicit `keda.triggers` overrides that, on the grounds that
a caller naming their own triggers has decided what this group scales on.

The release-wide keda.enabled is a hard precondition, not a default a group can
raise. It selects the autoscaler for the whole release (the chart renders HPAs
instead when it is off) and the group ScaledObjects are gated on it at file
level, so a group that could opt *in* would omit `replicas` for a scaler that
never renders. A group's own keda.enabled is therefore an opt-out only;
deployment-worker-group.yaml rejects a group that tries to opt in.
*/}}
{{- define "n8n.workerGroupScaled" -}}
{{- $ := .root -}}
{{- $group := .group -}}
{{- $keda := $group.keda | default dict -}}
{{- if $.Values.keda.enabled -}}
{{- if not (and (hasKey $keda "enabled") (not $keda.enabled)) -}}
{{- if or $group.poolName $keda.triggers -}}true{{- end -}}
{{- end -}}
{{- end -}}
{{- end }}

{{/*
Bull queue a worker group consumes. A group with no poolName stays on the
default queue alongside the chart's own worker deployment.
*/}}
{{- define "n8n.workerGroupQueueName" -}}
{{- $prefix := "jobs" -}}
{{- with .poolName -}}
{{- printf "%s-%s" $prefix . -}}
{{- else -}}
{{- $prefix -}}
{{- end -}}
{{- end }}
