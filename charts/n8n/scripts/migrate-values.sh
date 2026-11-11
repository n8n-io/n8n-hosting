#!/usr/bin/env bash
# Migrate a values file written for chart 1.x of the n8n chart to chart 2.0.
#
# Usage: migrate-values.sh values-1x.yaml > values-2x.yaml
#
# Run with -h for the details. The transforms follow UPGRADING.md and
# n8n.retiredKeys in templates/_helpers.tpl; a key added to one belongs here too.

# A $ inside single quotes belongs to a yq expression, not to the shell.
# shellcheck disable=SC2016

set -euo pipefail

# The yq version CI runs this script with. Newer v4 releases are expected to
# work, so an older one only gets a warning.
YQ_TESTED_VERSION="4.53.6"
YQ="${YQ:-yq}"

usage() {
  cat <<'EOF'
Usage: migrate-values.sh VALUES_FILE > NEW_VALUES_FILE

Migrates a values file for chart 1.x of the n8n chart to chart 2.0. The new
values go to stdout. A report of every change, and of everything you need to
check yourself, goes to stderr.

The script:
  - moves or removes every values key that chart 2.0 retired,
  - turns the extraEnv lists into the env maps,
  - renames or removes the environment variables that n8n 3.0 no longer reads.

Where it cannot decide for you, it keeps the 1.x behaviour and says so in the
report. Keys it does not know pass through unchanged. Running it over a 2.0
values file changes nothing.

Limits:
  - It reads plain YAML only. It does not read helmfile .gotmpl files or
    values that Argo CD or another tool generates from templates.
  - It never reads the contents of a Secret, including the Secrets named in
    your values.
  - It reads one values file. A setting it cannot see, such as a default from
    another values file, is not migrated.

Review the output before you upgrade. Render it with helm template. Read the
"Upgrading to 2.0" section of UPGRADING.md too.

Needs yq v4 (https://github.com/mikefarah/yq), tested with v4.53.6. Set YQ to
use a yq binary that is not on your PATH.
EOF
}

die() {
  echo "migrate-values: $*" >&2
  exit 1
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac
[[ $# -eq 1 ]] || { usage >&2; exit 2; }
input="$1"
[[ -f "$input" ]] || die "$input is not a file."

# --- yq ---
command -v "$YQ" > /dev/null 2>&1 || die "yq not found. Install yq v4 from https://github.com/mikefarah/yq, or set YQ to its path."
yq_version_line="$("$YQ" --version 2>&1 || true)"
[[ "$yq_version_line" == *mikefarah* ]] || die "$YQ is not mikefarah's yq. Install yq v4 from https://github.com/mikefarah/yq."
yq_version="$(sed -n 's/.*version v\{0,1\}\([0-9][0-9.]*\).*/\1/p' <<< "$yq_version_line")"
[[ "$yq_version" == 4.* ]] || die "yq ${yq_version:-of unknown version} found, but this script needs yq v4."
if [[ "$(printf '%s\n%s\n' "$YQ_TESTED_VERSION" "$yq_version" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" != "$YQ_TESTED_VERSION" ]]; then
  echo "migrate-values: warning: yq $yq_version is older than v$YQ_TESTED_VERSION, the version this script is tested with." >&2
fi

work="$(mktemp)"
trap 'rm -f "$work"' EXIT
# yq drops blank lines, so they travel through it as a comment.
blank="#__migrate_values_blank_line__"
sed "s/^[[:space:]]*\$/$blank/" "$input" > "$work"
"$YQ" -e 'tag == "!!map" or tag == "!!null"' "$work" > /dev/null 2>&1 || die "$input is not a YAML map of values."

# --- Helpers ---
changes=""
checks=""
changed() { changes+="  - $*"$'\n'; }
check() { checks+="  - $*"$'\n'; }

# Read from or update the working copy. Pass values through exported
# variables and strenv(), never by splicing them into the expression.
q() { "$YQ" "$@" "$work"; }
u() { "$YQ" -i "$1" "$work"; }

# True when the dotted path is present, whatever its value, as n8n.retiredKeys
# treats it.
present() {
  local path="$1" parent="" leaf="$1"
  if [[ "$path" == *.* ]]; then parent="${path%.*}"; leaf="${path##*.}"; fi
  [[ "$(q "((.${parent} | select(tag == \"!!map\")) // {}) | has(\"$leaf\")")" == "true" ]]
}

# The value at a path, empty when it is absent or null.
val() { q ".$1 // \"\" | select((tag != \"!!map\") and (tag != \"!!seq\"))"; }

# Truthy as Helm reads it: absent, null, false, 0 and "" are false.
truthy() {
  local v
  v="$(val "$1")"
  [[ -n "$v" && "$v" != "false" && "$v" != "0" ]]
}

# True when the path is absent, null, or an empty string, list or map.
empty_at() {
  [[ "$(q "(.$1 // \"\") | length")" == "0" ]]
}

# Remove a path, and any map it leaves empty above it.
remove() {
  u "del(.$1)"
  prune_up "$1"
  changed "Removed $1.${2:+ $2}"
}

prune_up() {
  local path="$1"
  while [[ "$path" == *.* ]]; do
    path="${path%.*}"
    [[ "$(q "(.$path | tag == \"!!map\") and (.$path | length == 0)")" == "true" ]] || break
    u "del(.$path)"
  done
}

queue_mode() {
  [[ "$(q '.queueMode.enabled')" != "false" ]]
}

# The chart this script ships in. Its values.yaml holds the 2.0 defaults.
chart="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$chart/values.yaml" && -f "$chart/templates/_helpers.tpl" ]] || die "Run the copy of this script that ships in the chart, next to its values.yaml and templates/."

# A file that sets a retired key was written for 1.x. A file that sets none
# could be either, so a transform that would change a valid 2.0 file runs
# only on a 1.x one.
written_for_1x=false
while read -r path; do
  [[ "$path" == retiredKeysTest.* ]] && continue
  if present "$path"; then written_for_1x=true; break; fi
done < <(sed -n '/define "n8n.retiredKeys"/,/end -/s/^- path: //p' "$chart/templates/_helpers.tpl")

# --- extraEnv lists to env maps ---

# Print each entry of a 1.x list in FILE as INDEX<tab>NAME<tab>JSON value.
list_entries() {
  "$YQ" "(.$2 | select(tag == \"!!seq\") // []) | to_entries[] | select(.value | has(\"name\")) | (.key | tostring) + \"	\" + .value.name + \"	\" + (((.value.valueFrom | select(. != null)) // (.value.value | select(. != null)) // \"\") | to_json(0))" "$1"
}

# Set env.<map>.N to a JSON value.
set_env() {
  export N="$2" V="$3"
  u ".env.${1}[strenv(N)] = (strenv(V) | from_json | ... style=\"\")"
}

# 1.x rendered redis.extraEnv only in queue mode, and s3.storage.extraEnv only
# with s3.enabled.
applied_in_1x() {
  case "$1" in
    redis.extraEnv) queue_mode ;;
    s3.storage.extraEnv) truthy s3.enabled ;;
    *) true ;;
  esac
}

converted=false
convert_env_list() {
  local src="$1" targets="$2" t names="" name value
  present "$src" || return 0
  if ! applied_in_1x "$src"; then
    if [[ "$(q "(.$src // []) | length")" != "0" ]]; then
      check "$src was dropped. 1.x did not apply it with your values, so moving it to env.$targets would start setting its variables."
    fi
    remove "$src" "1.x did not apply it with your values."
    return 0
  fi
  case "$(q ".$src | tag")" in
    "!!seq") ;;
    "!!null") remove "$src" "It was empty."; return 0 ;;
    *) check "$src is not a list, so it was not converted. Move its variables to env.${targets// / and env.} yourself."; return 0 ;;
  esac
  if [[ "$(q "[.${src}[] | select(has(\"name\") | not)] | length")" != "0" ]]; then
    check "$src has entries without a name, which Kubernetes rejected. They were dropped."
  fi
  while IFS=$'\t' read -r i name value; do
    [[ -n "$name" ]] || continue
    export N="$name"
    for t in $targets; do
      # A later 1.x list overwrites an earlier one, as it did in the
      # container. A map the values already set keeps its value.
      if [[ "$(q "(.env.$t // {}) | has(strenv(N))")" == "true" ]] &&
        ! grep -qxF "$t.$name" <<< "$written"; then
        if [[ "$(q -o=json -I=0 ".env.${t}[strenv(N)]")" != "$value" ]]; then
          check "$name in $src differs from env.$t.$name, which your values already set. The script kept env.$t.$name."
        fi
        continue
      fi
      # Copy the node rather than its JSON, so its quoting and comments stay.
      u ".env.${t}[strenv(N)] = (.${src}[$i] | ((.valueFrom | select(. != null)) // (.value | select(. != null)) // \"\"))"
      written+="$t.$name"$'\n'
    done
    names+="${names:+, }$name"
  done < <(list_entries "$work" "$src")
  u "del(.$src)"
  prune_up "$src"
  converted=true
  if [[ -n "$names" ]]; then
    changed "Moved $src to env.${targets// / and env.}: $names."
  else
    changed "Removed $src. It was empty."
  fi
}

# Each list goes to its map, in an order where the later list won in 1.x on
# every container that loads the map.
written=""
convert_env_list redis.extraEnv shared
convert_env_list s3.storage.extraEnv shared
convert_env_list config.extraEnv shared
convert_env_list webhook.extraEnv "main webhookProcessor"
convert_env_list executions.extraEnv "main worker"
convert_env_list queueMode.workerExtraEnv worker
convert_env_list webhookProcessor.extraEnv webhookProcessor
convert_env_list taskRunners.extraEnv taskRunner

# In 2.0 a component map wins over env.shared. In 1.x config.extraEnv came
# after webhook.extraEnv and executions.extraEnv and won over them. Replay
# each container's 1.x list order, and pin the 1.x winner in the component map
# where the 2.0 maps would pick another value.
if [[ "$converted" == true ]]; then
  for t in main worker webhookProcessor; do
    case "$t" in
      main) order="webhook.extraEnv redis.extraEnv s3.storage.extraEnv executions.extraEnv config.extraEnv" ;;
      worker) order="redis.extraEnv s3.storage.extraEnv executions.extraEnv config.extraEnv queueMode.workerExtraEnv" ;;
      webhookProcessor) order="redis.extraEnv webhook.extraEnv s3.storage.extraEnv config.extraEnv webhookProcessor.extraEnv" ;;
    esac
    effective="$(for src in $order; do applied_in_1x "$src" && list_entries "$input" "$src"; done |
      awk -F '\t' '{ v[$2] = $0 } END { for (k in v) print v[k] }' | sort -t "$(printf '\t')" -k2,2)"
    pinned=""
    while IFS=$'\t' read -r _ name value; do
      [[ -n "$name" ]] || continue
      export N="$name"
      now="$(q -o=json -I=0 "(.env.$t // {}) as \$c | (.env.shared // {}) as \$s | ((\$c | select(has(strenv(N)))) // \$s)[strenv(N)]")"
      [[ "$now" != "$value" ]] || continue
      # A value the env map already held before the script ran stays.
      if [[ "$(q "(.env.$t // {}) | has(strenv(N))")" == "true" ]] && ! grep -qxF "$t.$name" <<< "$written"; then
        continue
      fi
      if [[ "$(q -o=json -I=0 ".env.shared[strenv(N)]")" == "$value" ]]; then
        u ".env.$t |= del(.[strenv(N)])"
        prune_up "env.$t.$name"
      else
        set_env "$t" "$name" "$value"
      fi
      pinned+="${pinned:+, }$name"
    done <<< "$effective"
    [[ -z "$pinned" ]] || changed "Kept the 1.x value of $pinned on $t pods. In 2.0 env.$t wins over env.shared, which 1.x did not always do."
  done
fi

if present config.extraEnvFrom; then
  if [[ "$(q '.config.extraEnvFrom | tag')" == "!!seq" && "$(q '.config.extraEnvFrom | length')" != "0" ]]; then
    u '.envFrom.shared = (.envFrom.shared // []) + .config.extraEnvFrom | del(.config.extraEnvFrom)'
    prune_up config.extraEnvFrom
    changed "Moved config.extraEnvFrom to envFrom.shared."
    check "envFrom.shared now loads after the chart's ConfigMaps, so a key in it replaces the chart's value. Check that it holds only the keys you mean to set. The script cannot see into it."
  else
    remove config.extraEnvFrom "It was empty."
  fi
fi

# --- Environment variables n8n 3.0 renamed or removed ---
env_maps=""
for block in env chartEnvOverrides; do
  for t in shared main worker webhookProcessor taskRunner; do
    if [[ "$(q ".$block.$t | tag")" == "!!map" ]]; then env_maps+="$block.$t "; fi
  done
done

for m in $env_maps; do
  if [[ "$(q ".$m | has(\"N8N_DB_PING_TIMEOUT\")")" == "true" ]]; then
    if [[ "$(q ".$m | has(\"DB_PING_TIMEOUT_MS\")")" == "true" ]]; then
      u "del(.$m.N8N_DB_PING_TIMEOUT)"
      prune_up "$m.N8N_DB_PING_TIMEOUT"
      changed "Removed $m.N8N_DB_PING_TIMEOUT. n8n 3.0 reads DB_PING_TIMEOUT_MS, which $m already sets."
    else
      u ".$m.DB_PING_TIMEOUT_MS = .$m.N8N_DB_PING_TIMEOUT | del(.$m.N8N_DB_PING_TIMEOUT)"
      changed "Renamed $m.N8N_DB_PING_TIMEOUT to DB_PING_TIMEOUT_MS, which n8n 3.0 reads. Both are in milliseconds."
    fi
  fi
  for var in N8N_WORKFLOW_TAGS_DISABLED N8N_PRE_EXECUTE_ERROR_CREATES_EXECUTION N8N_RUNNERS_ENABLED \
    N8N_MIGRATE_FS_STORAGE_PATH N8N_AGENTS_SKILLS_HUB_ENABLED N8N_ENV_FEAT_CRED_SHARING \
    N8N_INSTANCE_AI_LOCAL_GATEWAY_DISABLED N8N_INSTANCE_AI_GATEWAY_API_KEY; do
    if [[ "$(q ".$m | has(\"$var\")")" == "true" ]]; then
      remove "$m.$var" "n8n 3.0 no longer reads it."
    fi
  done
  if [[ "$(q ".$m.N8N_DEFAULT_BINARY_DATA_MODE")" == "default" ]]; then
    remove "$m.N8N_DEFAULT_BINARY_DATA_MODE" "n8n 3.0 has no in-memory mode, and uses filesystem, or database in queue mode."
  fi
done

# --- Variables the 2.0 chart sets ---
# The render fails when an env map sets a variable the chart sets. These are
# the ones UPGRADING.md moves for you.
routed=false
if { truthy ingress.enabled && [[ "$(q '.ingress.hosts // [] | length')" != "0" ]]; } ||
  { truthy httpRoute.enabled && [[ "$(q '.httpRoute.hostnames // [] | length')" != "0" ]]; }; then
  routed=true
fi

# The chart sets both URL variables on every n8n container whenever it has an
# address: editor.url, webhook.url or a routed host.
move_url_var() {
  local var="$1" key="$2" t
  for t in shared main worker webhookProcessor; do
    [[ "$(q ".env.$t.$var | tag")" == "!!str" ]] || continue
    if truthy "$key"; then
      # In 1.x the list entry came after the chart's value, and won.
      if [[ "$(val "env.$t.$var")" == "$(val "$key")" ]]; then
        remove "env.$t.$var" "It repeats $key."
      else
        u ".chartEnvOverrides.$t.$var = .env.$t.$var | del(.env.$t.$var)"
        prune_up "env.$t.$var"
        changed "Moved env.$t.$var to chartEnvOverrides.$t, which keeps your value over the one the chart sets from $key."
        check "env.$t.$var differs from $key. The script kept your value on $t pods. Remove chartEnvOverrides.$t.$var if $key is the address you want."
      fi
    else
      u ".$key = .env.$t.$var | del(.env.$t.$var)"
      prune_up "env.$t.$var"
      changed "Moved env.$t.$var to $key, which the chart sets the variable from."
    fi
  done
}
if truthy editor.url || truthy webhook.url || [[ "$routed" == true ]]; then
  move_url_var N8N_WEBHOOK_URL webhook.url
  move_url_var N8N_EDITOR_BASE_URL editor.url
fi

if truthy ingress.enabled || truthy httpRoute.enabled; then
  for t in shared main webhookProcessor; do
    if [[ "$(q "(.env.$t // {}) | has(\"N8N_PROXY_HOPS\")")" == "true" ]]; then
      u ".chartEnvOverrides.$t.N8N_PROXY_HOPS = .env.$t.N8N_PROXY_HOPS | del(.env.$t.N8N_PROXY_HOPS)"
      prune_up "env.$t.N8N_PROXY_HOPS"
      changed "Moved env.$t.N8N_PROXY_HOPS to chartEnvOverrides.$t, which keeps your value. Without it, the chart sets 1 behind an Ingress or HTTPRoute."
    fi
  done
fi

for t in shared main worker webhookProcessor; do
  [[ "$(q "(.env.$t // {}) | has(\"N8N_DEFAULT_BINARY_DATA_MODE\")")" == "true" ]] || continue
  if truthy s3.enabled; then
    u ".chartEnvOverrides.$t.N8N_DEFAULT_BINARY_DATA_MODE = .env.$t.N8N_DEFAULT_BINARY_DATA_MODE | del(.env.$t.N8N_DEFAULT_BINARY_DATA_MODE)"
    prune_up "env.$t.N8N_DEFAULT_BINARY_DATA_MODE"
    changed "Moved env.$t.N8N_DEFAULT_BINARY_DATA_MODE to chartEnvOverrides.$t, which keeps your mode. Without it, s3.enabled sets the mode to s3."
  elif queue_mode && [[ "$(q ".env.$t.N8N_DEFAULT_BINARY_DATA_MODE")" == "filesystem" ]]; then
    remove "env.$t.N8N_DEFAULT_BINARY_DATA_MODE" "In queue mode, one pod cannot read binary data that another pod wrote to its own disk, so n8n now uses database."
  fi
done

# --- Retired values keys ---

# executions.concurrency.productionLimit: n8n uses the limit as each worker's
# concurrency in queue mode, and ignores --concurrency, so the flag goes too.
if present executions.concurrency.productionLimit; then
  limit="$(val executions.concurrency.productionLimit)"
  if [[ -z "$limit" || "$limit" == "-1" ]]; then
    remove executions.concurrency.productionLimit "-1 is n8n's default."
  else
    if queue_mode; then t=worker; else t=main; fi
    u ".env.$t.N8N_CONCURRENCY_PRODUCTION_LIMIT = .executions.concurrency.productionLimit | del(.executions.concurrency.productionLimit)"
    prune_up executions.concurrency.productionLimit
    changed "Moved executions.concurrency.productionLimit to env.$t.N8N_CONCURRENCY_PRODUCTION_LIMIT."
    if [[ "$t" == worker ]] && present queueMode.workerConcurrency; then
      remove queueMode.workerConcurrency "n8n ignored it, because the production limit sets each worker's concurrency."
    fi
  fi
fi

if present database.useExternal; then
  remove database.useExternal "database.type chooses the database. Your connection settings stay as they are."
fi
if present database.ssl.key; then
  [[ -z "$(val database.ssl.key)" ]] || check "database.ssl.key was set, but the chart never read it. To use a client key, put it in a Secret. Then set database.ssl.existingSecret.name and database.ssl.existingSecret.keyKey."
  remove database.ssl.key
fi
if present redis.useExternal; then
  remove redis.useExternal "Queue mode connects to the Redis at redis.host."
fi
if present redis.worker.maxStalledCount; then
  remove redis.worker.maxStalledCount "n8n has ignored it since n8n 2.0."
fi
if present webhook.timeout; then
  remove webhook.timeout "n8n never read the variable it set."
fi

# ingress.webhookProcessor: its settings move to ingress.webhook.
if present ingress.webhookProcessor; then
  moved=""
  for k in className annotations tls; do
    if ! empty_at "ingress.webhookProcessor.$k"; then
      if ! empty_at "ingress.webhook.$k"; then
        check "ingress.webhookProcessor.$k was not moved, because ingress.webhook.$k is already set."
      else
        u ".ingress.webhook.$k = .ingress.webhookProcessor.$k"
        moved+="${moved:+, }$k"
      fi
    fi
  done
  wp_enabled="$(q '.ingress.webhookProcessor.enabled // false')"
  u 'del(.ingress.webhookProcessor)'
  prune_up ingress.webhookProcessor
  changed "Removed ingress.webhookProcessor.${moved:+ Moved $moved to ingress.webhook.}"
  if [[ "$(q '.ingress.webhook.className // ""')" == "" ]] && truthy ingress.className && [[ "$wp_enabled" == "true" ]]; then
    check "The webhook Ingress now uses ingress.className, because ingress.webhook.className is empty. In 1.x it had no class. Set ingress.webhook.className to keep another class."
  fi
  if [[ "$wp_enabled" != "true" ]] && truthy webhookProcessor.enabled && truthy ingress.enabled; then
    check "The chart now renders the webhook Ingress, which sends production webhooks to the webhook processors. On a controller that gives each Ingress its own load balancer, such as the AWS Load Balancer Controller, add the same group annotation to ingress.annotations and ingress.webhook.annotations."
  fi
fi

# ingress.sticky: 1.x added the ingress-nginx cookie affinity annotations, but
# only for the nginx class.
if present ingress.sticky; then
  if truthy ingress.sticky.enabled; then
    if [[ "$(val ingress.className)" == "nginx" || "$(q '(.ingress.annotations // {}) | has("kubernetes.io/ingress.class")')" == "true" ]]; then
      u '.ingress.sticky as $s |
        .ingress.annotations["nginx.ingress.kubernetes.io/affinity"] |= (. // "cookie") |
        .ingress.annotations["nginx.ingress.kubernetes.io/session-cookie-name"] |= (. // ($s.cookieName // "n8n_affinity" | tostring)) |
        .ingress.annotations["nginx.ingress.kubernetes.io/session-cookie-expires"] |= (. // ($s.cookieExpires // "172800" | tostring)) |
        .ingress.annotations["nginx.ingress.kubernetes.io/session-cookie-max-age"] |= (. // ($s.cookieMaxAge // "172800" | tostring))'
      u 'del(.ingress.sticky)'
      prune_up ingress.sticky
      changed "Replaced ingress.sticky with the ingress-nginx cookie affinity annotations in ingress.annotations, as 1.x rendered them."
    else
      remove ingress.sticky "1.x set no affinity annotations for your ingress class."
      check "ingress.sticky.enabled was true, but 1.x adds its annotations for the nginx class only. If you run multi-main, set your controller's session affinity annotations in ingress.annotations."
    fi
  else
    remove ingress.sticky "It was off."
  fi
fi

# serviceAccount.awsRoleArn: 1.x rendered it as the IRSA annotation, only on a
# ServiceAccount it created, with s3.enabled and s3.auth.autoDetect. An
# annotation you set yourself won over it, and still does.
if present serviceAccount.awsRoleArn; then
  arn="$(val serviceAccount.awsRoleArn)"
  if [[ -z "$arn" ]]; then
    remove serviceAccount.awsRoleArn "It was empty."
  elif [[ "$(q '.serviceAccount.create')" == "false" ]] || ! truthy s3.enabled || ! truthy s3.auth.autoDetect; then
    remove serviceAccount.awsRoleArn "1.x did not render it with your values, because it needs serviceAccount.create, s3.enabled and s3.auth.autoDetect."
    check "serviceAccount.awsRoleArn was removed without adding an annotation. If the pods need that IAM role, set eks.amazonaws.com/role-arn in serviceAccount.annotations."
  elif [[ "$(q '(.serviceAccount.annotations // {}) | has("eks.amazonaws.com/role-arn")')" == "true" ]]; then
    remove serviceAccount.awsRoleArn "serviceAccount.annotations already sets eks.amazonaws.com/role-arn, which won in 1.x."
  else
    u '.serviceAccount.annotations["eks.amazonaws.com/role-arn"] = .serviceAccount.awsRoleArn | del(.serviceAccount.awsRoleArn)'
    prune_up serviceAccount.awsRoleArn
    changed "Moved serviceAccount.awsRoleArn to the eks.amazonaws.com/role-arn annotation in serviceAccount.annotations."
  fi
fi

# securityContext: the IDs move to podSecurityContext.shared.
if present securityContext; then
  if [[ "$(q '.securityContext.enabled')" == "false" ]]; then
    u '.podSecurityContext.shared = null | del(.securityContext)'
    changed "Replaced securityContext.enabled: false with podSecurityContext.shared: null, which drops the pod security defaults as 1.x did."
  else
    for k in fsGroup runAsUser runAsGroup; do
      if [[ "$(q ".securityContext | has(\"$k\")")" == "true" && "$(q "(.podSecurityContext.shared // {}) | has(\"$k\")")" == "false" ]]; then
        u ".podSecurityContext.shared.$k = .securityContext.$k"
      fi
    done
    u 'del(.securityContext)'
    changed "Moved securityContext to podSecurityContext.shared."
  fi
fi

# A 1.x podSecurityContext.<role> block replaced the pod defaults, and a 2.0
# one merges over podSecurityContext.shared. Each shared field the block left
# out is set to null, so the pods keep the context they had in 1.x.
if [[ "$written_for_1x" == true ]]; then
  DEFAULTS="$("$YQ" -o=json -I=0 '.podSecurityContext.shared' "$chart/values.yaml")"
  export DEFAULTS
  for role in main worker webhookProcessor; do
    [[ "$(q "(.podSecurityContext.$role | tag == \"!!map\") and (.podSecurityContext.$role | length > 0)")" == "true" ]] || continue
    nulled=()
    while read -r k; do
      [[ -n "$k" ]] || continue
      u ".podSecurityContext.$role.$k = null"
      nulled+=("$k")
    done < <(q ". as \$root | select((.podSecurityContext | has(\"shared\") | not) or (.podSecurityContext.shared | tag == \"!!map\")) | (strenv(DEFAULTS) | from_json) * (.podSecurityContext.shared // {}) | to_entries | .[] | select(.value != null) | .key | select(. as \$k | \$root.podSecurityContext.$role | has(\$k) | not)")
    if [[ ${#nulled[@]} -gt 0 ]]; then
      list="$(printf ', %s' "${nulled[@]}")"
      changed "Set ${list#, } to null in podSecurityContext.$role, so these pods keep their 1.x security context. In 1.x the block replaced the defaults. In 2.0 it merges over podSecurityContext.shared. Remove the nulls to take the 2.0 defaults."
    fi
  done
fi

# secretRefs.env host settings. With no other address, n8n built its URLs from
# N8N_HOST and N8N_PROTOCOL, so editor.url takes that address.
if present secretRefs.env.N8N_HOST || present secretRefs.env.N8N_PORT || present secretRefs.env.N8N_PROTOCOL; then
  host="$(val secretRefs.env.N8N_HOST)"
  protocol="$(val secretRefs.env.N8N_PROTOCOL)"; protocol="${protocol:-http}"
  port="$(val secretRefs.env.N8N_PORT)"; port="${port:-5678}"
  if [[ -n "$host" && "$host" != "localhost" ]] && ! truthy secretRefs.existingSecret && ! truthy editor.url && ! truthy webhook.url && ! truthy ingress.enabled; then
    url="$protocol://$host"
    if ! [[ ("$protocol" == "http" && "$port" == "80") || ("$protocol" == "https" && "$port" == "443") ]]; then url+=":$port"; fi
    export URL="$url"
    u '.editor.url = strenv(URL)'
    changed "Set editor.url to $url, the address n8n built from secretRefs.env.N8N_HOST, N8N_PROTOCOL and N8N_PORT."
    check "editor.url is now $url. Change it if n8n is reached at another address."
  fi
  service_port="$(val service.port)"; service_port="${service_port:-5678}"
  if present secretRefs.env.N8N_PORT && [[ "$port" != "$service_port" ]]; then
    check "secretRefs.env.N8N_PORT was $port. The chart now sets N8N_PORT from service.port, which is $service_port, so n8n listens there."
  fi
  for k in N8N_HOST N8N_PORT N8N_PROTOCOL; do
    if present "secretRefs.env.$k"; then remove "secretRefs.env.$k" "The chart's Secret holds only secrets."; fi
  done
fi

# Task runners.
if present taskRunners.authToken.value; then
  token_set=false
  if [[ -n "$(val taskRunners.authToken.value)" ]]; then
    if truthy taskRunners.authToken.existingSecret; then
      check "taskRunners.authToken.value was removed. 1.x read the token from taskRunners.authToken.existingSecret instead, and still does."
    elif truthy secretRefs.existingSecret; then
      check "taskRunners.authToken.value was set. Add the token to the Secret $(val secretRefs.existingSecret) under the key N8N_RUNNERS_AUTH_TOKEN. The script does not write to Secrets."
    elif present secretRefs.env.N8N_RUNNERS_AUTH_TOKEN; then
      check "taskRunners.authToken.value was removed. secretRefs.env.N8N_RUNNERS_AUTH_TOKEN already sets the token."
    else
      u '.secretRefs.env.N8N_RUNNERS_AUTH_TOKEN = .taskRunners.authToken.value'
      token_set=true
    fi
  fi
  u 'del(.taskRunners.authToken.value)'
  prune_up taskRunners.authToken.value
  if [[ "$token_set" == true ]]; then
    changed "Moved taskRunners.authToken.value to secretRefs.env.N8N_RUNNERS_AUTH_TOKEN."
  else
    changed "Removed taskRunners.authToken.value."
  fi
fi
if present taskRunners.broker.listenAddress; then
  remove taskRunners.broker.listenAddress "The broker listens on localhost, where the task-runner sidecar reaches it."
fi
if present taskRunners.nativePythonRunner; then
  [[ "$(q '.taskRunners.nativePythonRunner')" != "false" ]] || check "taskRunners.nativePythonRunner was false. The task runner image now decides whether Python runs, and the default image runs it."
  remove taskRunners.nativePythonRunner "The task runner image decides whether Python runs."
fi

# Worker probes: a command runs as an exec probe, and no command probes the
# health endpoint.
noop_probe='["/bin/sh","-c","pgrep -f '"'"'n8n worker'"'"' > /dev/null"]'
for p in liveness readiness; do
  path="probes.worker.$p"
  noop=false
  [[ "$(q -o=json -I=0 ".$path.command // []")" != "$noop_probe" ]] || noop=true
  has_cmd="$(q "(.$path.command // []) | length > 0")"
  if present "$path.type"; then
    type="$(val "$path.type")"
    if [[ "$type" == "httpGet" && "$has_cmd" == "true" && "$noop" == false ]]; then
      remove "$path.command" "type: httpGet ignored it in 1.x, and a command now makes an exec probe."
    elif [[ "$type" == "exec" && "$has_cmd" == "false" ]]; then
      check "$path.type was exec with no command, so 1.x ran a check that always passed. The probe now uses the worker health endpoint."
    fi
    remove "$path.type" "A command chooses an exec probe now."
  fi
  if [[ "$noop" == true ]]; then
    remove "$path.command" "Its pgrep check matched its own shell, so it always passed. The probe now uses the health endpoint."
  fi
done
if [[ "$(q '.redis.healthCheck.enabled')" == "false" ]]; then
  bare=""
  for p in liveness readiness; do
    if [[ "$(q ".probes.worker.$p.enabled")" != "false" && "$(q "(.probes.worker.$p.command // []) | length")" == "0" ]]; then bare+="${bare:+ and }probes.worker.$p"; fi
  done
  if [[ -n "$bare" ]]; then
    remove redis.healthCheck.enabled "$bare had no command, so they now probe the worker health endpoint, which this turns back on."
  fi
fi

# persistence: with an existing claim, the chart creates no PVC, so size and
# storageClassName did nothing. 2.0 fails the render on them.
if truthy persistence.existingClaim; then
  for k in size storageClassName; do
    if present "persistence.$k"; then
      remove "persistence.$k" "persistence.existingClaim is set, so the chart creates no PVC and never used it."
    fi
  done
fi

# s3.storage.mode: s3.enabled now sets the mode.
if present s3.storage.mode; then
  if truthy s3.enabled && [[ "$(val s3.storage.mode)" != "s3" ]] &&
    [[ "$(q '(.chartEnvOverrides.shared // {}) | has("N8N_DEFAULT_BINARY_DATA_MODE")')" != "true" ]]; then
    check "s3.storage.mode was $(val s3.storage.mode). With s3.enabled, n8n now stores binary data in the bucket. To keep it out of the bucket, set chartEnvOverrides.shared.N8N_DEFAULT_BINARY_DATA_MODE."
  fi
  remove s3.storage.mode "s3.enabled sets the binary data mode."
fi

# --- Checks on 1.x behaviour the script leaves to you ---
if [[ -n "$changes" ]]; then
  if truthy s3.enabled && ! truthy license.enabled; then
    check "s3.enabled needs license.enabled: true in 2.0, because n8n stores binary data in S3 only with a Business or Enterprise licence. The render fails until you set it, or set s3.enabled: false."
  fi
  if [[ "$(q '.taskRunners.enabled')" != "false" ]] && ! truthy secretRefs.existingSecret &&
    ! truthy secretRefs.env.N8N_RUNNERS_AUTH_TOKEN && ! truthy taskRunners.authToken.existingSecret; then
    check "Task runners are on by default in 2.0 and need a token. Set secretRefs.env.N8N_RUNNERS_AUTH_TOKEN, for example from openssl rand -base64 32. Or set taskRunners.authToken.existingSecret to a Secret that holds it under N8N_RUNNERS_AUTH_TOKEN. Or set taskRunners.enabled: false. The render fails until you do one of these."
  elif [[ "$(q '.taskRunners.enabled')" != "false" ]] && truthy secretRefs.existingSecret &&
    ! truthy taskRunners.authToken.existingSecret && [[ "$checks" != *N8N_RUNNERS_AUTH_TOKEN* ]]; then
    check "Task runners are on by default in 2.0 and need a token. Add N8N_RUNNERS_AUTH_TOKEN to the Secret $(val secretRefs.existingSecret). Or set taskRunners.authToken.existingSecret to another Secret that holds it, or set taskRunners.enabled: false. The chart cannot see into the Secret, so the render passes, but the pods do not start without the key."
  fi
  if truthy networkPolicy.enabled && [[ "$(q '.networkPolicy.egress // [] | length')" == "0" ]]; then
    check "networkPolicy.egress is empty, so the NetworkPolicy now allows all egress. UPGRADING.md has the 1.x rules to keep them."
  fi
fi

if [[ -z "$changes" ]]; then
  cat "$input"
else
  sed "s/^[[:space:]]*$blank\$//" "$work"
fi

{
  if [[ -z "$changes" && -z "$checks" ]]; then
    echo "migrate-values: nothing to change."
  else
    if [[ -n "$changes" ]]; then
      echo "Changed:"
      printf '%s' "$changes"
    fi
    if [[ -n "$checks" ]]; then
      echo "Check:"
      printf '%s' "$checks"
    fi
    echo "Review the output before you upgrade. Then render it with helm template."
  fi
} >&2
