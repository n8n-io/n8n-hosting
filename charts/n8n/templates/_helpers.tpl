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
Merge the map "over" onto the map "base", field by field, and return JSON.
Nested maps merge, any other value replaces the base, and a null removes the
field. A nested map left empty is dropped. The merge is written out rather
than using mergeOverwrite, because some Sprig versions skip false and 0 when
overwriting, and a role must be able to set either.
*/}}
{{- define "n8n.mergeOver" -}}
{{- $base := index . 0 | default dict -}}
{{- $out := deepCopy $base -}}
{{- range $k, $v := index . 1 | default dict -}}
{{- if kindIs "invalid" $v -}}
{{- $_ := unset $out $k -}}
{{- else if kindIs "map" $v -}}
{{- $sub := index $out $k -}}
{{- $merged := include "n8n.mergeOver" (list (ternary $sub dict (kindIs "map" $sub)) $v) | fromJson -}}
{{- if $merged -}}
{{- $_ := set $out $k $merged -}}
{{- else -}}
{{- $_ := unset $out $k -}}
{{- end -}}
{{- else -}}
{{- $_ := set $out $k $v -}}
{{- end -}}
{{- end -}}
{{- toJson $out -}}
{{- end -}}

{{/*
securityContext for a role from a podSecurityContext or
containerSecurityContext map: the shared block with the role block merged
over it. The shared block is merged onto an empty map first, so a null in it
is dropped too.
*/}}
{{- define "n8n.securityContextFor" -}}
{{- $contexts := .contexts | default dict -}}
{{- $shared := include "n8n.mergeOver" (list dict (index $contexts "shared")) | fromJson -}}
{{- with include "n8n.mergeOver" (list $shared (index $contexts .role)) | fromJson -}}
{{- toYaml . -}}
{{- end -}}
{{- end -}}

{{/*
Pod securityContext for a role (main, worker, webhookProcessor).
*/}}
{{- define "n8n.podSecurityContext" -}}
{{- include "n8n.securityContextFor" (dict "contexts" .root.Values.podSecurityContext "role" .role) -}}
{{- end -}}

