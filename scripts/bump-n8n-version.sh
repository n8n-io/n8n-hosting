#!/usr/bin/env bash
#
# Rewrite every n8n version pin in this repo to the version given.
#
#   scripts/bump-n8n-version.sh 2.38.6
#
# Deliberately mechanical: it validates the version format, rewrites nine
# lines and does nothing else. It never resolves `stable`, compares versions
# or touches git, so it is safe to run by hand, including to roll back to an
# older version. Those decisions belong to the job that calls it,
# .github/workflows/bump-n8n-version.yml.
#
# Every pin has to match exactly one line, and all nine are checked before any
# are written, so a file whose shape has changed fails the run instead of
# being quietly skipped or leaving the tree half rewritten.

set -euo pipefail

version=${1:-}

if [[ -z "$version" ]]; then
  echo "usage: ${0##*/} <version>, for example ${0##*/} 2.38.6" >&2
  exit 64
fi

if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "error: '$version' is not a concrete n8n version such as 2.38.6" >&2
  exit 64
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Each pin is a file plus an awk program that rewrites its version line and
# counts what it rewrote in `hits`, exiting non-zero unless it saw exactly one.
files=()
programs=()

pin() {
  files+=("$1")
  programs+=("$2")
}

# The chart's appVersion. image.tag and taskRunners.image.tag both fall back to
# it through the n8n.imageTag helpers, so this is the chart's only pin.
pin charts/n8n/Chart.yaml '
  /^appVersion:/ { print "appVersion: \"" version "\""; hits++; next }
  { print }
  END { exit(hits == 1 ? 0 : 1) }
'

# Compose and Caddy. Their n8n and runners images both interpolate
# ${N8N_VERSION}, so one line per stack moves both.
for env_file in \
  docker-compose/withPostgres/.env \
  docker-compose/withPostgresAndWorker/.env \
  docker-compose/subfolderWithSSL/.env \
  docker-caddy/.env; do
  pin "$env_file" '
    /^N8N_VERSION=/ { print "N8N_VERSION=" version; hits++; next }
    { print }
    END { exit(hits == 1 ? 0 : 1) }
  '
done

# The raw manifest. Matching on the colon leaves the busybox init container
# alone and refuses an untagged n8nio/n8n line rather than pinning it blind.
pin kubernetes/n8n-deployment.yaml '
  /^[[:space:]]*image: n8nio\/n8n:/ {
    sub(/image: n8nio\/n8n:.*/, "image: n8nio/n8n:" version)
    hits++
  }
  { print }
  END { exit(hits == 1 ? 0 : 1) }
'

# The ECS Fargate templates carry the version once each, as the default of
# their N8nVersion parameter, which every n8nio/n8n and n8nio/runners
# reference !Subs. Only the Default inside that parameter block is touched.
for template in \
  aws-cloudformation/ecs-fargate/n8n-w-multimain-queuemode.yaml \
  aws-cloudformation/ecs-fargate/n8n-w-multimain-queuemode-webhooks.yaml \
  aws-cloudformation/ecs-fargate/n8n-w-multimain-queuemode-webhooks-ha.yaml; do
  pin "$template" '
    /^  N8nVersion:/ { in_block = 1 }
    in_block && /^  [A-Za-z]/ && !/^  N8nVersion:/ { in_block = 0 }
    in_block && /^    Default:/ {
      sub(/Default:.*/, "Default: \"" version "\"")
      hits++
    }
    { print }
    END { exit(hits == 1 ? 0 : 1) }
  '
done

# Check pass. Nothing is written until every pin has been found exactly once.
for i in "${!files[@]}"; do
  file=${files[$i]}

  if [[ ! -f "$file" ]]; then
    echo "error: $file is missing" >&2
    exit 1
  fi

  if ! awk -v version="$version" "${programs[$i]}" "$file" >/dev/null; then
    echo "error: $file has no single line matching the expected pin, its shape has changed" >&2
    exit 1
  fi
done

# Write pass. Output goes through a temp file because `sed -i` takes different
# arguments on GNU and BSD, and this runs both on an Actions runner and on a
# maintainer's Mac. Copying the temp file back keeps the original's mode.
echo "Pinning n8n $version in:"

for i in "${!files[@]}"; do
  file=${files[$i]}
  tmp=$(mktemp)
  awk -v version="$version" "${programs[$i]}" "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  echo "  $file"
done
