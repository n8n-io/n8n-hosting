{{/*
Environment model.

Every variable the chart computes lands in a ConfigMap that the container
mounts with envFrom: one shared by the n8n processes (main, worker, webhook
processor) and one per component. The explicit env list holds only variables
read from a Secret, because envFrom would load every key in that Secret.

Users add variables with env.<component>, where a value is a literal or a
reference such as {secretKeyRef: ...}, and replace chart-computed ones with
chartEnvOverrides.<component>. Literals go in the ConfigMaps; references go in
the explicit env list. n8n.validateEnv refuses a user map that sets a
variable the chart sets, so a clash never resolves silently.
*/}}

{{/*
Render one env value as a ConfigMap string. Helm reads YAML numbers as
float64, and printing 1000000 that way gives "1e+06", so whole numbers are
printed without an exponent.
*/}}
{{- define "n8n.envValue" -}}
{{- if and (kindIs "float64" .) (eq . (floor .)) -}}
{{- printf "%.0f" . -}}
{{- else -}}
{{- toString . -}}
{{- end -}}
{{- end -}}

{{/*
One component's map from env or chartEnvOverrides, or an empty map when it is
missing or not a map, so the other helpers can range over it safely. The
validation reports a section that is not a map. Call with (list <block> <name>).
*/}}
{{- define "n8n.envSection" -}}
{{- $block := index . 0 -}}
{{- $m := dict -}}
{{- if kindIs "map" $block -}}{{- $m = index $block (index . 1) -}}{{- end -}}
{{- if kindIs "map" $m -}}{{- toJson $m -}}{{- else -}}{}{{- end -}}
{{- end -}}

{{/*
The n8n components this release renders.
*/}}
{{- define "n8n.envComponents" -}}
{{- $c := list "main" -}}
{{- /* The same conditions as the Deployments, so no ConfigMap is rendered for
pods that do not exist. */ -}}
{{- if and .Values.queueMode.enabled (gt (int .Values.queueMode.workerReplicaCount) 0) -}}{{- $c = append $c "worker" -}}{{- end -}}
{{- if and .Values.webhookProcessor.enabled .Values.queueMode.enabled -}}{{- $c = append $c "webhookProcessor" -}}{{- end -}}
{{- toJson $c -}}
{{- end -}}