{{/*
Container securityContext for a role (main, worker, webhookProcessor,
taskRunner). taskRunner is the task-runner sidecar on main and worker pods.
*/}}
{{- define "n8n.containerSecurityContext" -}}
{{- include "n8n.securityContextFor" (dict "contexts" .root.Values.containerSecurityContext "role" .role) -}}
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
n8n image reference. A digest, when set, replaces the tag, so the image is
pinned by content and nothing is resolved by tag at pull time.
*/}}
{{- define "n8n.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (include "n8n.imageTag" .) -}}
{{- end -}}
{{- end -}}

{{/*
Task runner image reference. Takes only taskRunners.image.digest: the runner is
a different image, so the n8n digest can never apply to it.
*/}}
{{- define "n8n.taskRunnerImage" -}}
{{- if .Values.taskRunners.image.digest -}}
{{- printf "%s@%s" .Values.taskRunners.image.repository .Values.taskRunners.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.taskRunners.image.repository (include "n8n.taskRunnerImageTag" .) -}}
{{- end -}}
{{- end -}}

{{/*
Task-runner sidecar container, shared by the main pod (standalone) and worker
pods (queue mode) so both sidecars stay the same.
*/}}
{{- define "n8n.taskRunnerContainer" -}}
- name: task-runner
  image: {{ include "n8n.taskRunnerImage" . | quote }}
  imagePullPolicy: {{ .Values.taskRunners.image.pullPolicy }}
  {{- with include "n8n.containerSecurityContext" (dict "root" . "role" "taskRunner") }}
  securityContext:
    {{- . | nindent 4 }}
  {{- end }}
  {{- include "n8n.containerEnv" (dict "root" . "component" "taskRunner") | trim | nindent 2 }}
  resources:
    {{- toYaml .Values.taskRunners.resources | nindent 4 }}
  {{- $probes := .Values.taskRunners.probes | default dict }}
  {{- $port := include "n8n.taskRunnerHealthCheckPort" . }}
  {{- if $port }}
  {{- /* The launcher answers this itself, so a runner busy with a long task
  does not fail it. The launcher restarts unhealthy runners on its own. */}}
  {{- with $probes.liveness }}
  {{- if .enabled }}
  livenessProbe:
    {{- include "n8n.taskRunnerProbe" (dict "probe" . "port" $port) | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- if .Values.taskRunners.customConfig.enabled }}
  volumeMounts:
    - name: task-runner-config
      mountPath: /etc/n8n-task-runners.json
      subPath: {{ .Values.taskRunners.customConfig.configMapKey }}
      readOnly: true
  {{- end }}
{{- end -}}

{{/*
Port of the launcher's health endpoint in the task-runner sidecar. The launcher
reads N8N_RUNNERS_LAUNCHER_HEALTH_CHECK_PORT, so the probe follows it when
env.taskRunner sets it, and uses the launcher's default otherwise. Empty when
it is a reference, which the chart cannot read, so the probe is left out rather
than pointed at the wrong port.
*/}}
{{- define "n8n.taskRunnerHealthCheckPort" -}}
{{- $port := "5680" -}}
{{- $runnerEnv := include "n8n.envSection" (list (.Values.env | default dict) "taskRunner") | fromJson -}}
{{- if hasKey $runnerEnv "N8N_RUNNERS_LAUNCHER_HEALTH_CHECK_PORT" -}}
{{- $val := get $runnerEnv "N8N_RUNNERS_LAUNCHER_HEALTH_CHECK_PORT" -}}
{{- $port = ternary "" (include "n8n.envValue" $val) (kindIs "map" $val) -}}
{{- end -}}
{{- $port -}}
{{- end -}}

{{/*
A task-runner sidecar probe against the launcher's health endpoint.
*/}}
{{- define "n8n.taskRunnerProbe" -}}
httpGet:
  path: {{ .probe.path }}
  port: {{ .port }}
initialDelaySeconds: {{ .probe.initialDelaySeconds }}
periodSeconds: {{ .probe.periodSeconds }}
timeoutSeconds: {{ .probe.timeoutSeconds }}
failureThreshold: {{ .probe.failureThreshold }}
{{- end -}}

{{/*
Render one extraObjects entry through tpl and return it as YAML. A string
entry is rendered as written; a map entry is serialised first, so both can
reference the release. A literal `{{` has to be written as `{{ "{{" }}`.

Call with (dict "root" $ "object" <entry>).
*/}}
{{- define "n8n.extraObject" -}}
{{- if typeIs "string" .object -}}
{{- tpl .object .root -}}
{{- else -}}
{{- tpl (toYaml .object) .root -}}
{{- end -}}
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
Values keys the chart no longer reads. n8n.validate fails on each one a user
still sets and names its replacement, so an old values file cannot install
with settings that silently do nothing. Add an entry in the same change that
removes or renames the key, and keep the list sorted by path. Write the
replacement as a full sentence in double quotes, because a sentence that
names a value often contains ": ". Paths are dot-separated, so a key that
contains a dot cannot be listed. Each key also gets a note in UPGRADING.md.
The retiredKeysTest entries are fixtures for tests/without-schema/retired-keys_test.yaml.
*/}}
{{- define "n8n.retiredKeys" -}}
- path: retiredKeysTest.first
  replacement: "Set retiredKeysTest.replacement: true instead."
- path: retiredKeysTest.nested.second
  replacement: "Remove it; nothing replaces it."
- path: securityContext
  replacement: "Move fsGroup, runAsUser and runAsGroup to podSecurityContext.shared, and remove enabled. If enabled was false, set podSecurityContext.shared: null instead."
- path: s3.storage.mode
  replacement: "Remove it. s3.enabled sets the binary data mode. To store binary data outside S3, set chartEnvOverrides.shared.N8N_DEFAULT_BINARY_DATA_MODE."
