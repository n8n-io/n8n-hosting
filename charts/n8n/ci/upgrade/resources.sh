#!/usr/bin/env bash
# Records what an upgrade must keep, and checks the upgrade kept it.
#
#   resources.sh snapshot <release> <file>   before the upgrade
#   resources.sh compare <release> <file>    after it, against that file
#
# The snapshot holds the UID of every object in the release's manifest and of
# every PVC in the namespace, which takes in claims a StatefulSet creates
# outside the manifest, and the revision of every Deployment.
#
# compare fails when an object kept its kind and name but changed its UID,
# because Helm deleted and recreated it. It fails when a PVC is gone, because
# its data went with it, and when a Deployment rolled more than once. An
# object the new chart no longer renders is reported, not failed: removing
# one can be intended, and the release notes have to say so.
set -euo pipefail

usage() {
  echo "usage: $0 snapshot|compare <release> <file>" >&2
  exit 2
}

[[ $# -eq 3 ]] || usage
action=$1 release=$2 file=$3

snapshot() {
  {
    helm get manifest "$release" | kubectl get -f - -o json
    kubectl get pvc -o json
  } | jq -s '[.[] | (.items // [.])[] | {
      key: "\(.kind)/\(.metadata.name)",
      kind: .kind,
      uid: .metadata.uid,
      revision: .metadata.annotations["deployment.kubernetes.io/revision"]
    }] | unique_by(.key)'
}

case "$action" in
  snapshot)
    snapshot > "$file"
    echo "Recorded $(jq length "$file") objects from release ${release}."
    ;;
  compare)
    after=$(snapshot)
    report=$(jq -r --argjson after "$after" '
      ($after | map({(.key): .}) | add // {}) as $now
      | .[]
      | . as $was
      | $now[$was.key] as $is
      | if $is == null then
          if $was.kind == "PersistentVolumeClaim" then "fail\t\($was.key) is gone, and its data with it."
          else "gone\t\($was.key) is no longer in the release." end
        elif $is.uid != $was.uid then "fail\t\($was.key) was deleted and recreated."
        elif $was.kind == "Deployment" then
          (($is.revision | tonumber) - ($was.revision | tonumber)) as $rolls
          | if $rolls > 1 then "fail\t\($was.key) rolled \($rolls) times."
            elif $rolls == 1 then "ok\t\($was.key) kept its UID and rolled once."
            else "ok\t\($was.key) kept its UID and did not roll." end
        else "ok\t\($was.key) kept its UID." end
    ' "$file")

    failed=0
    while IFS=$'\t' read -r result message; do
      case "$result" in
        fail) echo "::error::${message}"; failed=1 ;;
        gone) echo "::warning::${message}" ;;
        *) echo "$message" ;;
      esac
    done <<< "$report"
    exit "$failed"
    ;;
  *)
    usage
    ;;
esac