{{/*
Whether a component's pods carry the task-runner sidecar.
*/}}
{{- define "n8n.hasTaskRunner" -}}
{{- if eq .component "main" -}}
{{- include "n8n.mainTaskRunnersEnabled" .root -}}
{{- else if and (eq .component "worker") .root.Values.taskRunners.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Variables the chart computes for one ConfigMap, as a map of
NAME: {value, from}. "from" names the value that controls the variable, for
error messages. component is shared, main, worker, webhookProcessor or
taskRunner. Call with (dict "root" $ "component" <name>).
*/}}
{{- define "n8n.chartEnv" -}}
{{- $v := .root.Values -}}
{{- $e := dict -}}
{{- if eq .component "shared" -}}
{{- $_ := set $e "TZ" (dict "value" $v.config.timezone "from" "config.timezone") -}}
{{- /* Tells n8n's telemetry which artefact installed it. */ -}}
{{- $_ := set $e "N8N_DEPLOYMENT_ARTIFACT" (dict "value" ($v.config.deploymentArtifact | default (printf "helm-chart/%s" .root.Chart.Version)) "from" "config.deploymentArtifact") -}}
{{- $_ := set $e "N8N_PORT" (dict "value" $v.service.port "from" "service.port") -}}
{{- with $v.secretRefs.env.N8N_ENCRYPTION_KEY_FILE -}}
{{- $_ := set $e "N8N_ENCRYPTION_KEY_FILE" (dict "value" . "from" "secretRefs.env.N8N_ENCRYPTION_KEY_FILE") -}}
{{- end -}}
{{- $_ := set $e "DB_TYPE" (dict "value" $v.database.type "from" "database.type") -}}
{{- if eq $v.database.type "postgresdb" -}}
{{- $_ := set $e "DB_POSTGRESDB_DATABASE" (dict "value" $v.database.database "from" "database.database") -}}
{{- $_ := set $e "DB_POSTGRESDB_HOST" (dict "value" $v.database.host "from" "database.host") -}}
{{- $_ := set $e "DB_POSTGRESDB_PORT" (dict "value" $v.database.port "from" "database.port") -}}
{{- $_ := set $e "DB_POSTGRESDB_USER" (dict "value" $v.database.user "from" "database.user") -}}
{{- with $v.database.schema -}}
{{- $_ := set $e "DB_POSTGRESDB_SCHEMA" (dict "value" . "from" "database.schema") -}}
{{- end -}}
{{- if $v.database.ssl.enabled -}}
{{- /* The client key never goes in a ConfigMap, which is not encrypted at
rest. It comes from database.ssl.existingSecret in n8n.secretEnv instead. */ -}}
{{- $_ := set $e "DB_POSTGRESDB_SSL_ENABLED" (dict "value" "true" "from" "database.ssl.enabled") -}}
{{- with $v.database.ssl.ca -}}
{{- $_ := set $e "DB_POSTGRESDB_SSL_CA" (dict "value" . "from" "database.ssl.ca") -}}
{{- end -}}
{{- with $v.database.ssl.cert -}}
{{- $_ := set $e "DB_POSTGRESDB_SSL_CERT" (dict "value" . "from" "database.ssl.cert") -}}
{{- end -}}
{{- if not $v.database.ssl.rejectUnauthorized -}}
{{- $_ := set $e "DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED" (dict "value" "false" "from" "database.ssl.rejectUnauthorized") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $v.queueMode.enabled -}}
{{- $_ := set $e "EXECUTIONS_MODE" (dict "value" "queue" "from" "queueMode.enabled") -}}
{{- /* Always "true", and "n8n.mainTaskRunnersEnabled" depends on it: n8n skips
task runner startup on main when offloading is on, so the chart drops the
main-pod sidecar. If this ever becomes configurable, that helper must read it
rather than queueMode.enabled. */ -}}
{{- $_ := set $e "OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS" (dict "value" "true" "from" "queueMode.enabled") -}}
{{- if $v.redis.clusterNodes -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_CLUSTER_NODES" (dict "value" $v.redis.clusterNodes "from" "redis.clusterNodes") -}}
{{- else -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_HOST" (dict "value" $v.redis.host "from" "redis.host") -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_PORT" (dict "value" (default 6379 $v.redis.port) "from" "redis.port") -}}
{{- end -}}
{{- with $v.redis.username -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_USERNAME" (dict "value" . "from" "redis.username") -}}
{{- end -}}
{{- if and $v.redis.database (ne ($v.redis.database | int) 0) -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_DB" (dict "value" $v.redis.database "from" "redis.database") -}}
{{- end -}}
{{- with $v.redis.timeout -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD" (dict "value" . "from" "redis.timeout") -}}
{{- end -}}
{{- with $v.redis.prefix -}}
{{- $_ := set $e "QUEUE_BULL_PREFIX" (dict "value" . "from" "redis.prefix") -}}
{{- end -}}
{{- if $v.redis.tls -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_TLS" (dict "value" "true" "from" "redis.tls") -}}
{{- end -}}
{{- if $v.redis.dualstack -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_DUALSTACK" (dict "value" "true" "from" "redis.dualstack") -}}
{{- end -}}
{{- with $v.redis.worker.lockDuration -}}
{{- $_ := set $e "QUEUE_WORKER_LOCK_DURATION" (dict "value" . "from" "redis.worker.lockDuration") -}}
{{- end -}}
{{- with $v.redis.worker.lockRenewTime -}}
{{- $_ := set $e "QUEUE_WORKER_LOCK_RENEW_TIME" (dict "value" . "from" "redis.worker.lockRenewTime") -}}
{{- end -}}
{{- with $v.redis.worker.stalledInterval -}}
{{- $_ := set $e "QUEUE_WORKER_STALLED_INTERVAL" (dict "value" . "from" "redis.worker.stalledInterval") -}}
{{- end -}}
{{- with $v.redis.worker.maxStalledCount -}}
{{- $_ := set $e "QUEUE_WORKER_MAX_STALLED_COUNT" (dict "value" . "from" "redis.worker.maxStalledCount") -}}
{{- end -}}
{{- $_ := set $e "N8N_GRACEFUL_SHUTDOWN_TIMEOUT" (dict "value" $v.redis.worker.timeout "from" "redis.worker.timeout") -}}
{{- end -}}
{{- if $v.webhook.enabled -}}
{{- with include "n8n.webhookUrl" .root -}}
{{- $_ := set $e "N8N_WEBHOOK_URL" (dict "value" . "from" "webhook.url") -}}
{{- end -}}
{{- end -}}
{{- with include "n8n.editorBaseUrl" .root -}}
{{- $_ := set $e "N8N_EDITOR_BASE_URL" (dict "value" . "from" "editor.url") -}}
{{- end -}}
{{- if $v.s3.enabled -}}
{{- /* s3.enabled cannot choose another mode, so only an override can. */ -}}
{{- $_ := set $e "N8N_DEFAULT_BINARY_DATA_MODE" (dict "value" "s3" "from" "s3.enabled" "overrideOnly" true) -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_BUCKET_NAME" (dict "value" $v.s3.bucket.name "from" "s3.bucket.name") -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_BUCKET_REGION" (dict "value" $v.s3.bucket.region "from" "s3.bucket.region") -}}
{{- with $v.s3.bucket.host -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_HOST" (dict "value" . "from" "s3.bucket.host") -}}
{{- end -}}
{{- if $v.s3.auth.autoDetect -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_AUTH_AUTO_DETECT" (dict "value" "true" "from" "s3.auth.autoDetect") -}}
{{- else if $v.s3.auth.accessKeyId -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_ACCESS_KEY" (dict "value" $v.s3.auth.accessKeyId "from" "s3.auth.accessKeyId") -}}
{{- $_ := set $e "AWS_ACCESS_KEY_ID" (dict "value" $v.s3.auth.accessKeyId "from" "s3.auth.accessKeyId") -}}
{{- end -}}
{{- if $v.s3.storage.forcePathStyle -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_FORCE_PATH_STYLE" (dict "value" "true" "from" "s3.storage.forcePathStyle") -}}
{{- end -}}
{{- end -}}

{{- else if eq .component "taskRunner" -}}
{{- $_ := set $e "N8N_RUNNERS_TASK_BROKER_URI" (dict "value" (printf "http://127.0.0.1:%v" $v.taskRunners.broker.port) "from" "taskRunners.broker.port") -}}
{{- $_ := set $e "N8N_RUNNERS_AUTO_SHUTDOWN_TIMEOUT" (dict "value" $v.taskRunners.launcher.autoShutdownTimeout "from" "taskRunners.launcher.autoShutdownTimeout") -}}
{{- $_ := set $e "N8N_RUNNERS_LAUNCHER_LOG_LEVEL" (dict "value" $v.taskRunners.launcher.logLevel "from" "taskRunners.launcher.logLevel") -}}

{{- else -}}
{{- if eq .component "main" -}}
{{- if and $v.multiMain.enabled $v.license.enabled -}}
{{- $_ := set $e "N8N_MULTI_MAIN_SETUP_ENABLED" (dict "value" "true" "from" "multiMain.enabled") -}}
{{- with $v.multiMain.setup.keyTtl -}}
{{- $_ := set $e "N8N_MULTI_MAIN_SETUP_KEY_TTL" (dict "value" . "from" "multiMain.setup.keyTtl") -}}
{{- end -}}
{{- with $v.multiMain.setup.checkInterval -}}
{{- $_ := set $e "N8N_MULTI_MAIN_SETUP_CHECK_INTERVAL" (dict "value" . "from" "multiMain.setup.checkInterval") -}}
{{- end -}}
{{- end -}}
{{- if and $v.webhookProcessor.enabled $v.webhookProcessor.disableProductionWebhooksOnMainProcess -}}
{{- $_ := set $e "N8N_DISABLE_PRODUCTION_MAIN_PROCESS" (dict "value" "true" "from" "webhookProcessor.disableProductionWebhooksOnMainProcess") -}}
{{- end -}}
{{- end -}}
{{- /* The Ingress or route puts one proxy in front of the pods that take client
traffic, so n8n reads the client's address from X-Forwarded-For. Another
proxy in front of that one needs an override, as the chart cannot see it. */ -}}
{{- if has .component (list "main" "webhookProcessor") -}}
{{- $from := "" -}}
{{- if $v.ingress.enabled -}}{{- $from = "ingress.enabled" -}}{{- else if $v.httpRoute.enabled -}}{{- $from = "httpRoute.enabled" -}}{{- end -}}
{{- with $from -}}
{{- $_ := set $e "N8N_PROXY_HOPS" (dict "value" "1" "from" . "overrideOnly" true) -}}
{{- end -}}
{{- end -}}
{{- if include "n8n.hasTaskRunner" (dict "root" .root "component" .component) -}}
{{- $_ := set $e "N8N_RUNNERS_MODE" (dict "value" $v.taskRunners.mode "from" "taskRunners.mode") -}}
{{- $_ := set $e "N8N_NATIVE_PYTHON_RUNNER" (dict "value" $v.taskRunners.nativePythonRunner "from" "taskRunners.nativePythonRunner") -}}
{{- end -}}
{{- if and (eq .component "worker") $v.redis.healthCheck.enabled -}}
{{- $_ := set $e "QUEUE_HEALTH_CHECK_ACTIVE" (dict "value" "true" "from" "redis.healthCheck.enabled") -}}
{{- $_ := set $e "QUEUE_HEALTH_CHECK_PORT" (dict "value" $v.redis.healthCheck.port "from" "redis.healthCheck.port") -}}
{{- end -}}
{{- if has .component (list "main" "worker") -}}
{{- $exec := $v.executions -}}
{{- if and $exec.timeout (ne ($exec.timeout | int) -1) -}}
{{- $_ := set $e "EXECUTIONS_TIMEOUT" (dict "value" $exec.timeout "from" "executions.timeout") -}}
{{- end -}}
{{- with $exec.timeoutMax -}}
{{- $_ := set $e "EXECUTIONS_TIMEOUT_MAX" (dict "value" . "from" "executions.timeoutMax") -}}
{{- end -}}
{{- $_ := set $e "EXECUTIONS_DATA_SAVE_ON_ERROR" (dict "value" $exec.data.saveOnError "from" "executions.data.saveOnError") -}}
{{- $_ := set $e "EXECUTIONS_DATA_SAVE_ON_SUCCESS" (dict "value" $exec.data.saveOnSuccess "from" "executions.data.saveOnSuccess") -}}
{{- $_ := set $e "EXECUTIONS_DATA_SAVE_ON_PROGRESS" (dict "value" $exec.data.saveOnProgress "from" "executions.data.saveOnProgress") -}}
{{- $_ := set $e "EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS" (dict "value" $exec.data.saveManualExecutions "from" "executions.data.saveManualExecutions") -}}
{{- $_ := set $e "EXECUTIONS_DATA_PRUNE" (dict "value" $exec.pruning.enabled "from" "executions.pruning.enabled") -}}
{{- with $exec.pruning.maxAge -}}
{{- $_ := set $e "EXECUTIONS_DATA_MAX_AGE" (dict "value" . "from" "executions.pruning.maxAge") -}}
{{- end -}}
{{- $_ := set $e "EXECUTIONS_DATA_PRUNE_MAX_COUNT" (dict "value" $exec.pruning.maxCount "from" "executions.pruning.maxCount") -}}
{{- with $exec.pruning.hardDeleteBuffer -}}
{{- $_ := set $e "EXECUTIONS_DATA_HARD_DELETE_BUFFER" (dict "value" . "from" "executions.pruning.hardDeleteBuffer") -}}
{{- end -}}
{{- with $exec.pruning.hardDeleteInterval -}}
{{- $_ := set $e "EXECUTIONS_DATA_PRUNE_HARD_DELETE_INTERVAL" (dict "value" . "from" "executions.pruning.hardDeleteInterval") -}}
{{- end -}}
{{- with $exec.pruning.softDeleteInterval -}}
{{- $_ := set $e "EXECUTIONS_DATA_PRUNE_SOFT_DELETE_INTERVAL" (dict "value" . "from" "executions.pruning.softDeleteInterval") -}}
{{- end -}}
{{- if and $exec.concurrency.productionLimit (ne ($exec.concurrency.productionLimit | int) -1) -}}
{{- $_ := set $e "N8N_CONCURRENCY_PRODUCTION_LIMIT" (dict "value" $exec.concurrency.productionLimit "from" "executions.concurrency.productionLimit") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- range $k, $entry := $e -}}
{{- $_ := set $entry "value" (include "n8n.envValue" $entry.value) -}}
{{- end -}}
{{- toJson $e -}}
{{- end -}}

{{/*
Variables the chart reads from a Secret for one container, as a map of
NAME: {valueFrom, from}. They stay in the explicit env list so that only the
named key is read. component is main, worker, webhookProcessor or taskRunner.
*/}}
{{- define "n8n.secretEnv" -}}
{{- $v := .root.Values -}}
{{- $e := dict -}}
{{- $tokenRef := dict "name" ($v.secretRefs.existingSecret | default (include "n8n.fullname" .root)) "key" "N8N_RUNNERS_AUTH_TOKEN" -}}
{{- with $v.taskRunners.authToken.existingSecret -}}
{{- $tokenRef = dict "name" . "key" ($v.taskRunners.authToken.existingSecretKey | default "N8N_RUNNERS_AUTH_TOKEN") -}}
{{- end -}}
{{- $token := dict "valueFrom" (dict "secretKeyRef" $tokenRef) "from" "taskRunners.authToken" -}}
{{- if eq .component "taskRunner" -}}
{{- $_ := set $e "N8N_RUNNERS_AUTH_TOKEN" $token -}}
{{- else -}}
{{- if not $v.secretRefs.env.N8N_ENCRYPTION_KEY_FILE -}}
{{- $_ := set $e "N8N_ENCRYPTION_KEY" (dict "valueFrom" (dict "secretKeyRef" (dict "name" ($v.secretRefs.existingSecret | default (include "n8n.fullname" .root)) "key" "N8N_ENCRYPTION_KEY")) "from" "secretRefs") -}}
{{- end -}}
{{- if eq $v.database.type "postgresdb" -}}
{{- $_ := set $e "DB_POSTGRESDB_PASSWORD" (dict "valueFrom" (dict "secretKeyRef" (dict "name" $v.database.passwordSecret.name "key" $v.database.passwordSecret.key)) "from" "database.passwordSecret") -}}
{{- if $v.database.ssl.enabled -}}
{{- with $v.database.ssl.existingSecret -}}
{{- $refs := dict "DB_POSTGRESDB_SSL_CA" .caKey "DB_POSTGRESDB_SSL_CERT" .certKey "DB_POSTGRESDB_SSL_KEY" .keyKey -}}
{{- $name := .name -}}
{{- range $var, $key := $refs -}}
{{- if $key -}}
{{- $_ := set $e $var (dict "valueFrom" (dict "secretKeyRef" (dict "name" $name "key" $key)) "from" "database.ssl.existingSecret") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $v.queueMode.enabled -}}
{{- with $v.redis.passwordSecret -}}
{{- if and .name .key -}}
{{- $_ := set $e "QUEUE_BULL_REDIS_PASSWORD" (dict "valueFrom" (dict "secretKeyRef" (dict "name" .name "key" .key)) "from" "redis.passwordSecret") -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if and $v.s3.enabled (not $v.s3.auth.autoDetect) $v.s3.auth.secretAccessKeySecret.name -}}
{{- $ref := dict "valueFrom" (dict "secretKeyRef" (dict "name" $v.s3.auth.secretAccessKeySecret.name "key" $v.s3.auth.secretAccessKeySecret.key)) "from" "s3.auth.secretAccessKeySecret" -}}
{{- $_ := set $e "N8N_EXTERNAL_STORAGE_S3_ACCESS_SECRET" $ref -}}
{{- $_ := set $e "AWS_SECRET_ACCESS_KEY" (deepCopy $ref) -}}
{{- end -}}
{{- if and $v.license.enabled $v.license.activationKey -}}
{{- $_ := set $e "N8N_LICENSE_ACTIVATION_KEY" (dict "valueFrom" (dict "secretKeyRef" (dict "name" (include "n8n.fullname" .root) "key" "N8N_LICENSE_ACTIVATION_KEY")) "from" "license.activationKey") -}}
{{- else if and $v.license.enabled $v.license.existingSecret.name -}}
{{- $_ := set $e "N8N_LICENSE_ACTIVATION_KEY" (dict "valueFrom" (dict "secretKeyRef" (dict "name" $v.license.existingSecret.name "key" $v.license.existingSecret.key)) "from" "license.existingSecret") -}}
{{- end -}}
{{- if include "n8n.hasTaskRunner" . -}}
{{- $_ := set $e "N8N_RUNNERS_AUTH_TOKEN" $token -}}
{{- end -}}
{{- end -}}
{{- toJson $e -}}
{{- end -}}

{{/*
Whether an env map value is a reference: a map with exactly one of the
valueFrom sources Kubernetes accepts, holding a map.
*/}}
{{- define "n8n.isEnvRef" -}}
{{- if and (kindIs "map" .) (eq (len .) 1) -}}
{{- $source := keys . | first -}}
{{- if and (has $source (list "secretKeyRef" "configMapKeyRef" "fieldRef" "resourceFieldRef")) (kindIs "map" (get . $source)) -}}true{{- end -}}
{{- end -}}
{{- end -}}

{{/*
The references from the user's env maps that reach one container, as a map of
NAME: valueFrom. The shared map is merged under the component's first, so a
component literal also hides a shared reference of the same name; otherwise
the reference, rendered in env, would beat the component ConfigMap.
*/}}
{{- define "n8n.userRefEnv" -}}
{{- $v := .root.Values -}}
{{- $merged := dict -}}
{{- if ne .component "taskRunner" -}}
{{- $merged = include "n8n.envSection" (list ($v.env | default dict) "shared") | fromJson -}}
{{- end -}}
{{- range $k, $val := (include "n8n.envSection" (list ($v.env | default dict) .component) | fromJson) -}}
{{- $_ := set $merged $k $val -}}
{{- end -}}
{{- $refs := dict -}}
{{- range $k, $val := $merged -}}
{{- if include "n8n.isEnvRef" $val -}}
{{- $_ := set $refs $k $val -}}
{{- end -}}
{{- end -}}
{{- toJson $refs -}}
{{- end -}}

{{/*
Every variable a user sets for one container, as a list of {name, source}:
the env maps and chartEnvOverrides. Variables arriving through envFrom refs
are not visible to the chart.
*/}}
{{- define "n8n.userEnv" -}}
{{- $v := .root.Values -}}
{{- $c := .component -}}
{{- $out := list -}}
{{- $maps := list $c -}}
{{- if ne $c "taskRunner" -}}{{- $maps = prepend $maps "shared" -}}{{- end -}}
{{- range $m := $maps -}}
{{- range $k, $_ := (include "n8n.envSection" (list ($v.env | default dict) $m) | fromJson) -}}
{{- $out = append $out (dict "name" $k "source" (printf "env.%s" $m)) -}}
{{- end -}}
{{- range $k, $_ := (include "n8n.envSection" (list ($v.chartEnvOverrides | default dict) $m) | fromJson) -}}
{{- $out = append $out (dict "name" $k "source" (printf "chartEnvOverrides.%s" $m)) -}}
{{- end -}}
{{- end -}}
{{- toJson $out -}}
{{- end -}}

{{/*
The data of one env ConfigMap: the chart's variables, then the user's map,
then the overrides that apply. A shared override of a variable the chart sets
in a component ConfigMap is written there, so it is not hidden by the
component ConfigMap that envFrom loads later.
*/}}
{{- define "n8n.envConfigMapData" -}}
{{- $v := .root.Values -}}
{{- $c := .component -}}
{{- $data := dict -}}
{{- $chart := include "n8n.chartEnv" . | fromJson -}}
{{- range $k, $entry := $chart -}}
{{- $_ := set $data $k $entry.value -}}
{{- end -}}
{{- range $k, $val := (include "n8n.envSection" (list ($v.env | default dict) $c) | fromJson) -}}
{{- if not (include "n8n.isEnvRef" $val) -}}
{{- $_ := set $data $k (include "n8n.envValue" $val) -}}
{{- end -}}
{{- end -}}
{{- $overrides := $v.chartEnvOverrides | default dict -}}
{{- if eq $c "shared" -}}
{{- /* Only shared variables: an override of a component variable belongs in
that component's ConfigMap, so it reaches no other component. */ -}}
{{- range $k, $val := (include "n8n.envSection" (list $overrides "shared") | fromJson) -}}
{{- if hasKey $chart $k -}}
{{- $_ := set $data $k (include "n8n.envValue" $val) -}}
{{- end -}}
{{- end -}}
{{- else if ne $c "taskRunner" -}}
{{- range $k, $val := (include "n8n.envSection" (list $overrides "shared") | fromJson) -}}
{{- if hasKey $chart $k -}}
{{- $_ := set $data $k (include "n8n.envValue" $val) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if ne $c "shared" -}}
{{- range $k, $val := (include "n8n.envSection" (list $overrides $c) | fromJson) -}}
{{- $_ := set $data $k (include "n8n.envValue" $val) -}}
{{- end -}}
{{- end -}}
{{- toYaml $data -}}
{{- end -}}

{{/*
The name of one env ConfigMap: the release's full name for shared, with the
component appended otherwise.
*/}}
{{- define "n8n.envConfigMapName" -}}
{{- include "n8n.fullname" .root -}}
{{- with index (dict "main" "-main" "worker" "-worker" "webhookProcessor" "-webhook-processor" "taskRunner" "-task-runner") .component -}}{{ . }}{{- end -}}
{{- end -}}

{{/*
One env ConfigMap. component is shared, main, worker, webhookProcessor or
taskRunner.
*/}}
{{- define "n8n.envConfigMap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "n8n.envConfigMapName" . }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    {{- include "n8n.labels" .root | nindent 4 }}
    {{- if ne .component "shared" }}
    app.kubernetes.io/component: {{ trimPrefix "-" (trimPrefix (include "n8n.fullname" .root) (include "n8n.envConfigMapName" .)) }}
    {{- end }}
  {{- with .root.Values.commonAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- $data := include "n8n.envConfigMapData" . }}
{{- if ne $data "{}" }}
data:
  {{- $data | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
checksum/config for one component's pods: only the ConfigMaps they load, so a
change to one component's env rolls only that component.
*/}}
{{- define "n8n.envChecksum" -}}
{{- $parts := list (include "n8n.envConfigMap" (dict "root" .root "component" "shared")) (include "n8n.envConfigMap" .) -}}
{{- if include "n8n.hasTaskRunner" . -}}
{{- $parts = append $parts (include "n8n.envConfigMap" (dict "root" .root "component" "taskRunner")) -}}
{{- end -}}
{{- join "\n---\n" $parts | sha256sum -}}
{{- end -}}

{{/*
env and envFrom for one container. component is main, worker,
webhookProcessor or taskRunner.
*/}}
{{- define "n8n.containerEnv" -}}
{{- $v := .root.Values -}}
{{- $c := .component -}}
{{- $secrets := include "n8n.secretEnv" . | fromJson -}}
{{- $refs := include "n8n.userRefEnv" . | fromJson -}}
{{- if or $secrets $refs }}
env:
  {{- range $k, $entry := $secrets }}
  - name: {{ $k }}
    valueFrom:
      {{- toYaml $entry.valueFrom | nindent 6 }}
  {{- end }}
  {{- range $k, $ref := $refs }}
  - name: {{ $k }}
    valueFrom:
      {{- toYaml $ref | nindent 6 }}
  {{- end }}
{{- end }}
envFrom:
  {{- if ne $c "taskRunner" }}
  - configMapRef:
      name: {{ include "n8n.envConfigMapName" (dict "root" .root "component" "shared") }}
  {{- end }}
  - configMapRef:
      name: {{ include "n8n.envConfigMapName" . }}
  {{- $userFrom := $v.envFrom | default dict }}
  {{- if not (kindIs "map" $userFrom) }}{{- $userFrom = dict }}{{- end }}
  {{- if ne $c "taskRunner" }}
  {{- with index $userFrom "shared" }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- end }}
  {{- with index $userFrom $c }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end -}}

{{/*
Validation for the env model. Returns a JSON list of error messages for
n8n.validate to report.
*/}}
{{- define "n8n.validateEnv" -}}
{{- $root := . -}}
{{- $v := .Values -}}
{{- $errs := list -}}
{{- range $block := list "env" "chartEnvOverrides" "envFrom" -}}
{{- if not (kindIs "map" (index $v $block | default dict)) -}}
{{- $errs = append $errs (printf "%s must be a map with the keys shared, main, worker, webhookProcessor and taskRunner." $block) -}}
{{- end -}}
{{- end -}}
{{- $env := $v.env | default dict -}}
{{- if not (kindIs "map" $env) -}}{{- $env = dict -}}{{- end -}}
{{- $overrides := $v.chartEnvOverrides | default dict -}}
{{- if not (kindIs "map" $overrides) -}}{{- $overrides = dict -}}{{- end -}}
{{- $sections := list "shared" "main" "worker" "webhookProcessor" "taskRunner" -}}

{{- /* Keys and values. The schema checks these too; this covers renders without it. */ -}}
{{- range $block, $maps := dict "env" $env "chartEnvOverrides" $overrides -}}
{{- range $section, $m := $maps -}}
{{- if not (has $section $sections) -}}
{{- $errs = append $errs (printf "%s.%s is not a component. Use one of: %s." $block $section (join ", " $sections)) -}}
{{- else if not (kindIs "map" ($m | default dict)) -}}
{{- $errs = append $errs (printf "%s.%s must be a map of NAME: value." $block $section) -}}
{{- else -}}
{{- range $k, $val := $m -}}
{{- if not (regexMatch "^[A-Za-z_][A-Za-z0-9_]*$" $k) -}}
{{- $errs = append $errs (printf "%s.%s.%s is not a valid environment variable name. Use letters, digits and underscores, starting with a letter or underscore." $block $section $k) -}}
{{- end -}}
{{- $scalar := or (kindIs "string" $val) (kindIs "bool" $val) (kindIs "float64" $val) (kindIs "int" $val) (kindIs "int64" $val) -}}
{{- if eq $block "chartEnvOverrides" -}}
{{- if not $scalar -}}
{{- $errs = append $errs (printf "%s.%s.%s must be a string, number or boolean." $block $section $k) -}}
{{- end -}}
{{- else if not (or $scalar (include "n8n.isEnvRef" $val)) -}}
{{- $errs = append $errs (printf "%s.%s.%s must be a string, number or boolean, or a reference with exactly one of secretKeyRef, configMapKeyRef, fieldRef or resourceFieldRef." $block $section $k) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* What the chart sets on each container this release renders. */ -}}
{{- $sharedChart := include "n8n.chartEnv" (dict "root" $root "component" "shared") | fromJson -}}
{{- $containers := include "n8n.envComponents" $root | fromJsonArray -}}
{{- if $v.taskRunners.enabled -}}{{- $containers = append $containers "taskRunner" -}}{{- end -}}
{{- $reported := dict -}}
{{- range $c := $containers -}}
{{- $ctx := dict "root" $root "component" $c -}}
{{- $chart := include "n8n.chartEnv" $ctx | fromJson -}}
{{- if ne $c "taskRunner" -}}{{- $chart = merge (deepCopy $chart) $sharedChart -}}{{- end -}}
{{- $secrets := include "n8n.secretEnv" $ctx | fromJson -}}
{{- $maps := list $c -}}
{{- if ne $c "taskRunner" -}}{{- $maps = prepend $maps "shared" -}}{{- end -}}

{{- /* A map may not set what the chart sets. */ -}}
{{- range $m := $maps -}}
{{- range $k, $_ := (include "n8n.envSection" (list $env $m) | fromJson) -}}
{{- $id := printf "env.%s.%s" $m $k -}}
{{- if hasKey $reported $id -}}
{{- else if hasKey $secrets $k -}}
{{- $_ := set $reported $id true -}}
{{- $errs = append $errs (printf "%s is read by the chart from %s. Set %s instead." $id (get $secrets $k).from (get $secrets $k).from) -}}
{{- else if hasKey $chart $k -}}
{{- $_ := set $reported $id true -}}
{{- $from := (get $chart $k).from -}}
{{- if (get $chart $k).overrideOnly -}}
{{- $errs = append $errs (printf "%s is set by the chart from %s. Put it in chartEnvOverrides.%s to override the chart deliberately." $id $from $m) -}}
{{- else -}}
{{- $errs = append $errs (printf "%s is set by the chart from %s. Set %s instead, or put it in chartEnvOverrides.%s to override the chart deliberately." $id $from $from $m) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* An override may only replace a variable the chart computes here. */ -}}
{{- range $k, $_ := (include "n8n.envSection" (list $overrides $c) | fromJson) -}}
{{- $id := printf "chartEnvOverrides.%s.%s" $c $k -}}
{{- if hasKey $secrets $k -}}
{{- $errs = append $errs (printf "%s cannot be overridden, because the chart reads it from a Secret. Set %s instead." $id (get $secrets $k).from) -}}
{{- else if not (hasKey $chart $k) -}}
{{- $errs = append $errs (printf "%s overrides nothing: the chart does not set %s here. Put it in env.%s instead." $id $k $c) -}}
{{- end -}}
{{- end -}}

{{- end -}}

{{- /* Overrides for a component this release does not render replace nothing. */ -}}
{{- range $section, $m := $overrides -}}
{{- if and (has $section $sections) (ne $section "shared") (not (has $section $containers)) (kindIs "map" $m) -}}
{{- range $k, $_ := $m -}}
{{- $errs = append $errs (printf "chartEnvOverrides.%s.%s overrides nothing: this release renders no %s pods." $section $k $section) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /* chartEnvOverrides.shared must replace something on at least one container. */ -}}
{{- range $k, $_ := (include "n8n.envSection" (list $overrides "shared") | fromJson) -}}
{{- $id := printf "chartEnvOverrides.shared.%s" $k -}}
{{- $found := hasKey $sharedChart $k -}}
{{- $secretFrom := "" -}}
{{- range $c := include "n8n.envComponents" $root | fromJsonArray -}}
{{- $ctx := dict "root" $root "component" $c -}}
{{- if hasKey (include "n8n.chartEnv" $ctx | fromJson) $k -}}{{- $found = true -}}{{- end -}}
{{- with get (include "n8n.secretEnv" $ctx | fromJson) $k -}}{{- $secretFrom = .from -}}{{- end -}}
{{- end -}}
{{- if $secretFrom -}}
{{- $errs = append $errs (printf "%s cannot be overridden, because the chart reads it from a Secret. Set %s instead." $id $secretFrom) -}}
{{- else if not $found -}}
{{- $errs = append $errs (printf "%s overrides nothing: the chart does not set %s. Put it in env.shared instead." $id $k) -}}
{{- end -}}
{{- end -}}

{{- toJson $errs -}}
{{- end -}}