- path: taskRunners.authToken.value
  replacement: "Set secretRefs.env.N8N_RUNNERS_AUTH_TOKEN instead, or with secretRefs.existingSecret, add the token to that Secret under the key N8N_RUNNERS_AUTH_TOKEN."
- path: taskRunners.broker.listenAddress
  replacement: "Remove it. The broker listens on localhost, where the task-runner sidecar reaches it. For a runner outside the pod, set N8N_RUNNERS_BROKER_LISTEN_ADDRESS in env.worker, or in env.main in standalone mode."
{{- end -}}

{{/*
Validate values. Called once from deployment-main.yaml to fail on bad config.
Every check adds its message to $errs instead of failing on the spot, so one
render reports every problem rather than making the user fix and re-run once
per mistake.
*/}}
{{- define "n8n.validate" -}}
{{- $errs := list -}}

{{/* --- Retired keys --- */}}
{{/* First, because later checks may read the keys that replaced them. */}}
{{- $upgradingDoc := "https://github.com/n8n-io/n8n-hosting/blob/main/charts/n8n/UPGRADING.md" -}}
{{- range $retired := include "n8n.retiredKeys" . | fromYamlArray -}}
{{- $node := $.Values -}}
{{- $set := true -}}
{{- range $part := splitList "." $retired.path -}}
{{- if and $set (kindIs "map" $node) (hasKey $node $part) -}}
{{- $node = index $node $part -}}
{{- else -}}
{{- $set = false -}}
{{- end -}}
{{- end -}}
{{- if $set -}}
{{- $errs = append $errs (printf "%s is no longer a chart value. %s See %s" $retired.path $retired.replacement $upgradingDoc) -}}
{{- end -}}
{{- end -}}

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

{{/* --- Worker probes --- */}}
{{/* Same condition as deployment-worker.yaml: no worker pods, nothing to probe. */}}
{{- if and .Values.queueMode.enabled (gt (int .Values.queueMode.workerReplicaCount) 0) -}}
{{- range $name := list "liveness" "readiness" -}}
{{- $probe := index $.Values.probes.worker $name -}}
{{- if and $probe.enabled (eq $probe.type "httpGet") (not $.Values.redis.healthCheck.enabled) -}}
{{- $errs = append $errs (printf "probes.worker.%s.type=httpGet requires redis.healthCheck.enabled=true, which starts the worker health endpoint. Set redis.healthCheck.enabled=true, or remove probes.worker.%s.type to let the chart choose." $name $name) -}}
{{- end -}}
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
{{- if and .Values.multiMain.enabled (not .Values.license.enabled) -}}
{{- $errs = append $errs "multiMain.enabled=true requires license.enabled=true. Multi-main is an n8n Enterprise feature. Set license.activationKey or license.existingSecret.name, or set license.enabled=true alone if the licence reaches n8n another way." -}}
{{- end -}}
{{/* Mains only coordinate in multi-main; without it, every main acts as leader and the instance splits. */}}
{{- if and (gt (int .Values.replicaCount) 1) (not .Values.multiMain.enabled) -}}
{{- $errs = append $errs "replicaCount > 1 requires multiMain.enabled=true. Without multi-main, each extra main runs schedules and triggers on its own. Set multiMain.enabled=true, or set replicaCount to 1." -}}
{{- end -}}
{{- if and .Values.hpa.main.enabled (gt (int .Values.hpa.main.maxReplicas) 1) (not .Values.multiMain.enabled) -}}
{{- $errs = append $errs "hpa.main.enabled=true with hpa.main.maxReplicas > 1 requires multiMain.enabled=true. Without multi-main, each extra main runs schedules and triggers on its own. Set multiMain.enabled=true, or set hpa.main.enabled=false." -}}
{{- end -}}

