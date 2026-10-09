#!/usr/bin/env bash
# Builds a lab image from any n8n branch: the nightly image with that branch's compiled changes
# copied over it, then loads it into minikube. No full n8n image build, so it takes seconds.
#
#   ./build-image.sh <n8n worktree> <name>
#   ./build-image.sh ~/git/n8n-wt-my-branch my-branch
#
# Result: n8n-<name>:latest inside minikube. Run it with  N8N_IMAGE=n8n-<name> N8N_TAG=latest ./lab up ...
#
# Before you run it, build the packages the branch touched (pnpm --filter <package> build).
# Environment:
#   BASE_REF     what "changed on this branch" is measured from. Default: origin/master.
#   REGISTRY     push to this repository instead of minikube, as linux/amd64, tagged <name>. Get one with ./lab registry --provider aws|azure.
#   BASE_IMAGE   image the changed files are copied onto. Default: n8nio/n8n:nightly.
set -euo pipefail

[ $# -eq 2 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
WT=$1
NAME=$2
BASE_REF=${BASE_REF:-origin/master}
BASE_IMAGE=${BASE_IMAGE:-n8nio/n8n:nightly}
CTX=$(mktemp -d)
trap 'rm -rf "$CTX"' EXIT

N8N=/usr/local/lib/node_modules/n8n
# Workspace packages live under node_modules/.pnpm in the image, named after their CI build path.
pkg_dir() { echo "$N8N/node_modules/.pnpm/$1@file++++home+runner+_work+n8n+n8n+packages+$2/node_modules/$3"; }

# Map each changed source file to its compiled file and its path in the image.
{
  echo "FROM $BASE_IMAGE"
  git -C "$WT" diff --name-only "$BASE_REF"...HEAD -- 'packages/*.ts' |
    grep -vE '__tests__|/test/|\.test\.ts$' |
    while read -r src; do
      case "$src" in
        packages/cli/src/*)            rel=${src#packages/cli/src/};                 dst="$N8N/dist" ;;
        packages/@n8n/config/src/*)    rel=${src#packages/@n8n/config/src/};         dst="$(pkg_dir @n8n+config @n8n+config @n8n/config)/dist" ;;
        packages/@n8n/db/src/*)        rel=${src#packages/@n8n/db/src/};             dst="$(pkg_dir @n8n+db @n8n+db @n8n/db)/dist" ;;
        packages/@n8n/telemetry/src/*)rel=${src#packages/@n8n/telemetry/src/};      dst="$(pkg_dir @n8n+telemetry @n8n+telemetry @n8n/telemetry)/dist" ;;
        packages/@n8n/decorators/src/*) rel=${src#packages/@n8n/decorators/src/};    dst="$(pkg_dir @n8n+decorators @n8n+decorators @n8n/decorators)/dist" ;;
        packages/@n8n/nodes-langchain/*) rel=${src#packages/@n8n/nodes-langchain/};  dst="$(pkg_dir @n8n+n8n-nodes-langchain @n8n+nodes-langchain @n8n/n8n-nodes-langchain)/dist" ;;
        *) echo "Package not supported yet, add it to the case in build-image.sh: $src" >&2; exit 1 ;;
      esac
      js=${rel%.ts}.js
      base=${src%/src/*}; [ "$base" = "$src" ] && base=packages/@n8n/nodes-langchain
      [ -f "$WT/$base/dist/$js" ] || { echo "Not built: $WT/$base/dist/$js. Run: pnpm --filter ./$base build" >&2; exit 1; }
      mkdir -p "$CTX/$(dirname "$src")"
      cp "$WT/$base/dist/$js" "$CTX/${src%.ts}.js"
      echo "COPY ${src%.ts}.js $dst/$js"
    done
} > "$CTX/Dockerfile"

[ "$(wc -l < "$CTX/Dockerfile")" -gt 1 ] || { echo "No changed source files between $BASE_REF and HEAD in $WT" >&2; exit 1; }

cat "$CTX/Dockerfile"
if [ -n "${REGISTRY:-}" ]; then
  # Cloud nodes are amd64, whatever this machine is.
  docker buildx build --platform linux/amd64 --push -t "$REGISTRY:$NAME" "$CTX"
  echo "Pushed $REGISTRY:$NAME. Run it with  N8N_IMAGE=$REGISTRY N8N_TAG=$NAME ./lab up ..."
  exit 0
fi
docker build -q -t "n8n-$NAME:latest" "$CTX"
minikube image load "n8n-$NAME:latest" --overwrite=true
echo "Loaded n8n-$NAME:latest into minikube"