{{/* --- Database TLS from an existing Secret --- */}}
{{- $ssl := .Values.database.ssl -}}
{{- $sslSecret := $ssl.existingSecret | default dict -}}
{{- $sslSecretKeys := or $sslSecret.caKey $sslSecret.certKey $sslSecret.keyKey -}}
{{- if and $sslSecret.name (not $sslSecretKeys) -}}
{{- $errs = append $errs "database.ssl.existingSecret.name is set but no key is. Set at least one of caKey, certKey or keyKey to a key your Secret holds, for example caKey: ca.crt." -}}
{{- end -}}
{{- if and $sslSecretKeys (not $sslSecret.name) -}}
{{- $errs = append $errs "database.ssl.existingSecret has a key set but no name. Set database.ssl.existingSecret.name to the Secret that holds the keys." -}}
{{- end -}}
{{- if and $sslSecret.certKey (not $sslSecret.keyKey) -}}
{{- $errs = append $errs "database.ssl.existingSecret.certKey is set but keyKey is not. A client certificate is only used with its private key." -}}
{{- end -}}
{{- if and $sslSecret.keyKey (not (or $sslSecret.certKey $ssl.cert)) -}}
{{- $errs = append $errs "database.ssl.existingSecret.keyKey is set but there is no client certificate. Set database.ssl.existingSecret.certKey, or database.ssl.cert." -}}
{{- end -}}
{{- if and (or $sslSecret.name $sslSecretKeys) (not $ssl.enabled) -}}
{{- $errs = append $errs "database.ssl.existingSecret is set but database.ssl.enabled is false. Set database.ssl.enabled: true, or remove database.ssl.existingSecret." -}}
{{- end -}}
{{- if and $ssl.ca $sslSecret.caKey -}}
{{- $errs = append $errs "database.ssl.ca and database.ssl.existingSecret.caKey are mutually exclusive. Use one or the other." -}}
{{- end -}}
{{- if and $ssl.cert $sslSecret.certKey -}}
{{- $errs = append $errs "database.ssl.cert and database.ssl.existingSecret.certKey are mutually exclusive. Use one or the other." -}}
{{- end -}}

{{/* --- Task runners --- */}}
{{- if and .Values.taskRunners.enabled (ne .Values.taskRunners.mode "external") -}}
{{- $errs = append $errs "taskRunners.mode must be 'external'. This chart only supports external task runner sidecars." -}}
{{- end -}}
{{- /* The token lives in the core Secret by default. The chart cannot see into
an existing Secret, so it checks only the token it renders itself. */ -}}
{{- $tokenSecret := .Values.taskRunners.authToken.existingSecret -}}
{{- $inlineToken := .Values.secretRefs.env.N8N_RUNNERS_AUTH_TOKEN | default "" -}}
{{- if and .Values.taskRunners.enabled (not $tokenSecret) (not .Values.secretRefs.existingSecret) (not $inlineToken) -}}
{{- $errs = append $errs "taskRunners.enabled=true requires an auth token. Set secretRefs.env.N8N_RUNNERS_AUTH_TOKEN to a token, which you can generate with: openssl rand -base64 32. Or set taskRunners.authToken.existingSecret to a Secret that holds it." -}}
{{- end -}}
{{- if and $inlineToken .Values.secretRefs.existingSecret -}}
{{- $errs = append $errs (printf "secretRefs.env.N8N_RUNNERS_AUTH_TOKEN has no effect with secretRefs.existingSecret. Add the token to %s under the key N8N_RUNNERS_AUTH_TOKEN, and remove secretRefs.env.N8N_RUNNERS_AUTH_TOKEN." .Values.secretRefs.existingSecret) -}}
{{- else if and $inlineToken $tokenSecret -}}
{{- $errs = append $errs "secretRefs.env.N8N_RUNNERS_AUTH_TOKEN and taskRunners.authToken.existingSecret are mutually exclusive. Use one or the other." -}}
{{- end -}}
{{- if and .Values.taskRunners.enabled ((.Values.taskRunners.probes | default dict).liveness | default dict).enabled -}}
{{- $healthPort := include "n8n.taskRunnerHealthCheckPort" . -}}
{{- if and $healthPort (or (not (regexMatch "^[0-9]+$" $healthPort)) (lt (atoi $healthPort) 1) (gt (atoi $healthPort) 65535)) -}}
{{- $errs = append $errs (printf "env.taskRunner.N8N_RUNNERS_LAUNCHER_HEALTH_CHECK_PORT must be a port number from 1 to 65535, got %q. The sidecar's liveness probe uses it." $healthPort) -}}
{{- end -}}
{{- end -}}
{{- /* A digest on one image only lets a chart upgrade move the other, so the
runner and n8n drift onto different versions. */ -}}
{{- if and .Values.taskRunners.enabled .Values.image.digest (not .Values.taskRunners.image.digest) -}}
{{- $errs = append $errs "image.digest is set but taskRunners.image.digest is not. Pin the runner image by digest too, from the same n8n version, or remove image.digest." -}}
{{- end -}}
{{- if and .Values.taskRunners.enabled .Values.taskRunners.image.digest (not .Values.image.digest) -}}
{{- $errs = append $errs "taskRunners.image.digest is set but image.digest is not. Pin the n8n image by digest too, from the same n8n version, or remove taskRunners.image.digest." -}}
{{- end -}}

{{/* --- Persistence --- */}}
{{- if and .Values.persistence.annotations .Values.persistence.existingClaim -}}
{{- $errs = append $errs (printf "persistence.annotations has no effect with persistence.existingClaim, because the chart does not create that PVC. Annotate %s directly, or remove persistence.annotations." .Values.persistence.existingClaim) -}}
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
{{- if not .Values.license.enabled -}}
{{- $errs = append $errs "s3.enabled=true requires license.enabled=true. n8n stores binary data in S3 only with a Business or Enterprise licence, and exits at boot without one. Set license.activationKey or license.existingSecret.name, or set license.enabled=true alone if the licence reaches n8n another way." -}}
{{- end -}}
{{- end -}}

{{/* --- Binary data mode --- */}}
{{- /* n8n cannot tell that queue-mode pods have separate disks; the chart can. */ -}}
{{- if .Values.queueMode.enabled -}}
{{- $sections := concat (list "shared") (include "n8n.envComponents" . | fromJsonArray) -}}
{{- $fix := ternary "Remove it so the chart's S3 mode applies, or set it to \"database\"." "Remove it, and n8n uses \"database\" in queue mode, or store binary data in S3 with s3.enabled=true." .Values.s3.enabled -}}
{{- range $block := list "env" "chartEnvOverrides" -}}
{{- range $section := $sections -}}
{{- $vars := include "n8n.envSection" (list (index $.Values $block | default dict) $section) | fromJson -}}
{{- $val := get $vars "N8N_DEFAULT_BINARY_DATA_MODE" -}}
{{- /* A reference holds no value the chart can read. */ -}}
{{- if and (not (kindIs "map" $val)) (eq (toString $val | lower) "filesystem") -}}
{{- $errs = append $errs (printf "%s.%s.N8N_DEFAULT_BINARY_DATA_MODE is filesystem, but queueMode.enabled=true. The pods do not share a disk, so one pod cannot read binary data that another pod writes. %s" $block $section $fix) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* --- License --- */}}
{{- if and .Values.license.enabled .Values.license.activationKey .Values.license.existingSecret.name -}}
{{- $errs = append $errs "license.activationKey and license.existingSecret.name are mutually exclusive. Use one or the other." -}}
{{- end -}}
{{- /* An inline key goes in the chart's Secret, which would collide with an
existing Secret of the same name. */ -}}
{{- if and .Values.license.enabled .Values.license.activationKey (eq .Values.secretRefs.existingSecret (include "n8n.fullname" .)) -}}
{{- $errs = append $errs (printf "license.activationKey is stored in the chart's Secret %q, but secretRefs.existingSecret uses that name. Put the key in a Secret of your own and set license.existingSecret instead." (include "n8n.fullname" .)) -}}
{{- end -}}

{{/* --- Encryption key --- */}}
{{- $encryptionKeyFile := .Values.secretRefs.env.N8N_ENCRYPTION_KEY_FILE | default "" -}}
{{- if and $encryptionKeyFile (not (hasPrefix "/" $encryptionKeyFile)) -}}
{{- $errs = append $errs "secretRefs.env.N8N_ENCRYPTION_KEY_FILE must be an absolute path" -}}
{{- end -}}
{{- if and (not $encryptionKeyFile) (not .Values.secretRefs.existingSecret) (eq .Values.secretRefs.env.N8N_ENCRYPTION_KEY "change-me-to-a-long-random-key") -}}
{{- $errs = append $errs "secretRefs.env.N8N_ENCRYPTION_KEY must be changed from the default placeholder value, provide secretRefs.existingSecret with your own Secret, or set secretRefs.env.N8N_ENCRYPTION_KEY_FILE" -}}
{{- end -}}

{{/* --- Settings the chart no longer reads --- */}}
{{- range $k := list "N8N_HOST" "N8N_PROTOCOL" -}}
{{- if hasKey $.Values.secretRefs.env $k -}}
{{- $errs = append $errs (printf "secretRefs.env.%s is no longer read. n8n builds its public URLs from editor.url and webhook.url. Remove it from secretRefs.env, and set it in env.shared if you still need it." $k) -}}
{{- end -}}
{{- end -}}
{{- if hasKey .Values.secretRefs.env "N8N_PORT" -}}
{{- $errs = append $errs "secretRefs.env.N8N_PORT is no longer read. The chart sets N8N_PORT from service.port. Remove it from secretRefs.env." -}}
{{- end -}}
{{- $lists := list
  (dict "path" "config.extraEnv" "value" .Values.config.extraEnv "to" "env.shared")
  (dict "path" "config.extraEnvFrom" "value" .Values.config.extraEnvFrom "to" "envFrom.shared")
  (dict "path" "queueMode.workerExtraEnv" "value" .Values.queueMode.workerExtraEnv "to" "env.worker")
  (dict "path" "webhookProcessor.extraEnv" "value" .Values.webhookProcessor.extraEnv "to" "env.webhookProcessor")
  (dict "path" "webhook.extraEnv" "value" .Values.webhook.extraEnv "to" "env.main and env.webhookProcessor")
  (dict "path" "redis.extraEnv" "value" .Values.redis.extraEnv "to" "env.shared")
  (dict "path" "executions.extraEnv" "value" .Values.executions.extraEnv "to" "env.main and env.worker")
  (dict "path" "s3.storage.extraEnv" "value" .Values.s3.storage.extraEnv "to" "env.shared")
  (dict "path" "taskRunners.extraEnv" "value" .Values.taskRunners.extraEnv "to" "env.taskRunner") -}}
{{- range $lists -}}
{{- if .value -}}
{{- if eq .path "config.extraEnvFrom" -}}
{{- $errs = append $errs (printf "%s is no longer read. Move its entries to %s." .path .to) -}}
{{- else -}}
{{- $errs = append $errs (printf "%s is no longer read. Set these variables in %s as NAME: value, or NAME: {secretKeyRef: {name: ..., key: ...}} for a value from a Secret." .path .to) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if hasKey .Values.webhook "timeout" -}}
{{- $errs = append $errs "webhook.timeout has no effect: n8n has no setting for a webhook timeout. Remove it from your values." -}}
{{- end -}}

{{/* --- Environment --- */}}
{{- range include "n8n.validateEnv" . | fromJsonArray -}}
{{- $errs = append $errs . -}}
{{- end -}}
{{- /* n8n takes a worker's concurrency from N8N_CONCURRENCY_PRODUCTION_LIMIT
when it is set, and ignores the --concurrency flag. */ -}}
{{- if and .Values.queueMode.enabled .Values.queueMode.workerConcurrency -}}
{{- $limit := .Values.executions.concurrency.productionLimit -}}
{{- if and $limit (ne ($limit | int) -1) -}}
{{- $errs = append $errs "queueMode.workerConcurrency and executions.concurrency.productionLimit both set each worker's concurrency, and n8n uses productionLimit. Remove one of them." -}}
{{- end -}}
{{- range include "n8n.userEnv" (dict "root" . "component" "worker") | fromJsonArray -}}
{{- if and (eq .name "N8N_CONCURRENCY_PRODUCTION_LIMIT") (not (hasPrefix "chartEnvOverrides." .source)) -}}
{{- $errs = append $errs (printf "queueMode.workerConcurrency and N8N_CONCURRENCY_PRODUCTION_LIMIT in %s both set each worker's concurrency, and n8n uses the variable. Remove one of them." .source) -}}
{{- end -}}
{{- end -}}
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

{{/* --- Extra objects --- */}}
{{- range $i, $entry := .Values.extraObjects -}}
{{- $rendered := include "n8n.extraObject" (dict "root" $ "object" $entry) -}}
{{- $obj := fromYaml $rendered -}}
{{/* fromYaml keeps only the first document, so a second one would be dropped without a word. */}}
{{- if regexMatch "(?m)^---" (trimPrefix "---" (trim $rendered)) -}}
{{- $errs = append $errs (printf "extraObjects[%d] holds more than one YAML document. Put each object in its own entry." $i) -}}
{{- else if hasKey $obj "Error" -}}
{{- $errs = append $errs (printf "extraObjects[%d] must render to a single Kubernetes object, as a map or a YAML string. %s" $i $obj.Error) -}}
{{- else if not (and $obj.apiVersion $obj.kind (dig "metadata" "name" "" $obj)) -}}
{{- $errs = append $errs (printf "extraObjects[%d] must set apiVersion, kind and metadata.name." $i) -}}
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
The public editor URL, rendered as N8N_EDITOR_BASE_URL and printed by NOTES.txt.
editor.url wins. The ingress fallback uses https://, which assumes TLS ends at
the ingress or in front of it. Empty when no public URL is configured.
*/}}
{{- define "n8n.editorBaseUrl" -}}
{{- if .Values.editor.url -}}
{{ .Values.editor.url }}
{{- else if and .Values.ingress .Values.ingress.enabled (gt (len .Values.ingress.hosts) 0) -}}
https://{{ (index .Values.ingress.hosts 0).host }}
{{- else if and .Values.webhook.url (hasPrefix "http" (.Values.webhook.url | toString)) -}}
{{ .Values.webhook.url }}
{{- end -}}
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

{{/*
Main pod replica count: multiMain.replicas under multi-main, otherwise replicaCount.
*/}}
{{- define "n8n.mainReplicas" -}}
{{- ternary .Values.multiMain.replicas .Values.replicaCount .Values.multiMain.enabled -}}
{{- end -}}

{{/*
Probe type for a worker liveness or readiness probe. An explicit type wins.
Otherwise a command means exec, and the health endpoint means httpGet, so
partial overrides keep rendering the probe they asked for.

Call with (dict "probe" .Values.probes.worker.liveness "root" .)
*/}}
{{- define "n8n.workerProbeType" -}}
{{- if .probe.type -}}
{{- .probe.type -}}
{{- else if .probe.command -}}
exec
{{- else if .root.Values.redis.healthCheck.enabled -}}
httpGet
{{- else -}}
exec
{{- end -}}
{{- end -}}

{{/*
Handler for a worker liveness or readiness probe. With the health endpoint
off and no command, it falls back to a process check. pgrep matches its own
shell, so that check passes whenever the container can run a shell; the
health endpoint is the real check.

Call with (dict "probe" .Values.probes.worker.liveness "root" .)
*/}}
{{- define "n8n.workerProbeHandler" -}}
{{- if eq (include "n8n.workerProbeType" .) "httpGet" -}}
httpGet:
  path: {{ .probe.path }}
  port: {{ .root.Values.redis.healthCheck.port }}
{{- else -}}
exec:
  command:
    {{- toYaml (.probe.command | default (list "/bin/sh" "-c" "pgrep -f 'n8n worker' > /dev/null")) | nindent 4 }}
{{- end -}}
{{- end -}}
